import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api import router

app = FastAPI(
    title="Life360 Remote Controller",
    description="Remote control interface for Life360 iOS app",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

def main():
    print("Starting Life360 Remote Controller Server")
    print("Waiting for iOS app to connect via WebSocket...")
    print("Server running at: http://localhost:8000")
    print("API docs available at: http://localhost:8000/docs")
    print("\nTo use the interactive CLI, run: python -m src.cli\n")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )


if __name__ == "__main__":
    main()
