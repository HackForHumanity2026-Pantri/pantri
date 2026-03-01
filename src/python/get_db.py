import os
from pathlib import Path
from urllib.parse import quote

import logging
from dotenv import load_dotenv

logger = logging.getLogger(__name__)
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
import psycopg2

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(env_path, override=True)


def _build_database_url() -> str:
    """Resolve the database URL from env vars, falling back to individual credentials."""

    # If DATABASE_URL is set, use it directly
    url = os.getenv("DATABASE_URL")
    if url and url.strip():
        return url

    # Load individual pieces
    username = os.getenv("POSTGRES_USER")
    password = os.getenv("POSTGRES_PASSWORD")
    host = os.getenv("POSTGRES_HOST")
    db = os.getenv("POSTGRES_DB")

    # Validate configuration
    if not all([username, host, db]):
        raise ValueError(
            "Missing required database config. Set DATABASE_URL or "
            "POSTGRES_USER, POSTGRES_HOST, and POSTGRES_DB."
        )

    # Properly quote password for URLs
    password_q = quote(password or "")

    return f"postgresql://{username}:{password_q}@{host}/{db}"


SQLALCHEMY_DATABASE_URL = _build_database_url()


def _ensure_database_exists():
    """Create the target database if it doesn't already exist."""
    db_name = os.getenv("POSTGRES_DB")
    if not db_name:
        return  # Can't determine DB name, skip
    username = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "")
    host = os.getenv("POSTGRES_HOST", "localhost")
    try:
        conn = psycopg2.connect(
            dbname="postgres", user=username, password=password, host=host
        )
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
        if not cur.fetchone():
            cur.execute(f'CREATE DATABASE "{db_name}"')
            print(f"Created database '{db_name}'.")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Warning: could not ensure database exists: {e}")


_ensure_database_exists()

_engine_kwargs = {"pool_pre_ping": True}
if not SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    _engine_kwargs["pool_size"] = 5
    _engine_kwargs["max_overflow"] = 10

engine = create_engine(SQLALCHEMY_DATABASE_URL, **_engine_kwargs)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

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
