import sys
import os
from pathlib import Path

# Ensure parent dir is on path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# Force SQLite for testing (must be set before any imports that use get_db)
os.environ["DATABASE_URL"] = "sqlite:///test_pantri.db"

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from get_db import Base

TEST_DATABASE_URL = "sqlite:///test_pantri.db"
test_engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(bind=test_engine, autoflush=False, autocommit=False)


@pytest.fixture(autouse=True)
def setup_test_db():
    """Create all tables before each test and drop them after."""
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def db_session():
    """Yield a test DB session."""
    session = TestSessionLocal()
    try:
        yield session
    finally:
        session.close()
