import os
import uuid
from pathlib import Path
from typing import Tuple

import cloudinary.uploader
from fastapi import HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

_CHUNK_SIZE = 1024 * 1024  # 1MB

UPLOAD_DIR = "uploads"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


async def read_upload_limited(file: UploadFile, max_bytes: int) -> bytes:
    """Read an uploaded file, failing as soon as it exceeds `max_bytes`.

    Reading in chunks means an oversized upload is rejected after at most
    `max_bytes + 1MB` is held in memory, instead of loading the whole file first.
    """
    chunks = []
    total = 0
    while True:
        chunk = await file.read(_CHUNK_SIZE)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(
                status_code=400,
                detail=f"File too large. Max {max_bytes // (1024 * 1024)}MB",
            )
        chunks.append(chunk)
    return b"".join(chunks)


def public_upload_url(request: Request, filename: str) -> str:
    base_url = os.getenv("PUBLIC_BACKEND_URL", "").rstrip("/")
    if base_url:
        return f"{base_url}/uploads/{filename}"
    return str(request.url_for("uploads", path=filename))


def cloud_storage_enabled() -> bool:
    return bool(os.getenv("CLOUDINARY_CLOUD_NAME"))


async def store_upload(request: Request, contents: bytes, ext: str, prefix: str = "") -> Tuple[str, str]:
    """Save an uploaded file and return (public_url, stored_name).

    Uses Cloudinary when it is configured. The server's local disk is only a
    fallback for local development: on Render it is wiped on every deploy and
    restart, so files stored there disappear.

    `ext` must already be validated against an allow-list by the caller; the
    stored name never contains user input. The blocking upload/write runs in a
    worker thread so a large file does not stall every other request.
    """
    name = f"{prefix}{uuid.uuid4().hex}"
    if cloud_storage_enabled():
        if ext in IMAGE_EXTS:
            options = {"folder": "zynkup", "resource_type": "image"}
        else:
            # PDFs and documents are stored as raw files so they download as-is
            # (Cloudinary blocks PDF delivery as images on many accounts).
            options = {"folder": "zynkup", "resource_type": "raw", "public_id": f"{name}{ext}"}
        try:
            result = await run_in_threadpool(cloudinary.uploader.upload, contents, **options)
        except Exception as exc:
            raise HTTPException(status_code=502, detail="File storage is unavailable, please try again") from exc
        url = result.get("secure_url")
        if not url:
            raise HTTPException(status_code=502, detail="File storage is unavailable, please try again")
        return url, result.get("public_id") or name

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    filename = f"{name}{ext}"
    await run_in_threadpool((Path(UPLOAD_DIR) / filename).write_bytes, contents)
    return public_upload_url(request, filename), filename
