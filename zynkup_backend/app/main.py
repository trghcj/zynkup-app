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
from app.routes import users, events, analytics
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
ORIGINS = [
    "https://zynkup-app.vercel.app",
    "https://endearing-alpaca-a16035.netlify.app",
    "https://zynkup-app.onrender.com",
    "http://localhost:5555",
    "http://127.0.0.1:5555",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled: {exc}", exc_info=True)
    return JSONResponse(status_code=500,
        content={"detail": "Something went wrong."})

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

@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API v2.0 is live! 🚀"}