# app/database.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# ── Database URL ──────────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("❌ DATABASE_URL is not set. Please configure it in environment variables.")

def normalize_database_url(url: str) -> str:
    """Pin Postgres URLs to the psycopg2 driver (the one in requirements.txt).

    - `postgres://` (Render/Heroku style) is not accepted by SQLAlchemy at all.
    - A bare `postgresql://` uses SQLAlchemy's *default* driver, which changed
      from psycopg2 to psycopg (v3) in SQLAlchemy 2.1 and crashed deploys with
      "No module named 'psycopg'". An explicit driver avoids depending on that.
    URLs that already name a driver (e.g. `postgresql+psycopg://`) are left alone.
    """
    if url.startswith("postgres://"):
        return "postgresql+psycopg2://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        return "postgresql+psycopg2://" + url[len("postgresql://"):]
    return url


DATABASE_URL = normalize_database_url(DATABASE_URL)

# ── Engine ────────────────────────────────────────────────────────────────────
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

# ── Session ───────────────────────────────────────────────────────────────────
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# ── Base ──────────────────────────────────────────────────────────────────────
class Base(DeclarativeBase):
    pass


# ── Dependency ────────────────────────────────────────────────────────────────
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()