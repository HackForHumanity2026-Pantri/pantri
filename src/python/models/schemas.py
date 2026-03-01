from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel


class HoursEntry(BaseModel):
    day: str
    open: str
    close: str


class SourceCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip: Optional[str] = None
    types_json: Optional[List[str]] = None       # food available e.g. ["groceries", "cooked meals"]
    hours_json: Optional[List[HoursEntry]] = None
    duration: Optional[str] = None               # "permanent", "temporary", etc.
    is_accessible: Optional[bool] = None
    availability: Optional[str] = None           # "open", "by_appointment", etc.
    excess_food: Optional[bool] = None


class RestaurantCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip: Optional[str] = None
    types_json: Optional[List[str]] = None
    hours_json: Optional[List[HoursEntry]] = None
    duration: Optional[str] = None
    accessible: Optional[bool] = None
    availability: Optional[str] = None
    excess_food: Optional[bool] = None

class Requests(BaseModel):
	id: str
	user_contact: Optional[str] = None
	location: str
	need_type: str
	urgency: str
	created_at: datetime

class Matches(BaseModel):
	request_id: str
	source_id: str
	score: int
	matched_at: datetime

class Verifications(BaseModel):
	source_id: str
	email_id: str
	status: str
	raw_transcript: str
	confidence: float
	verified_at: datetime
