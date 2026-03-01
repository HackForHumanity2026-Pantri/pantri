from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Boolean, Integer, JSON, DateTime
from get_db import Base


class Sources(Base):
    __tablename__ = "sources"

    id               = Column(Integer, primary_key=True, index=True)
    name             = Column(String, nullable=False)
    type             = Column(String)
    address          = Column(String)
    city             = Column(String)
    state            = Column(String)
    zip              = Column(String)
    lat              = Column(Float)
    lng              = Column(Float)
    phone            = Column(String)
    hours_json       = Column(JSON)
    types_json       = Column(JSON)

class Requests(Base):
    __tablename__ = "requests"

    id                = Column(String, primary_key=True, index=True)
    user_contact      = Column(String, nullable=True)
    location          = Column(String, nullable=False)
    need_type         = Column(String, nullable=False)
    urgency           = Column(String, nullable=False)
    created_at        = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    find_location     = Column(String, nullable=True)
    find_type         = Column(String, nullable=True)
    find_urgency      = Column(String, nullable=True)
    find_created_at   = Column(DateTime, nullable=True)
    completed_session = Column(Boolean, default=False)
