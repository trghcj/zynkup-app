"""Serialization shared by feed and club routes for poll attachments."""
import json
from typing import Optional


def poll_to_dict(poll, user_id: Optional[int] = None) -> Optional[dict]:
    """Return the poll as sent to the app, or None when there is no poll.

    `my_vote` is the option index the requesting user picked (None if they
    have not voted or are signed out), so the app can highlight it and let
    them change it.
    """
    if poll is None:
        return None
    votes = json.loads(poll.votes) if poll.votes else {}
    return {
        "question": poll.question,
        "options": json.loads(poll.options) if poll.options else [],
        "votes": votes,
        "my_vote": votes.get(str(user_id)) if user_id is not None else None,
    }
