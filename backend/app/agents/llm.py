from __future__ import annotations

import json
from typing import Any

import httpx

from app.core.logging import get_logger
from app.services import provider_context

logger = get_logger(__name__)


class LLMError(RuntimeError):
    pass


class _StreamSetupError(RuntimeError):
    """Connection/HTTP failure before any token was emitted (retryable)."""


class OpenAICompatibleLLM:
    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=120.0)

    async def complete(self, *, messages: list[dict[str, str]], temperature: float | None = None) -> str:
        endpoints = provider_context.chat_endpoints()
        last_error: str | None = None
        for ep in endpoints:
            try:
                content = await self._complete_once(ep, messages=messages, temperature=temperature)
                provider_context.emit_provider_used(ep.provider_name, ep.model, kind="chat")
                return content
            except httpx.HTTPStatusError as exc:
                last_error = self._describe_error(ep, exc)
                self._switch_away(ep, last_error)
            except httpx.HTTPError as exc:
                last_error = f"{ep.provider_name or ep.base_url}: {exc}"
                self._switch_away(ep, last_error)
        raise LLMError(f"No working LLM provider. Last error: {last_error}")

    async def complete_json(self, *, messages: list[dict[str, str]], temperature: float | None = None) -> dict[str, Any]:
        content = await self.complete(messages=messages, temperature=temperature)
        return _parse_json(content)

    async def stream_complete(
        self,
        *,
        messages: list[dict[str, str]],
        temperature: float | None = None,
        on_token: Any,
        on_usage: Any,
    ) -> str:
        endpoints = provider_context.chat_endpoints()
        last_error: str | None = None
        for ep in endpoints:
            emitted = False
            full = ""
            try:
                payload = {
                    "model": ep.model,
                    "messages": messages,
                    "temperature": self._temperature(temperature),
                    "stream": True,
                    "stream_options": {"include_usage": True},
                }
                url = f"{ep.base_url.rstrip('/')}/chat/completions"
                headers = self._headers(ep)
                async with self._client.stream("POST", url, json=payload, headers=headers) as resp:
                    if resp.status_code >= 400:
                        body = await resp.aread()
                        raise _StreamSetupError(
                            f"{ep.provider_name or ep.base_url}: HTTP {resp.status_code}: {body[:300]}"
                        )
                    async for line in resp.aiter_lines():
                        if not line.startswith("data:"):
                            continue
                        chunk = line[5:].strip()
                        if chunk == "[DONE]":
                            break
                        try:
                            event = json.loads(chunk)
                        except json.JSONDecodeError:
                            continue
                        delta = event.get("choices", [{}])[0].get("delta", {})
                        token = delta.get("content")
                        if token:
                            emitted = True
                            full += token
                            on_token(token)
                        usage = event.get("usage")
                        if usage:
                            on_usage(usage)
                provider_context.emit_provider_used(ep.provider_name, ep.model, kind="chat")
                return full
            except _StreamSetupError as exc:
                last_error = str(exc)
            except httpx.HTTPError as exc:
                last_error = f"{ep.provider_name or ep.base_url}: {exc}"
                if emitted:
                    raise LLMError(f"LLM stream failed after partial output: {last_error}") from exc

            self._switch_away(ep, last_error)
        raise LLMError(f"No working LLM provider. Last error: {last_error}")

    async def aclose(self) -> None:
        await self._client.aclose()

    async def _complete_once(
        self,
        ep: provider_context.Endpoint,
        *,
        messages: list[dict[str, str]],
        temperature: float | None,
    ) -> str:
        payload = {
            "model": ep.model,
            "messages": messages,
            "temperature": self._temperature(temperature),
        }
        url = f"{ep.base_url.rstrip('/')}/chat/completions"
        resp = await self._client.post(url, json=payload, headers=self._headers(ep))
        resp.raise_for_status()
        data = resp.json()
        try:
            return data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LLMError(f"Malformed LLM response: {data}") from exc

    def _switch_away(self, ep: provider_context.Endpoint, reason: str) -> None:
        logger.warning("Provider %s failed, switching away: %s", ep.provider_name or ep.provider_id, reason)
        provider_context.mark_failed(ep.provider_id, reason)

    @staticmethod
    def _headers(ep: provider_context.Endpoint) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if ep.api_key:
            headers["Authorization"] = f"Bearer {ep.api_key}"
        return headers

    @staticmethod
    def _temperature(temperature: float | None) -> float:
        from app.core.config import settings

        return settings.TEMPERATURE if temperature is None else temperature

    @staticmethod
    def _describe_error(ep: provider_context.Endpoint, exc: httpx.HTTPStatusError) -> str:
        return f"{ep.provider_name or ep.base_url}: HTTP {exc.response.status_code}: {exc.response.text[:300]}"


def _parse_json(content: str) -> dict[str, Any]:
    cleaned = content.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[-1]
        cleaned = cleaned.rsplit("```", 1)[0].strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start == -1 or end == -1:
            raise LLMError(f"Could not parse JSON from LLM: {content[:200]}")
        try:
            return json.loads(cleaned[start : end + 1])
        except json.JSONDecodeError as exc:
            raise LLMError(f"Could not parse JSON from LLM: {content[:200]}") from exc


_llm: OpenAICompatibleLLM | None = None


def get_llm() -> OpenAICompatibleLLM:
    global _llm
    if _llm is None:
        _llm = OpenAICompatibleLLM()
    return _llm
