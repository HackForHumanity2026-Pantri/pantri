# main.py

import uvicorn
from fastapi import FastAPI
from sqlalchemy import text
from routes import sources
from get_db import Base, engine, SessionLocal
from models.db_init import init_db

app = FastAPI()

app.include_router(sources.router)


def main():
    print("Starting Pantri application...")

    # Create all tables if they don't exist
    Base.metadata.create_all(bind=engine)
    print("Database tables ready.")

    # Seed initial data
    db = SessionLocal()
    try:
        init_db(db)
    finally:
        db.close()

    # Reset sequences to avoid ID conflicts after seeding
    with engine.begin() as conn:
        for table in ("sources", "restaurants"):
            conn.execute(text(
                f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), COALESCE(MAX(id), 0)) FROM {table}"
            ))
    print("Sequences reset.")


if __name__ == "__main__":
    main()
    uvicorn.run(app, host="127.0.0.1", port=8000)

