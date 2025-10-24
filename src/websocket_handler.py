import asyncio
import json
from typing import Optional, Dict
from fastapi import WebSocket, WebSocketDisconnect
from datetime import datetime
import uuid

from .models import Command, Response, ResponseStatus


class ConnectionManager:
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.pending_commands: Dict[str, asyncio.Future] = {}
        
    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✓ iOS app connected: {client_id}")
        
    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✗ iOS app disconnected: {client_id}")
            
    async def send_command(self, client_id: str, command: Command, timeout: int = 30) -> Response:
        if client_id not in self.active_connections:
            raise Exception(f"No active connection for client: {client_id}")
        websocket = self.active_connections[client_id]
        future = asyncio.Future()
        self.pending_commands[command.command_id] = future
        try:
            await websocket.send_json(command.dict())
            print(f"[{datetime.now().strftime('%H:%M:%S')}] → Sent command: {command.type} (ID: {command.command_id})")
            response = await asyncio.wait_for(future, timeout=timeout)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ← Received response: {response.status}")
            return response
        except asyncio.TimeoutError:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✗ Command timeout: {command.command_id}")
            raise Exception(f"Command timeout after {timeout}s")
        finally:
            if command.command_id in self.pending_commands:
                del self.pending_commands[command.command_id]
                
    async def handle_response(self, response_data: dict):
        try:
            response = Response(**response_data)
            command_id = response.command_id
            if command_id in self.pending_commands:
                future = self.pending_commands[command_id]
                if not future.done():
                    future.set_result(response)
            else:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] ⚠ Received response for unknown command: {command_id}")
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✗ Error handling response: {e}")
            
    async def listen(self, websocket: WebSocket, client_id: str):
        try:
            while True:
                data = await websocket.receive_json()
                if "command_id" in data and "status" in data:
                    await self.handle_response(data)
                else:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Received unknown message type: {data}")
        except WebSocketDisconnect:
            self.disconnect(client_id)
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✗ Error in listen loop: {e}")
            self.disconnect(client_id)
            
    def get_connected_clients(self) -> list:
        return list(self.active_connections.keys())
        
    def is_connected(self, client_id: str) -> bool:
        return client_id in self.active_connections

manager = ConnectionManager()
