# Life360 Remote Controller

This project lets you control Life360 **remotely** from a server using a FastAPI server and websockets. There's also a cli if you want to use inside the terminal.
It is designed to provide access to Life360 data (profile, circles, members, device locations) by remote-controlling an iOS app running on your own device.
You can use this to access information -- information you'd already have acccess to based on your account -- to make applications with etc. have fun!

I am not responsible for any misuse, damage, data loss, or legal consequences arising from the use of this tool. This project is intended for educational and personal purposes only. Use it at your own risk and ensure you comply with all applicable laws and the terms of service of Life360.

## Setup & Usage

### 1. Install & Run the iOS App

1. **Build the iOS app** (`Life720/Life720App.swift`) using Xcode on your iPhone or simulator.  
   - Make sure Wi-Fi is enabled and your app and computer are on the same local network.
   - The app will show a log screen, and automatically tries to connect to the server (by default at `10.0.0.0:8000`, adjustable).
   - It creates a WebSocket connection to allow remote control.

2. **Configure `Config.plist`**  
   - Copy `Config.example.plist` to `Config.plist` and fill in your Life360 Basic Auth (or leave as provided).
   - Optionally set "default" phone/country for quick login/OTP.

### 2. Run the FastAPI Server

On your computer (where you want to control the process):

```bash
# Install requirements
pip install -r requirements.txt

# Start the server
python main.py
```

The server will be available at http://localhost:8000.

**Note:** The server and your iPhone must be able to talk via IP (typically local Wi-Fi).

### 3. Run the Python CLI

Use the provided CLI to interact with the iOS app via the server:

```bash
python -m src.cli
```

You'll see an interactive menu, e.g.:

```
═══ Life360 Remote Controller ═══

● iOS App Connected

Commands:
  1. Get Device Status
  2. Send OTP
  3. Verify OTP
  4. Get Profile
  5. Get Circles
  6. Get Device Locations
  0. Exit
```

Just follow the prompts to send OTP, verify, list circles, get live locations, etc. **All data is fetched by your real iOS device!**

---

## Notes

- **NEVER use with unauthorized accounts.** This is for **educational or personal archival uses** only. You are responsible for any use of this code!
- The iOS device and your computer must be on the same network/firewall zone.

---

