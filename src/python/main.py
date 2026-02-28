# main.py

import os
import uvicorn
from fastapi import FastAPI
from routers import sources

app = FastAPI()

app.include_router(sources.router)

def main():
    # Initialize application settings
    print("Starting Pantri application...")

if __name__ == "__main__":
    main()
    uvicorn.run(app, host= "127.0.0.1", port = 8000)

    