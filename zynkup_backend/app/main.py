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
from app.routes import users, events, analytics, admin
from app.auth import get_current_user
from app import models

ENV = os.getenv("ENV", "development")
logging.basicConfig(
    level=logging.DEBUG if ENV == "development" else logging.WARNING,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("zynkup")

app = FastAPI(title="Zynkup API", version="2.0.0")

# ── CORS ──────────────────────────────────────────────────────────────────────
# Using a more robust configuration to ensure headers are always present
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # For development, we allow all. In production, we'll use regex.
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

# ── Upload (base64 — works everywhere) ───────────────────────────────────────
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".pdf"}

@app.post("/upload", tags=["Upload"])
async def upload_file(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    ext = Path(file.filename or "file.jpg").suffix.lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Unsupported file type")

    contents = await file.read()
    if len(contents) > 15 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Max 15MB")

    mime_map = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp",
        ".pdf": "application/pdf",
    }
    mime = mime_map.get(ext, "image/jpeg")
    b64  = base64.b64encode(contents).decode("utf-8")
    data_url = f"data:{mime};base64,{b64}"

    logger.info(f"Uploaded {ext} by user {current_user.id}")
    return {"url": data_url, "filename": f"{uuid.uuid4().hex}{ext}"}


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(events.router)
app.include_router(analytics.router)
app.include_router(admin.router)

@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API is live! "}