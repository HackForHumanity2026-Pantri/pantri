from pydantic import BaseModel
fro
elalqs 

class Sources(BaseModel): 
	id: Column(str)
	name: Column(str)
	type: Column(str)
	address: Column(str)  
	lat: Column(float)
	lng: Column(float)
	phone: Column(str)
	hours_json: Column(list[dict[str,str]])
	types_json: Column(list[str])
	verified_bool: Column(bool)

class Requests(BaseModel):
    __tableName = "user_requests"
    
	#Registration details
    id = Column(String, primary_key=True, index=True)
    user_contact = Column(String, nullable=True)
    location = Column(String, nullable=False)
    need_type = Column(String, nullable=False)
    urgency = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    

	#Onboarding details
    find_location = Column(String, nullable=True)
    find_type = Column(String, nullable=True)
    find_urgency = Column(String, nullable=True)
    find_created_at = Column(DateTime, nullable=True)
    
	#completion details
    completed_session = Column(Boolean, default=False)