from fastapi import HTTPException, UploadFile

_CHUNK_SIZE = 1024 * 1024  # 1MB


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
