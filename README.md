# Pantri 🥫

**Pantri** helps food-insecure individuals discover nearby food pantries, food banks, and restaurants with surplus food. It combines a FastAPI backend, a SwiftUI iOS app, and optional voice/SMS accessibility features so that anyone — regardless of technical ability — can find a hot meal or bag of groceries.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Backend Setup (Python / FastAPI)](#backend-setup-python--fastapi)
- [iOS App Setup](#ios-app-setup)
- [Environment Variables](#environment-variables)
- [Database](#database)
- [API Reference](#api-reference)
- [Running Tests](#running-tests)
- [Voice & Twilio Integration](#voice--twilio-integration)
- [Project Structure](#project-structure)
- [Contributing](#contributing)

---

## Features

- 📍 **Location-based search** — find food sources near you by address, city, or GPS coordinates
- 🗂️ **Filter by need** — groceries, fresh produce, cooked meals, excess restaurant food
- 🚌 **Transit accessibility** — flags sources reachable by VTA bus
- 📞 **Voice integration** — Twilio + ElevenLabs AI agent answers inbound calls and updates source data automatically
- 💬 **Chat assistant** — conversational interface for quick queries
- ✅ **Automatic verification** — phone-bot calls food banks, transcribes answers, and applies confidence-scored updates to the database

---

## Architecture

```
pantri/
├── src/python/          # FastAPI backend (primary API, port 3000)
│   ├── routes/          # API route handlers
│   ├── models/          # SQLAlchemy DB models & Pydantic schemas
│   ├── services/        # Business logic (NLP, geocoding, bus proximity)
│   ├── voice/           # Twilio + ElevenLabs call pipeline
│   └── test/            # Pytest test suite
├── Hack For Humanity/   # iOS SwiftUI app
│   └── Hack For Humanity/   # Swift source files
└── src/typescript/      # Express.js scaffolding (optional / future use)
```

| Layer | Technology | Port |
|---|---|---|
| Backend API | Python · FastAPI · SQLAlchemy | 3000 |
| Mobile app | Swift · SwiftUI | iOS simulator / device |
| Database | SQLite (dev) · PostgreSQL (prod) | 5432 |
| Voice pipeline | Twilio · ElevenLabs · Ollama | WebSocket |

---

## Quick Start

```bash
bash setup.sh
```

`setup.sh` creates a Python virtual environment, installs dependencies, writes a default `.env` (SQLite for local dev), and starts the FastAPI server on **http://127.0.0.1:3000**.

Then open `Hack For Humanity/Hack For Humanity.xcodeproj` in Xcode and run the iOS app — it already targets `http://127.0.0.1:3000`.

---

## Backend Setup (Python / FastAPI)

### Prerequisites

- Python 3.9+
- *(Optional)* PostgreSQL 13+ for production

### Steps

```bash
cd src/python

# Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start the server
python main.py    # → http://127.0.0.1:3000
```

On first run the server auto-creates all database tables and seeds them from the JSON files in `src/python/json_files/`.

---

## iOS App Setup

1. Open `Hack For Humanity/Hack For Humanity.xcodeproj` in **Xcode 15 or later**.
2. Select a simulator (e.g. iPhone 15) or a physical device.
3. Press **⌘ R** to build and run.

The app is pre-configured to call `http://127.0.0.1:3000`. No additional configuration is required for local development.

---

## Environment Variables

Create `src/python/.env`. The defaults below work out-of-the-box with SQLite.

```dotenv
# ── Database ────────────────────────────────────────────────────────────────
# SQLite (default — no extra setup needed):
DATABASE_URL=sqlite:///pantri.db

# PostgreSQL (uncomment and fill in for production):
# DATABASE_URL=postgresql://pantri:PASSWORD@localhost/pantri
# POSTGRES_USER=pantri
# POSTGRES_PASSWORD=your_secure_password
# POSTGRES_HOST=localhost
# POSTGRES_DB=pantri

# ── Server ───────────────────────────────────────────────────────────────────
PORT=3000
DEBUG=False
SECRET_KEY=your_secret_key_here
ALLOWED_HOSTS=localhost

# ── Twilio (required only for voice/SMS features) ────────────────────────────
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1XXXXXXXXXX   # E.164 format

# ── ElevenLabs (required only for AI voice agent) ────────────────────────────
ELEVENLABS_API_KEY=your_api_key
ELEVENLABS_AGENT_ID=your_agent_id
PUBLIC_URL=http://localhost:3000    # Use an ngrok URL when testing webhooks
```

---

## Database

### SQLite (default)

Zero configuration — the database file `pantri.db` is created automatically in `src/python/`.

### PostgreSQL (production)

```bash
# Create the database
createdb pantri

# Set DATABASE_URL in src/python/.env, then start the server normally.
# Tables and seed data are applied automatically on first run.
```

### Seed data

| Table | Source file | Contents |
|---|---|---|
| `sources` | `json_files/food_banks.json` | 100+ food banks & pantries in the South Bay |
| `restaurants` | `json_files/rest.json` | Partner restaurants with surplus food |
| `buses` | `json_files/buses.json` | VTA bus stop coordinates |

Bus accessibility (`is_accessible`) is computed on startup using the Haversine formula — any source within **0.5 km** of a VTA stop is marked as transit-accessible.

---

## API Reference

All responses are JSON. The base URL is `http://127.0.0.1:3000`.

### Food Sources

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/sources` | List all food sources. Pass `lat` & `lng` to include `distance_km`. |
| `GET` | `/sources/search` | Search with filters (see below). |
| `POST` | `/sources` | Create a new food source (address is auto-geocoded). |

**`GET /sources/search` query parameters**

| Parameter | Type | Description |
|---|---|---|
| `food_type` | string | `groceries`, `cooked meals`, `fresh produce`, … |
| `urgent_level` | string | `high`, `medium`, `low` (affects search radius) |
| `transportation` | string | `walking`, `bike`, `bus`, `car` |
| `address` | string | Street address (geocoded via OpenStreetMap) |
| `city` | string | City filter |
| `zip` | string | ZIP code filter |
| `lat` / `lng` | float | User coordinates |

**Example response item**

```json
{
  "id": "abc123",
  "name": "The Salvation Army Community Center",
  "phone": "408-848-5373",
  "address": "200 W 5th St",
  "city": "Gilroy",
  "state": "CA",
  "latitude": 37.0058,
  "longitude": -121.5764,
  "sourceType": "Food Bank",
  "foodTypes": ["Groceries", "Fresh Produce"],
  "hoursOfOperation": "Mon 12:00-14:00, Tue 12:00-14:00",
  "duration": "Permanent",
  "publicTransitAccessible": true,
  "availability": "High",
  "hasExcessFood": false,
  "isVerified": true,
  "isOpen": true,
  "distance_km": 2.34
}
```

### Chat & Voice

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/chat` | Keyword-based conversational food finder |
| `POST` | `/sms/send` | Send an SMS to a user |
| `POST` | `/verify/{source_id}` | Mark a source as phone-verified |
| `POST` | `/call/ingest` | Process a call transcript via the Ollama NLP pipeline |
| `POST` | `/ingest_call` | Voice agent entry point (Twilio + ElevenLabs) |

### Restaurants

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/restaurants` | Add a partner restaurant |

---

## Running Tests

```bash
cd src/python

# All tests
python3 -m pytest test/ -v

# Individual suites
python3 -m pytest test/test_source.py -v        # Source CRUD + search
python3 -m pytest test/test_call_ingest.py -v   # Ollama call ingest pipeline
python3 -m pytest test/test_voice.py -v         # Twilio voice pipeline
```

Tests use SQLite by default (no PostgreSQL required) and mock external services (Ollama, Twilio) so they run offline.

---

## Voice & Twilio Integration

Pantri can call food banks automatically and update its database from the conversation transcript.

### How it works

1. A scheduled outbound call is triggered via `POST /twilio/call/outbound`.
2. Twilio delivers audio to the `/twilio/media-stream` WebSocket.
3. The ElevenLabs AI agent conducts the conversation.
4. The transcript is sent to `POST /ingest_call`.
5. Ollama extracts structured changes (hours, phone, address, …).
6. Changes with confidence ≥ 0.90 are applied immediately; lower-confidence changes are stored as `PendingProposal` for human review.

### Required environment variables

```
TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
ELEVENLABS_API_KEY, ELEVENLABS_AGENT_ID
PUBLIC_URL   ← must be a publicly reachable URL (use ngrok for local testing)
```

### Ollama setup (for local NLP)

```bash
# Install Ollama: https://ollama.com
ollama pull mistral   # or any model of your choice
```

---

## Project Structure

```
pantri/
├── setup.sh                        # One-command bootstrap
├── README.md
├── Pantri App Icon.jpg
│
├── src/
│   ├── python/                     # FastAPI backend
│   │   ├── main.py                 # Entry point (uvicorn on port 3000)
│   │   ├── config.py               # Environment / settings
│   │   ├── get_db.py               # SQLAlchemy session factory
│   │   ├── requirements.txt
│   │   ├── routes/
│   │   │   ├── sources.py          # /sources, /sources/search
│   │   │   ├── chat.py             # /chat
│   │   │   ├── sms.py              # /sms/send
│   │   │   ├── verify.py           # /verify/{source_id}
│   │   │   └── call_ingest.py      # /call/ingest
│   │   ├── models/
│   │   │   └── models.py           # SQLAlchemy ORM models
│   │   ├── services/
│   │   │   ├── ollama_client.py    # LLM inference client
│   │   │   ├── apply_changes.py    # Applies proposed DB changes
│   │   │   └── calculate_bus.py    # Bus-stop proximity
│   │   ├── voice/
│   │   │   ├── router.py           # /ingest_call endpoint
│   │   │   ├── twilio_elevenlabs.py# Twilio + ElevenLabs WebSocket bridge
│   │   │   ├── agent_extract.py    # LLM prompt + extraction logic
│   │   │   ├── db_apply.py         # Applies voice-extracted changes to DB
│   │   │   ├── schemas.py          # Pydantic schemas for voice pipeline
│   │   │   ├── ollama_client.py    # Voice-specific Ollama client
│   │   │   └── models.py           # AuditLog, PendingProposal ORM models
│   │   ├── json_files/
│   │   │   ├── food_banks.json     # Seed data — food banks
│   │   │   ├── rest.json           # Seed data — restaurants
│   │   │   └── buses.json          # Seed data — VTA bus stops
│   │   └── test/
│   │       ├── conftest.py         # Shared fixtures (SQLite override)
│   │       ├── test_source.py
│   │       ├── test_call_ingest.py
│   │       └── test_voice.py
│   │
│   └── typescript/                 # Express.js scaffolding (future use)
│       ├── app.ts
│       └── routes/index.ts
│
└── Hack For Humanity/              # iOS SwiftUI app
    └── Hack For Humanity/
        ├── Hack_For_HumanityApp.swift
        ├── ContentView.swift
        ├── MainTabView.swift
        ├── ChatView.swift
        ├── MatchResultsView.swift
        ├── MapSnippetView.swift
        ├── APIClient.swift         # HTTP client (points to port 3000)
        ├── LocationManager.swift
        ├── AppState.swift
        ├── DesignSystem.swift
        ├── MatchingEngine.swift
        ├── Models.swift
        └── OnboardingView.swift
```

---

## Contributing

1. **Fork** the repository and create a feature branch.
2. Make your changes and add or update tests as appropriate.
3. Run the test suite (`python3 -m pytest test/ -v`) and confirm everything passes.
4. Open a **Pull Request** against `main` with a clear description of what you changed and why.

For questions or ideas, open an issue — we'd love to hear from you. 🙌
