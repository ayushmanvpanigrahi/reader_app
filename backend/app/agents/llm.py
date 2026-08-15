from __future__ import annotations

import json
from typing import Any

import httpx

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


class LLMError(RuntimeError):
    pass


class OpenAICompatibleLLM:
    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=120.0)

    @property
    def _url(self) -> str:
        base = settings.OPENAI_BASE_URL or "https://api.openai.com/v1"
        return f"{base.rstrip('/')}/chat/completions"

    @property
    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if settings.OPENAI_API_KEY:
            headers["Authorization"] = f"Bearer {settings.OPENAI_API_KEY}"
        return headers

    async def complete(self, *, messages: list[dict[str, str]], temperature: float | None = None) -> str:
        payload = {
            "model": settings.CHAT_MODEL,
            "messages": messages,
            "temperature": settings.TEMPERATURE if temperature is None else temperature,
        }
        try:
            resp = await self._client.post(self._url, json=payload, headers=self._headers)
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPStatusError as exc:
            raise LLMError(f"LLM returned {exc.response.status_code}: {exc.response.text[:300]}") from exc
        except httpx.HTTPError as exc:
            raise LLMError(f"LLM request failed: {exc}") from exc

        try:
            return data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LLMError(f"Malformed LLM response: {data}") from exc

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
        payload = {
            "model": settings.CHAT_MODEL,
            "messages": messages,
            "temperature": settings.TEMPERATURE if temperature is None else temperature,
            "stream": True,
            "stream_options": {"include_usage": True},
        }
        full = ""
        try:
            async with self._client.stream("POST", self._url, json=payload, headers=self._headers) as resp:
                if resp.status_code >= 400:
                    body = await resp.aread()
                    raise LLMError(f"LLM returned {resp.status_code}: {body[:300]}")
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
                        full += token
                        on_token(token)
                    usage = event.get("usage")
                    if usage:
                        on_usage(usage)
        except httpx.HTTPError as exc:
            raise LLMError(f"LLM stream failed: {exc}") from exc
        return full

    async def aclose(self) -> None:
        await self._client.aclose()


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
