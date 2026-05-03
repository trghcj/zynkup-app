import os
import uuid
import logging

from fastapi import FastAPI, Request, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from dotenv import load_dotenv
from pathlib import Path

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
ALLOWED_ORIGINS = [
    "https://zynkup-app.netlify.app",
    "https://endearing-alpaca-a16035.netlify.app",
    "https://zynkup-app.onrender.com",
    "http://localhost:5555",
    "http://127.0.0.1:5555",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=600,
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

# ── Upload directory ──────────────────────────────────────────────────────────
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "application/pdf"}

# ── Upload endpoint ───────────────────────────────────────────────────────────
@app.post("/upload", tags=["Upload"])
async def upload_file(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    content_type = file.content_type or ""
    ext_lower = Path(file.filename or "").suffix.lower()

    # Accept image types and PDF
    allowed_exts = {".jpg", ".jpeg", ".png", ".webp", ".pdf"}
    if ext_lower not in allowed_exts and content_type not in ALLOWED_TYPES:
        return JSONResponse(
            status_code=400,
            content={"detail": "Only JPEG, PNG, WEBP images and PDF allowed"},
        )

    contents = await file.read()
    if len(contents) > 20 * 1024 * 1024:  # 20MB limit
        return JSONResponse(
            status_code=400,
            content={"detail": "File too large. Max 20MB"},
        )

    # For production on Render — store as base64 in response
    # (Render free tier doesn't have persistent disk)
    import base64
    b64 = base64.b64encode(contents).decode()
    mime = content_type or "image/jpeg"
    data_url = f"data:{mime};base64,{b64}"

    logger.info(f"File uploaded as base64 by user {current_user.id}")
    return {"url": data_url, "filename": file.filename}


# ── Serve uploaded files ──────────────────────────────────────────────────────
@app.get("/uploads/{filename}", tags=["Upload"])
async def serve_upload(filename: str, request: Request):
    file_path = UPLOAD_DIR / filename
    if not file_path.exists():
        return JSONResponse(status_code=404, content={"detail": "File not found"})

    suffix = file_path.suffix.lower()
    media_types = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp",
        ".pdf": "application/pdf",
    }
    media_type = media_types.get(suffix, "image/jpeg")

    response = FileResponse(file_path, media_type=media_type)
    origin = request.headers.get("origin", "")
    if origin in ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
    response.headers["Cache-Control"] = "public, max-age=86400"
    return response


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(events.router)
app.include_router(admin.router)
app.include_router(analytics.router)


@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API is live!", "version": "1.0.0"}