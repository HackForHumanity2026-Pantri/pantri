# main.py

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from routes import sources
from routes import chat as chat_routes
from routes import verify as verify_routes
from routes import sms as sms_routes
from voice.router import router as voice_router
import voice.models  # noqa: F401 – register tables with Base
from get_db import Base, engine, SessionLocal
from models.db_init import init_db

app = FastAPI(title="Pantri API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sources.router)
app.include_router(chat_routes.router)
app.include_router(verify_routes.router)
app.include_router(sms_routes.router)
app.include_router(voice_router)


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
    uvicorn.run(app, host="127.0.0.1", port=3000)

