# Wasteland Pawn

A clean Roblox Luau project using Rojo. Code lives in this repository and syncs into Roblox Studio. Maps, props, models, lighting, and other visual world-building can still be made directly in Studio.

## Setup

1. Install Rojo from <https://rojo.space/docs/installation/>. This project also includes `aftman.toml`, so Aftman users can run the pinned Rojo version automatically.
2. Open or create the Roblox place for Wasteland Pawn in Roblox Studio.
3. In this folder, run:

   ```sh
   rojo serve
   ```

4. In Studio, open the Rojo plugin and connect to the local Rojo server.
5. Press Play in Studio to test once gameplay has been added.

## Workflow

- Use Studio for maps, props, models, terrain, lighting, and visual layout.
- Use Rojo and Cursor for Luau code.
- Keep server code authoritative. The client can request actions, but the server owns money, item values, customer stats, deal outcomes, and inventory.

## Project Layout

- `src/ReplicatedStorage/Shared` contains shared modules used by both server and client.
- `src/ServerScriptService/Server` contains server-only startup code and services.
- `src/StarterPlayer/StarterPlayerScripts/Client` contains client startup code and controllers.

The first gameplay milestone should be a small haggling loop, not a full tycoon.
