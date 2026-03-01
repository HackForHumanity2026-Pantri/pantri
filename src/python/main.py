# main.py

import uvicorn
from fastapi import FastAPI
from routes import sources
from get_db import Base, engine, SessionLocal
from models.models import Sources, Requests
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


if __name__ == "__main__":
    main()
    uvicorn.run(app, host="127.0.0.1", port=8000)

