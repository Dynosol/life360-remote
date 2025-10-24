from fastapi import APIRouter, WebSocket, HTTPException
from typing import List, Optional
from datetime import datetime

from .websocket_handler import manager
from .life360_service import Life360Service
from .models import (
    SendOTPParams, VerifyOTPParams, GetCircleMembersParams,
    GetDeviceLocationsParams
)

router = APIRouter()
service = Life360Service()


@router.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    await manager.listen(websocket, client_id)


@router.get("/")
async def root():
    return {
        "service": "Life360 Remote Controller",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }


@router.get("/status")
async def get_connection_status():
    clients = manager.get_connected_clients()
    return {
        "connected": len(clients) > 0,
        "clients": clients,
        "count": len(clients)
    }


@router.post("/ping")
async def ping_device():
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    result = await service.ping()
    return {"success": result}


@router.get("/device/status")
async def get_device_status():
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    status = await service.get_status()
    if status:
        return status.dict()
    raise HTTPException(status_code=500, detail="Failed to get status")


@router.post("/auth/send-otp")
async def send_otp(params: SendOTPParams):
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    transaction_id = await service.send_otp(params.phone, params.country)
    if transaction_id:
        return {"transaction_id": transaction_id}
    raise HTTPException(status_code=500, detail="Failed to send OTP")


@router.post("/auth/verify-otp")
async def verify_otp(params: VerifyOTPParams):
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    bearer = await service.verify_otp(params.transaction_id, params.code)
    if bearer:
        return {"bearer_token": bearer, "authenticated": True}
    raise HTTPException(status_code=500, detail="Failed to verify OTP")


@router.get("/profile")
async def get_profile():
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    profile = await service.get_profile()
    if profile:
        return profile
    raise HTTPException(status_code=500, detail="Failed to get profile")


@router.get("/circles")
async def get_circles():
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    circles = await service.get_circles()
    if circles is not None:
        return {"circles": circles}
    raise HTTPException(status_code=500, detail="Failed to get circles")


@router.post("/circles/{circle_id}/members")
async def get_circle_members(circle_id: str):
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    members = await service.get_circle_members(circle_id)
    if members:
        return members
    raise HTTPException(status_code=500, detail="Failed to get circle members")


@router.post("/locations")
async def get_device_locations(params: GetDeviceLocationsParams):
    if not manager.is_connected(service.client_id):
        raise HTTPException(status_code=503, detail="iOS app not connected")
    
    locations = await service.get_device_locations(params.circle_ids)
    if locations:
        return locations
    raise HTTPException(status_code=500, detail="Failed to get device locations")

