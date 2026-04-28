import os
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv # type: ignore
from pathlib import Path

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

from app.database import Base, engine
from app.routes import users, events, admin
from app.routes import analytics

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
PROD_ORIGINS = ["https://zynkup.yourdomain.com"]
origins = DEV_ORIGINS if ENV != "production" else PROD_ORIGINS

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

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(events.router)
app.include_router(admin.router)
app.include_router(analytics.router)

@app.get("/", tags=["Health"])
def home():
    return {"message": "Zynkup API is live!", "version": "1.0.0"}