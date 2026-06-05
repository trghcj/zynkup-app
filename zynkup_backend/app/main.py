import os
import uuid
import logging
from pathlib import Path

from fastapi import FastAPI, Request, UploadFile, File, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv  # type: ignore

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

from sqlalchemy import text

from app.database import Base, engine
from app.routes import users, events, analytics, admin, clubs, notifications, feed, friends
from app.auth import get_current_user
from app import models

import cloudinary
import cloudinary.uploader

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

ENV = os.getenv("ENV", "development")
logging.basicConfig(
    level=logging.DEBUG if ENV == "development" else logging.WARNING,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Zynkup API", version="2.0.0")

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

cors_origins = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "https://zynkup.vercel.app,http://localhost:3000,http://localhost:5173,http://127.0.0.1:5173",
    ).split(",")
    if origin.strip()
]

# ── CORS ──────────────────────────────────────────────────────────────────────
# Using a more robust configuration to ensure headers are always present
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=os.getenv("CORS_ORIGIN_REGEX", r"https://.*\.vercel\.app"),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"CRITICAL ERROR: {exc}", exc_info=True)
    # Manually add CORS headers to the error response to prevent "CORS Blocked" mask
    response = JSONResponse(
        status_code=500,
        content={"detail": f"Internal Server Error: {str(exc)}"}
    )
    response.headers["Access-Control-Allow-Origin"] = request.headers.get("origin") or "*"
    response.headers["Access-Control-Allow-Credentials"] = "true"
    return response

# ── DB ────────────────────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)


def repair_event_schema() -> None:
    """Keep older Render databases compatible with the current SQLAlchemy model."""
    if engine.dialect.name == "postgresql":
        statements = [
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS creator_id INTEGER REFERENCES users(id)",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS club_id INTEGER REFERENCES clubs(id)",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS image_urls TEXT DEFAULT ''",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS gallery_files TEXT DEFAULT ''",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_url VARCHAR",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_url_type VARCHAR",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW()",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS is_reported BOOLEAN DEFAULT FALSE NOT NULL",
            "ALTER TABLE events ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0 NOT NULL",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR",
            "ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS banner_url TEXT",
            "ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS is_reported BOOLEAN DEFAULT FALSE NOT NULL",
            "ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0 NOT NULL",
            "ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS club_id INTEGER REFERENCES clubs(id)",
            "ALTER TABLE club_members ADD COLUMN IF NOT EXISTS role VARCHAR DEFAULT 'member'",
            "ALTER TABLE clubs ADD COLUMN IF NOT EXISTS gallery_files TEXT DEFAULT ''",
            "ALTER TABLE club_messages ADD COLUMN IF NOT EXISTS attachment_url TEXT",
            "ALTER TABLE club_messages ADD COLUMN IF NOT EXISTS attachment_type TEXT",
            """
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='events'
                      AND column_name='image_urls'
                      AND data_type='ARRAY'
                ) THEN
                    ALTER TABLE events
                    ALTER COLUMN image_urls DROP DEFAULT,
                    ALTER COLUMN image_urls TYPE TEXT
                        USING COALESCE(array_to_string(image_urls, ','), ''),
                    ALTER COLUMN image_urls SET DEFAULT '';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='events'
                      AND column_name='gallery_files'
                      AND data_type='ARRAY'
                ) THEN
                    ALTER TABLE events
                    ALTER COLUMN gallery_files DROP DEFAULT,
                    ALTER COLUMN gallery_files TYPE TEXT
                        USING COALESCE(array_to_string(gallery_files, '|||---|||'), ''),
                    ALTER COLUMN gallery_files SET DEFAULT '';
                END IF;
            END $$;
            """,
            """
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='events' AND column_name='organizer_id'
                ) THEN
                    UPDATE events
                    SET creator_id = organizer_id
                    WHERE creator_id IS NULL AND organizer_id IS NOT NULL;
                END IF;
            END $$;
            """,
        ]

        try:
            with engine.begin() as conn:
                for statement in statements:
                    conn.execute(text(statement))
        except Exception as exc:
            logger.error(f"EVENT SCHEMA REPAIR FAILED: {exc}", exc_info=True)
    elif engine.dialect.name == "sqlite":
        statements = [
            "ALTER TABLE users ADD COLUMN fcm_token VARCHAR",
            "ALTER TABLE events ADD COLUMN club_id INTEGER",
            "ALTER TABLE clubs ADD COLUMN gallery_files TEXT",
            "ALTER TABLE feed_posts ADD COLUMN is_reported BOOLEAN DEFAULT 0 NOT NULL",
            "ALTER TABLE feed_posts ADD COLUMN report_count INTEGER DEFAULT 0 NOT NULL",
            "ALTER TABLE feed_posts ADD COLUMN club_id INTEGER",
            "ALTER TABLE club_members ADD COLUMN role VARCHAR DEFAULT 'member'",
            "ALTER TABLE club_messages ADD COLUMN attachment_url TEXT",
            "ALTER TABLE club_messages ADD COLUMN attachment_type TEXT",
        ]
        with engine.begin() as conn:
            for statement in statements:
                try:
                    conn.execute(text(statement))
                except Exception as exc:
                    # Ignore duplicate column error in SQLite
                    logger.debug(f"SQLite migration skipped/already exists: {exc}")


repair_event_schema()

# ── Uploads ──────────────────────────────────────────────────────────────────
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".pdf"}


def _public_upload_url(request: Request, filename: str) -> str:
    base_url = os.getenv("PUBLIC_BACKEND_URL", "").rstrip("/")
    if base_url:
        return f"{base_url}/uploads/{filename}"
    return str(request.url_for("uploads", path=filename))

@app.post("/upload", tags=["Upload"])
async def upload_file(
    request: Request,
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    ext = Path(file.filename or "file.jpg").suffix.lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Unsupported file type")

    contents = await file.read()
    if len(contents) > 15 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Max 15MB")

    try:
        if os.getenv("CLOUDINARY_CLOUD_NAME"):
            upload_result = cloudinary.uploader.upload(contents, folder="zynkup")
            public_url = upload_result.get("secure_url")
            filename = upload_result.get("public_id")
        else:
            filename = f"{uuid.uuid4().hex}{ext}"
            file_path = Path(UPLOAD_DIR) / filename
            file_path.write_bytes(contents)
            public_url = _public_upload_url(request, filename)
    except Exception as e:
        logger.error(f"Upload failed: {e}")
        raise HTTPException(status_code=500, detail="Upload failed")

    logger.info(f"Uploaded {filename} by user {current_user.id}")
    return {"url": public_url, "filename": filename}


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(events.router)
app.include_router(analytics.router)
app.include_router(admin.router)
app.include_router(clubs.router)
app.include_router(notifications.router)
app.include_router(feed.router)
app.include_router(friends.router)

@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API is live! "}
