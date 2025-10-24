from typing import Optional, Any, List
from pydantic import BaseModel
from enum import Enum


class CommandType(str, Enum):
    SEND_OTP = "send_otp"
    VERIFY_OTP = "verify_otp"
    GET_PROFILE = "get_profile"
    GET_CIRCLES = "get_circles"
    GET_CIRCLE_MEMBERS = "get_circle_members"
    GET_DEVICE_LOCATIONS = "get_device_locations"
    PING = "ping"
    GET_STATUS = "get_status"


class Command(BaseModel):
    """Command sent from server to iOS app."""
    command_id: str
    type: CommandType
    params: Optional[dict] = None


class ResponseStatus(str, Enum):
    """Response status types."""
    SUCCESS = "success"
    ERROR = "error"
    PENDING = "pending"


class Response(BaseModel):
    """Response from iOS app to server."""
    command_id: str
    status: ResponseStatus
    data: Optional[Any] = None
    error: Optional[str] = None


# Specific command parameter models
class SendOTPParams(BaseModel):
    phone: str
    country: str


class VerifyOTPParams(BaseModel):
    transaction_id: str
    code: str


class GetCircleMembersParams(BaseModel):
    circle_id: str


class GetDeviceLocationsParams(BaseModel):
    circle_ids: List[str]


# Response data models
class StatusData(BaseModel):
    has_transaction: bool
    has_bearer: bool
    is_authenticated: bool


class OTPSentData(BaseModel):
    transaction_id: str


class AuthData(BaseModel):
    bearer_token: str


class CircleInfo(BaseModel):
    id: str
    name: str
    created_at: str


class CirclesData(BaseModel):
    circles: List[CircleInfo]

