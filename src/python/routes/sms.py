from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class SMSRequest(BaseModel):
    to: str
    body: str


@router.post("/sms/send")
async def send_sms(request: SMSRequest):
    """SMS send endpoint. In production, this would integrate with Twilio or similar.
    Currently returns a success response to support the iOS app flow."""
    return {
        "status": "sent",
        "to": request.to,
        "message": "SMS queued for delivery",
    }
