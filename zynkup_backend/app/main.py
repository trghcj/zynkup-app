import os
import uuid
import base64
import logging
from pathlib import Path

from fastapi import FastAPI, Request, UploadFile, File, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv  # type: ignore

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

from app.database import Base, engine
from app.routes import users, events, admin, analytics
from app.auth import get_current_user
from app import models

ENV = os.getenv("ENV", "development")
logging.basicConfig(
    level=logging.DEBUG if ENV == "development" else logging.WARNING,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("zynkup")

app = FastAPI(
    title="Zynkup API",
    description="College Event Management Platform — MAIT",
    version="1.0.0",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
ALL_ORIGINS = [
    "http://localhost:5555",
    "http://127.0.0.1:5555",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://endearing-alpaca-a16035.netlify.app",
    "https://zynkup-app.netlify.app",
    "https://zynkup-app.onrender.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALL_ORIGINS, 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global error handler ──────────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong. Please try again later."},
    )

# ── DB ────────────────────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

# ── Upload directory (local dev fallback) ─────────────────────────────────────
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp", "application/octet-stream"}


@app.post("/upload", tags=["Upload"])
async def upload_file(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    """
    Upload image — returns a base64 data URL so it works without
    external storage. Works on both local and Render deployment.
    """
    ext = Path(file.filename or "image.jpg").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        ext = ".jpg"

    contents = await file.read()

    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Max 10MB")

    # ── Convert to base64 data URL ─────────────────────────────────────────
    # This approach works everywhere without needing a CDN or static files
    mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                ".png": "image/png", ".webp": "image/webp"}
    mime = mime_map.get(ext, "image/jpeg")
    b64 = base64.b64encode(contents).decode("utf-8")
    data_url = f"data:{mime};base64,{b64}"

    logger.info(f"File uploaded as base64 by user {current_user.id}")
    return {"url": data_url, "filename": f"{uuid.uuid4().hex}{ext}"}


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(events.router)
app.include_router(admin.router)
app.include_router(analytics.router)


@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API is live!", "version": "1.0.0"}