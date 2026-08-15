from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    APP_NAME: str = "Reader AI Backend"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Auth
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRES_MINUTES: int = 60 * 24

    # LLM (OpenAI-compatible)
    LLM_PROVIDER: str = "openai"
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str | None = None
    CHAT_MODEL: str = "gpt-4o-mini"
    EMBEDDING_MODEL: str = "text-embedding-3-small"
    TEMPERATURE: float = 0.3

    # Reranker: "cohere" | "bge" | "none"
    RERANKER_PROVIDER: str = "none"
    COHERE_API_KEY: str = ""
    COHERE_RERANK_MODEL: str = "rerank-v3.5"
    BGE_RERANK_MODEL: str = "BAAI/bge-reranker-base"

    # Vector store: "qdrant" | "pgvector"
    VECTOR_STORE: str = "qdrant"
    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_API_KEY: str = ""
    PG_DSN: str = "postgresql://postgres:postgres@localhost:5432/reader_ai"

    # Memory / checkpointer: "redis" | "memory"
    CHECKPOINTER: str = "memory"
    REDIS_URL: str = "redis://localhost:6379/0"

    # RAG tuning
    COLLECTION_PREFIX: str = "reader_books"
    DENSE_TOP_K: int = 20
    SPARSE_TOP_K: int = 20
    FUSION_TOP_K: int = 10
    RERANK_TOP_K: int = 6
    RETRIEVAL_MAX_ATTEMPTS: int = 2
    RELEVANCE_THRESHOLD: float = 0.55
    CHUNK_SIZE: int = 800
    CHUNK_OVERLAP: int = 120
    MIN_QUERY_SIMILARITY: float = 0.25


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
