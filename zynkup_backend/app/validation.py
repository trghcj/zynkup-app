"""Input validation shared by routes: safe URLs and text length limits."""
from typing import Optional
from urllib.parse import urlparse

from fastapi import HTTPException

MAX_URL_LENGTH = 2048

# Text limits (characters)
MAX_POST_CONTENT = 5000
MAX_COMMENT = 2000
MAX_LINK_TITLE = 200
MAX_POLL_QUESTION = 300
MAX_POLL_OPTION = 100
MIN_POLL_OPTIONS = 2
MAX_POLL_OPTIONS = 10
MAX_REACTION = 16
MAX_NAME = 100
MAX_SHORT_TEXT = 200  # college names, phone, branch, category, etc.
MAX_BIO = 500
MAX_CLUB_DESCRIPTION = 3000
MAX_EVENT_DESCRIPTION = 10000
MAX_CUSTOM_ROLE = 50


def safe_url(value: Optional[str], field: str) -> Optional[str]:
    """Return a trimmed http(s) URL, None for empty input, or raise 400.

    Blocks javascript:, data:, file:, intent: and other schemes that the app
    would otherwise hand straight to url_launcher / image loaders.
    """
    if value is None:
        return None
    url = value.strip()
    if not url:
        return None
    if len(url) > MAX_URL_LENGTH:
        raise HTTPException(status_code=400, detail=f"{field} is too long")
    parsed = urlparse(url)
    if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc:
        raise HTTPException(status_code=400, detail=f"{field} must be an http(s) URL")
    return url


def safe_link(value: Optional[str], field: str) -> Optional[str]:
    """Like safe_url, but accepts scheme-less links people commonly paste
    (e.g. "youtube.com/watch?v=x") by assuming https://."""
    if value is None or not value.strip():
        return None
    url = value.strip()
    if "://" not in url and not url.lower().startswith(("javascript:", "data:", "file:", "intent:", "vbscript:")):
        url = "https://" + url
    return safe_url(url, field)


def check_length(value: Optional[str], limit: int, field: str) -> Optional[str]:
    if value is not None and len(value) > limit:
        raise HTTPException(status_code=400, detail=f"{field} must be at most {limit} characters")
    return value
