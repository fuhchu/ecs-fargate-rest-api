"""Items API — a small REST service.

This is the application we will containerize (Milestone 2) and deploy to
AWS ECS Fargate (Milestones 3-5). It is deliberately simple so the focus
stays on the infrastructure and pipeline around it.

Persistence note: state is kept in memory on purpose. A real database
(AWS RDS) is introduced in Project 2 — keeping it in memory here means a
restart wipes data, which is fine for a single-instance demo and keeps
Project 1 focused on the deployment story.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Items API", version="0.1.0")


# ---- Data models ----
# Pydantic models give us request validation and response shaping for free.
class ItemIn(BaseModel):
    """Fields a client sends when creating an item."""

    name: str
    description: str | None = None


class Item(ItemIn):
    """An item as stored and returned by the API (adds the server-assigned id)."""

    id: int


# ---- In-memory store ----
_items: dict[int, Item] = {}
_next_id = 1


# ---- Endpoints ----
@app.get("/health")
def health() -> dict[str, str]:
    """Health check endpoint.

    The Application Load Balancer (Milestone 4) calls this URL repeatedly.
    If it returns HTTP 200, the container is considered healthy and is sent
    traffic; if it fails, ECS will stop routing to it and can replace it.
    Keep it cheap and dependency-free.
    """
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    """Basic service identity — handy as a smoke test after deploy."""
    return {"service": "items-api", "version": app.version}


@app.get("/items", response_model=list[Item])
def list_items() -> list[Item]:
    return list(_items.values())


@app.post("/items", response_model=Item, status_code=201)
def create_item(payload: ItemIn) -> Item:
    global _next_id
    item = Item(id=_next_id, **payload.model_dump())
    _items[item.id] = item
    _next_id += 1
    return item


@app.get("/items/{item_id}", response_model=Item)
def get_item(item_id: int) -> Item:
    item = _items.get(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
