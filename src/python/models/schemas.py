from datetime import datetime
from typing import Optional

from pydantic import BaseModel

class Sources(BaseModel): 
	id: str
	name: str
	type: str
	address: str  
	lat: float
	ing: float
	phone: str
	hours_json: list[dict[str,str]]
	types_json: list[str]
	verified_bool: bool

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