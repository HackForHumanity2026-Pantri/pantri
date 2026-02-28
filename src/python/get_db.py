import os
from pathlib import Path
from urllib.parse import quote

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

def _build_database_url() -> str:
    """Resolve the database URL from env vars, falling back to individual credentials."""
    url = os.getenv("DATABASE_URL")
    if url:
        return url

    env_path = Path(".") / ".env"
    load_dotenv(dotenv_path=env_path, override=True)

    password = quote(os.getenv("POSTGRES_PASSWORD", ""))
    username = os.getenv("POSTGRES_USER", "")
    host = os.getenv("POSTGRES_HOST", "")
    db = os.getenv("POSTGRES_DB", "")

    if not all([username, host, db]):
        raise ValueError(
            "Missing required database config. Set DATABASE_URL or "
            "POSTGRES_USER, POSTGRES_HOST, and POSTGRES_DB."
        )

    return f"postgresql://{username}:{password}@{host}/{db}"


SQLALCHEMY_DATABASE_URL = _build_database_url()

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,   # drops stale connections before use
    pool_size=5,
    max_overflow=10,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Yield a database session and ensure it is closed after use."""
    db = SessionLocal()
    try:
        # Lightweight connectivity check
        db.execute(text("SELECT 1"))
        logger.info("Database session opened successfully.")
        yield db
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        db.rollback()
        raise
    finally:
        db.close()
        logger.debug("Database session closed.")