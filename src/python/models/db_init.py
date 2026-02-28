import json
from models import Sources
from sqlalchemy.orm import Session
from sqlalchemy import inspect
from fastapi import Depends
from database import get_db 

def init_db(db: Session = Depends(get_db)):
    #Make sure it exists
    if not inspect(db).has_table(Sources.__tablename__):
        print("Source table does not exist, skipping initialization")
    if db.query(Sources).first():
        print("Source table already has data, skipping initialization")
    
    with open('food_bank.json') as f:
        data = json.load(f)
        for item in data:
            source = Sources(
                id = item['id'],
                name=item['name'],
                type =item['type'],
                address=item['address'],
                state=item['state'],
                city=item['city'],
                zip=item['zip'],
                lat=item['lat'],
                lng=item['lng'], 
                phone = item['phone'],
                hours_json=item['hours_json'],
                types_json=item['types_json'],
                verified_bool=item['verified_bool'],
                last_verified_ts=item['last_verified_ts'],
                capacity_score=item['capacity_score']
            )
            db.add(source)
            print("Added sources.")