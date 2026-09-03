from __future__ import annotations
import asyncio
from dataclasses import dataclass, field
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Infinite Ascension Server", version="0.1.0")

@dataclass
class Room:
    clients: dict[str, WebSocket] = field(default_factory=dict)
    state: dict = field(default_factory=lambda: {
        "players": {},
        "average_level": 5.0,
        "world_tier": 1,
        "reborn_average": 0.0,
        "frontier": {"min_level": 5, "max_level": 10},
        "generated_zones": 1,
    })
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

rooms: dict[str, Room] = {}

def get_room(room_id: str) -> Room:
    return rooms.setdefault(room_id, Room())

def recompute_world(room: Room) -> None:
    levels = [float(p.get("level", 1)) for p in room.state["players"].values()]
    if not levels:
        return
    average = sum(levels) / len(levels)
    low = max(1, int(average // 5) * 5)
    room.state["average_level"] = round(average, 2)
    room.state["frontier"] = {"min_level": low, "max_level": low + 5}
    room.state["world_tier"] = max(room.state["world_tier"], 1 + int(average // 30))

@app.get("/health")
async def health():
    return {"status": "ok", "service": "infinite-ascension", "rooms": len(rooms)}

@app.websocket("/ws/{room_id}/{player_id}")
async def socket(room_id: str, player_id: str, ws: WebSocket):
    await ws.accept()
    r = get_room(room_id)
    r.clients[player_id] = ws
    await ws.send_json({"type": "snapshot", "state": r.state})
    try:
        while True:
            msg = await ws.receive_json()
            kind = msg.get("type")
            if kind == "player_state":
                async with r.lock:
                    r.state["players"][player_id] = msg.get("player", {})
                    recompute_world(r)
                    snapshot = r.state.copy()
                await asyncio.gather(*[
                    client.send_json({"type": "state", "state": snapshot})
                    for client in list(r.clients.values())
                ], return_exceptions=True)
            elif kind == "generate_frontier":
                async with r.lock:
                    r.state["generated_zones"] += 1
                    payload = {"type": "frontier_generated", "frontier": r.state["frontier"], "generated_zones": r.state["generated_zones"]}
                await asyncio.gather(*[
                    client.send_json(payload) for client in list(r.clients.values())
                ], return_exceptions=True)
    except WebSocketDisconnect:
        r.clients.pop(player_id, None)
        r.state["players"].pop(player_id, None)
        recompute_world(r)
