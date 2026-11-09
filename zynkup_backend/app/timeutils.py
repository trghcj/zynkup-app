from datetime import datetime, timezone


def utcnow_naive() -> datetime:
    """Current UTC time as a naive datetime.

    Drop-in replacement for the deprecated `datetime.utcnow()`. The DB columns
    are naive `DateTime` storing UTC, so values compared with or written to them
    must stay naive.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)
