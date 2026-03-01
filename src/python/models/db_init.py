import json
from pathlib import Path
from models.models import Sources
from sqlalchemy.orm import Session
from sqlalchemy import inspect
from get_db import engine


def init_db(db: Session):
    # Check table exists
    if not inspect(engine).has_table("sources"):
        print("Source table does not exist, skipping initialization")
        return

    # Skip if already seeded
    if db.query(Sources).first():
        print("Source table already has data, skipping initialization")
        return

    with open(Path(__file__).resolve().parent.parent.parent / "food_bank.json") as f:
        data = json.load(f)

    for item in data:
        source = Sources(
            id=item['id'],
            name=item['name'],
            type=item['type'],
            address=item['address'],
            state=item['state'],
            city=item['city'],
            zip=item['zip'],
            lat=item['lat'],
            lng=item['lng'],
            phone=item['phone'],
            hours_json=item['hours_json'],
            types_json=item['types_json'],
        )
        db.add(source)

    db.commit()
    print(f"Seeded {len(data)} sources.")
