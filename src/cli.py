import asyncio
import json
from typing import Optional
import httpx
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt, Confirm
from rich import print as rprint

console = Console()


class Life360CLI:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.transaction_id: Optional[str] = None
        self.bearer_token: Optional[str] = None
        self.circles: list = []
        
    async def check_connection(self) -> bool:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.base_url}/status")
                data = response.json()
                return data.get("connected", False)
        except Exception as e:
            console.print(f"[red]Error checking connection: {e}[/red]")
            return False
            
    async def get_device_status(self):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.base_url}/device/status")
                if response.status_code == 200:
                    data = response.json()
                    
                    table = Table(title="Device Status")
                    table.add_column("Property", style="cyan")
                    table.add_column("Value", style="green")
                    
                    table.add_row("Has Transaction", "✓" if data.get("has_transaction") else "✗")
                    table.add_row("Has Bearer", "✓" if data.get("has_bearer") else "✗")
                    table.add_row("Authenticated", "✓" if data.get("is_authenticated") else "✗")
                    
                    console.print(table)
                else:
                    console.print(f"[red]Failed to get status: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def send_otp(self):
        phone = Prompt.ask("Enter phone number")
        country = Prompt.ask("Enter country code", default="1")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/auth/send-otp",
                    json={"phone": phone, "country": country}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    self.transaction_id = data.get("transaction_id")
                    console.print(f"[green]✓ OTP sent! Transaction ID: {self.transaction_id}[/green]")
                else:
                    console.print(f"[red]Failed to send OTP: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def verify_otp(self):
        if not self.transaction_id:
            console.print("[yellow]Please send OTP first[/yellow]")
            return
            
        code = Prompt.ask("Enter OTP code")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/auth/verify-otp",
                    json={"transaction_id": self.transaction_id, "code": code}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    self.bearer_token = data.get("bearer_token")
                    console.print(f"[green]✓ Authenticated successfully![/green]")
                    console.print(f"[dim]Bearer: {self.bearer_token[:20]}...[/dim]")
                else:
                    console.print(f"[red]Failed to verify OTP: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def get_profile(self):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.base_url}/profile")
                
                if response.status_code == 200:
                    data = response.json()
                    console.print("[green]User Profile:[/green]")
                    console.print(json.dumps(data, indent=2))
                else:
                    console.print(f"[red]Failed to get profile: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def get_circles(self):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.base_url}/circles")
                
                if response.status_code == 200:
                    data = response.json()
                    self.circles = data.get("circles", [])
                    
                    if not self.circles:
                        console.print("[yellow]No circles found[/yellow]")
                        return
                    
                    table = Table(title="Circles")
                    table.add_column("#", style="cyan")
                    table.add_column("Name", style="green")
                    table.add_column("ID", style="dim")
                    
                    for idx, circle in enumerate(self.circles, 1):
                        table.add_row(
                            str(idx),
                            circle.get("name", "Unknown"),
                            circle.get("id", "")
                        )
                    
                    console.print(table)
                else:
                    console.print(f"[red]Failed to get circles: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def get_device_locations(self):
        if not self.circles:
            console.print("[yellow]Please fetch circles first[/yellow]")
            return
        
        # Ask which circles to query
        circle_input = Prompt.ask(
            "Enter circle numbers (comma-separated) or 'all'",
            default="all"
        )
        
        if circle_input.lower() == "all":
            circle_ids = [c["id"] for c in self.circles]
        else:
            try:
                indices = [int(x.strip()) - 1 for x in circle_input.split(",")]
                circle_ids = [self.circles[i]["id"] for i in indices if 0 <= i < len(self.circles)]
            except (ValueError, IndexError):
                console.print("[red]Invalid circle selection[/red]")
                return
        
        if not circle_ids:
            console.print("[yellow]No circles selected[/yellow]")
            return
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/locations",
                    json={"circle_ids": circle_ids}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    console.print("[green]Device Locations:[/green]")
                    console.print(json.dumps(data, indent=2))
                else:
                    console.print(f"[red]Failed to get locations: {response.text}[/red]")
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            
    async def show_menu(self):
        while True:
            console.print("\n[bold cyan]═══ Life360 Remote Controller ═══[/bold cyan]\n")
            
            # Check connection status
            connected = await self.check_connection()
            if connected:
                console.print("[green]● iOS App Connected[/green]")
            else:
                console.print("[red]○ iOS App Disconnected[/red]")
                console.print("[yellow]Waiting for iOS app to connect...[/yellow]")
                await asyncio.sleep(2)
                continue
            
            console.print("\n[bold]Commands:[/bold]")
            console.print("  1. Get Device Status")
            console.print("  2. Send OTP")
            console.print("  3. Verify OTP")
            console.print("  4. Get Profile")
            console.print("  5. Get Circles")
            console.print("  6. Get Device Locations")
            console.print("  0. Exit")
            
            choice = Prompt.ask("\nSelect option", choices=["0", "1", "2", "3", "4", "5", "6"])
            
            if choice == "0":
                console.print("[yellow]Goodbye![/yellow]")
                break
            elif choice == "1":
                await self.get_device_status()
            elif choice == "2":
                await self.send_otp()
            elif choice == "3":
                await self.verify_otp()
            elif choice == "4":
                await self.get_profile()
            elif choice == "5":
                await self.get_circles()
            elif choice == "6":
                await self.get_device_locations()
            
            console.print("\n[dim]Press Enter to continue...[/dim]")
            input()


async def main():
    cli = Life360CLI()
    await cli.show_menu()


if __name__ == "__main__":
    asyncio.run(main())

