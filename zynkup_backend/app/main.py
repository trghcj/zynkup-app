import os
import uuid
import logging

from fastapi import FastAPI, Request, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv  # type: ignore
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
DEV_ORIGINS = [
    "http://localhost:5555",
    "http://127.0.0.1:5555",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]
PROD_ORIGINS = [
    "https://zynkup-app.onrender.com",
    "https://endearing-alpaca-a16035.netlify.app",
]
origins = DEV_ORIGINS + PROD_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global error handler ──────────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        f"Unhandled exception on {request.method} {request.url}: {exc}",
        exc_info=True,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong. Please try again later."},
    )

# ── DB ────────────────────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

# ── Upload directory ──────────────────────────────────────────────────────────
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

# ── Upload endpoint ───────────────────────────────────────────────────────────
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}

@app.post("/upload", tags=["Upload"])
async def upload_file(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    # Accept any image content type — browser sometimes sends octet-stream
    content_type = file.content_type or ""
    if content_type not in ALLOWED_TYPES and not content_type.startswith("image/"):
        # Check by file extension as fallback
        ext_lower = Path(file.filename or "").suffix.lower()
        if ext_lower not in {".jpg", ".jpeg", ".png", ".webp"}:
            return JSONResponse(
                status_code=400,
                content={"detail": "Only JPEG, PNG, WEBP images allowed"},
            )

    contents = await file.read()

    if len(contents) > 10 * 1024 * 1024:  # 10MB limit
        return JSONResponse(
            status_code=400,
            content={"detail": "File too large. Max 10MB"},
        )

    ext = Path(file.filename).suffix.lower() if file.filename else ".jpg"
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        ext = ".jpg"

    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename

    with open(dest, "wb") as f:
        f.write(contents)

    url = f"https://zynkup-app.onrender.com/uploads/{filename}"
    logger.info(f"File uploaded: {filename} by user {current_user.id}")
    return {"url": url, "filename": filename}


# ── Serve uploaded images with CORS headers ───────────────────────────────────
# Must be BEFORE app.mount so it intercepts /uploads/* with proper CORS
@app.get("/uploads/{filename}", tags=["Upload"])
async def serve_upload(filename: str, request: Request):
    file_path = UPLOAD_DIR / filename
    if not file_path.exists():
        return JSONResponse(status_code=404, content={"detail": "File not found"})

    # Determine media type
    suffix = file_path.suffix.lower()
    media_types = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png",  ".webp": "image/webp",
    }
    media_type = media_types.get(suffix, "image/jpeg")

    response = FileResponse(file_path, media_type=media_type)

    # ✅ Add CORS headers so Flutter Web can load the image
    origin = request.headers.get("origin", "")
    if origin in origins or ENV == "development":
        response.headers["Access-Control-Allow-Origin"] = origin or "*"
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