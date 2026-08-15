# Reader AI Backend — Agentic RAG (FastAPI + LangGraph)

Enterprise-grade backend powering the AI reading companion for the Flutter reader app.

## Stack

| Layer | Technology |
|---|---|
| API | FastAPI (async, SSE streaming) |
| Orchestration | LangGraph StateGraph (Agentic RAG) |
| Document parsing | PyMuPDF (PDF), ebooklib + BeautifulSoup (EPUB) |
| Vector store | Qdrant — hybrid search (dense + BM25 sparse, RRF fusion) |
| Reranker | Cohere Rerank v3 / BGE-Reranker / no-op fallback |
| Memory | LangGraph checkpointer (Redis or InMemory), per user/session/book |
| Auth | JWT (python-jose), `user_id` scoped on all vector payloads |

## Run

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Windows
pip install -r requirements.txt

cp .env.example .env              # fill keys / endpoints
uvicorn app.main:app --reload --port 8000
```

Get a dev token (DEBUG=true only):

```bash
curl -X POST http://localhost:8000/api/v1/auth/token -H "Content-Type: application/json" -d '{"user_id":"user-1"}'
```

## Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/ingest` | Upload `.pdf`/`.epub` (multipart) → async chunking + indexing, returns `task_id` |
| GET | `/api/v1/ingest/status/{task_id}` | Poll ingest progress |
| POST | `/api/v1/chat/stream` | SSE token stream over the agentic RAG graph |
| POST | `/api/v1/reader/explain-highlight` | SSE structured explainer (Meaning / Author Context / Socratic Anchor) |
| POST | `/api/v1/chat/resume` | Resume a HITL-paused LangGraph thread (`thread_id` + `approved`) |
| GET | `/health` | Liveness |

All endpoints except `/auth/token` and `/health` require `Authorization: Bearer <jwt>`.

### SSE event payloads (`/chat/stream`)

```json
{"type":"scope","data":"single_book"}
{"type":"retrieved","data":6}
{"type":"status","data":"Relevance gate: 4/6 passages passed (avg 0.81)."}
{"type":"token","data":"Hinglish answer streamed token-by-token"}
{"type":"usage","data":{"prompt_tokens":142,"completion_tokens":38,"total_tokens":180}}
{"type":"citation","data":{"title":"Meditations","chapter":"Book II","page":12}}
{"type":"hitl_pending","data":{"reason":"Multi-book summarisation requires approval."}}
{"type":"done","data":{"citations":[],"grounded":true,"usage":{}}}
{"type":"error","data":{"detail":"..."}}
```

## Agentic RAG graph

```
START → query_router_node → hybrid_retrieval_node → hitl_checkpoint_node ─(approved)→ relevance_grader_node
   single_book / multi_selected_books / all_books / highlight_explainer ─┐
                                                                          ▼
relevance_grader_node ─(fail)→ query_rewriter_node → hybrid_retrieval_node (retry loop)
        └(pass)→ answer_generator_node → hallucination_checker_node
                                              ├(not grounded)→ query_rewriter_node
                                              ├(highlight)→ socratic_memory_anchor_node
                                              └(done)→ done_node → END
```

- **CRAG**: `relevance_grader_node` LLM-scores every chunk; below-threshold → `query_rewriter_node` rephrases and re-retrieves (max `RETRIEVAL_MAX_ATTEMPTS`).
- **Self-RAG**: `hallucination_checker_node` validates the answer against retrieved chunks and lists unsupported claims.
- **HITL**: `hitl_checkpoint_node` calls `interrupt()` before expensive multi-book summaries; `/chat/resume` resumes the thread via `Command(resume=approved)`.

## Document pipeline

`document_processor` extracts per-page text, detects chapter boundaries (PDF TOC / heading heuristics / EPUB spine headings) and runs semantic chunking that preserves `chapter` + `page_number` in every chunk's metadata, along with `user_id`, `book_id`, `title`, `author`, `chunk_index`.

## Configuration

All knobs live in `app/core/config.py` / `.env`. Notable: `VECTOR_STORE` (qdrant | pgvector), `RERANKER_PROVIDER` (cohere | bge | none), `CHECKPOINTER` (redis | memory), `CHUNK_SIZE`, `RELEVANCE_THRESHOLD`, `RETRIEVAL_MAX_ATTEMPTS`.
