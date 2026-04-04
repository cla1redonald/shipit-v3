# Stack Reference: Python + FastAPI

Load this reference when working on Python projects using FastAPI.

## Project Structure

```
/src
  /app
    /api              # Route modules
      /v1             # API version
    /models           # Pydantic models + SQLAlchemy models
    /services         # Business logic
    /db               # Database connection, queries
    /auth             # Authentication utilities
    /config           # Settings and environment
    main.py           # FastAPI app entry point
/tests                # Test files (mirrors /src)
/alembic              # Database migrations
/scripts              # Utility scripts
requirements.txt      # or pyproject.toml
```

## Route Pattern

```python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/items", tags=["items"])

class ItemCreate(BaseModel):
    name: str
    description: str | None = None

class ItemResponse(BaseModel):
    id: str
    name: str
    description: str | None
    created_at: str

@router.post("/", response_model=ItemResponse)
async def create_item(item: ItemCreate, db=Depends(get_db)):
    result = await db.execute(
        insert(items).values(**item.model_dump()).returning(items)
    )
    return result.first()

@router.get("/{item_id}", response_model=ItemResponse)
async def get_item(item_id: str, db=Depends(get_db)):
    result = await db.execute(select(items).where(items.c.id == item_id))
    item = result.first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
```

## Pydantic Models

- Use Pydantic v2 (`BaseModel` from `pydantic`)
- Separate request models (Create, Update) from response models
- Use `model_dump()` not `dict()` (v2 API)
- Use `ConfigDict` for model configuration

## SQLAlchemy + Alembic

```python
# models.py
from sqlalchemy import Column, String, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
import uuid

class Item(Base):
    __tablename__ = "items"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
```

## Testing with pytest

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.mark.asyncio
async def test_create_item(client):
    response = await client.post("/items/", json={"name": "Test Item"})
    assert response.status_code == 200
    assert response.json()["name"] == "Test Item"
```

## Deployment on Vercel

FastAPI runs on Vercel via the Python runtime with Fluid Compute:

```python
# api/index.py
from app.main import app
```

```
# vercel.json
{
  "builds": [{"src": "api/index.py", "use": "@vercel/python"}],
  "routes": [{"src": "/(.*)", "dest": "api/index.py"}]
}
```

## Environment Variables

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    debug: bool = False

    class Config:
        env_file = ".env"

settings = Settings()
```

## Key Differences from Node.js

| Concept | Node.js/Next.js | Python/FastAPI |
|---------|----------------|----------------|
| Validation | Zod | Pydantic |
| ORM | Supabase client / Prisma | SQLAlchemy |
| Migrations | Supabase migrations | Alembic |
| Test runner | Vitest / Jest | pytest |
| Package manager | npm / pnpm | pip / uv / poetry |
| Type checking | TypeScript compiler | mypy / pyright |
