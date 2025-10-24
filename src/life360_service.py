import uuid
from typing import Optional, List, Dict, Any

from .models import (
    Command, CommandType, Response, ResponseStatus,
    SendOTPParams, VerifyOTPParams, GetCircleMembersParams,
    GetDeviceLocationsParams, StatusData, CirclesData
)
from .websocket_handler import manager

class Life360Service:
    
    def __init__(self, client_id: str = "ios-app"):
        self.client_id = client_id
        
    def _generate_command_id(self) -> str:
        return str(uuid.uuid4())
        
    async def _send_command(self, command_type: CommandType, params: Optional[dict] = None) -> Response:
        command = Command(
            command_id=self._generate_command_id(),
            type=command_type,
            params=params
        )
        return await manager.send_command(self.client_id, command)
        
    async def ping(self) -> bool:
        try:
            response = await self._send_command(CommandType.PING)
            return response.status == ResponseStatus.SUCCESS
        except Exception as e:
            print(f"Ping failed: {e}")
            return False
            
    async def get_status(self) -> Optional[StatusData]:
        try:
            response = await self._send_command(CommandType.GET_STATUS)
            if response.status == ResponseStatus.SUCCESS and response.data:
                return StatusData(**response.data)
            return None
        except Exception as e:
            print(f"Get status failed: {e}")
            return None
            
    async def send_otp(self, phone: str, country: str) -> Optional[str]:
        try:
            params = SendOTPParams(phone=phone, country=country)
            response = await self._send_command(CommandType.SEND_OTP, params.dict())
            if response.status == ResponseStatus.SUCCESS and response.data:
                return response.data.get("transaction_id")
            else:
                print(f"Send OTP failed: {response.error}")
                return None
        except Exception as e:
            print(f"Send OTP error: {e}")
            return None
            
    async def verify_otp(self, transaction_id: str, code: str) -> Optional[str]:
        try:
            params = VerifyOTPParams(transaction_id=transaction_id, code=code)
            response = await self._send_command(CommandType.VERIFY_OTP, params.dict())
            if response.status == ResponseStatus.SUCCESS and response.data:
                return response.data.get("bearer_token")
            else:
                print(f"Verify OTP failed: {response.error}")
                return None
        except Exception as e:
            print(f"Verify OTP error: {e}")
            return None
            
    async def get_profile(self) -> Optional[Dict[str, Any]]:
        try:
            response = await self._send_command(CommandType.GET_PROFILE)
            if response.status == ResponseStatus.SUCCESS:
                return response.data
            else:
                print(f"Get profile failed: {response.error}")
                return None
        except Exception as e:
            print(f"Get profile error: {e}")
            return None
            
    async def get_circles(self) -> Optional[List[Dict[str, Any]]]:
        try:
            response = await self._send_command(CommandType.GET_CIRCLES)
            if response.status == ResponseStatus.SUCCESS and response.data:
                return response.data.get("circles", [])
            else:
                print(f"Get circles failed: {response.error}")
                return None
        except Exception as e:
            print(f"Get circles error: {e}")
            return None
            
    async def get_circle_members(self, circle_id: str) -> Optional[Dict[str, Any]]:
        try:
            params = GetCircleMembersParams(circle_id=circle_id)
            response = await self._send_command(CommandType.GET_CIRCLE_MEMBERS, params.dict())
            if response.status == ResponseStatus.SUCCESS:
                return response.data
            else:
                print(f"Get circle members failed: {response.error}")
                return None
        except Exception as e:
            print(f"Get circle members error: {e}")
            return None
            
    async def get_device_locations(self, circle_ids: List[str]) -> Optional[Dict[str, Any]]:
        try:
            params = GetDeviceLocationsParams(circle_ids=circle_ids)
            response = await self._send_command(CommandType.GET_DEVICE_LOCATIONS, params.dict())
            if response.status == ResponseStatus.SUCCESS:
                return response.data
            else:
                print(f"Get device locations failed: {response.error}")
                return None
        except Exception as e:
            print(f"Get device locations error: {e}")
            return None

