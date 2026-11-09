"""Integration tests: the real FastAPI app, routes, auth and SQLite DB via TestClient."""
from tests import _env  # noqa: F401  (must be first: configures env)

import json
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app

client = TestClient(app, raise_server_exceptions=False)
MB = 1024 * 1024


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def signup(prefix: str = "user", password: str = "password123") -> tuple[str, int, str]:
    email = _env.unique_email(prefix)
    r = client.post("/users/signup", json={"email": email, "password": password, "name": prefix})
    assert r.status_code == 201, r.text
    body = r.json()
    return body["access_token"], body["user"]["id"], email


def create_club(token: str) -> int:
    r = client.post(
        "/clubs/",
        headers=auth(token),
        json={"name": "Club " + _env.unique_email("c")[:12], "description": "d", "category": "tech"},
    )
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def create_event(token: str) -> int:
    r = client.post(
        "/events/",
        headers=auth(token),
        json={
            "title": "Test Event",
            "description": "desc",
            "venue": "Hall A",
            "date": (datetime.utcnow() + timedelta(days=7)).isoformat() + "Z",
            "category": "tech",
        },
    )
    assert r.status_code == 201, r.text
    return r.json()["id"] if "id" in r.json() else int(r.json()["event"]["id"])


class HealthTests(unittest.TestCase):
    def test_root(self):
        self.assertEqual(client.get("/").status_code, 200)


class AuthFlowTests(unittest.TestCase):
    def test_signup_requires_8_char_password(self):
        r = client.post("/users/signup", json={"email": _env.unique_email(), "password": "short12"})
        self.assertEqual(r.status_code, 400)

    def test_duplicate_signup_rejected(self):
        _, _, email = signup()
        r = client.post("/users/signup", json={"email": email, "password": "password123"})
        self.assertEqual(r.status_code, 400)

    def test_login_and_me(self):
        _, _, email = signup()
        r = client.post("/users/login", json={"email": email, "password": "password123"})
        self.assertEqual(r.status_code, 200)
        me = client.get("/users/me", headers=auth(r.json()["access_token"]))
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.json()["email"], email)

    def test_protected_route_requires_token(self):
        self.assertIn(client.get("/users/me").status_code, (401, 403))
        self.assertEqual(client.get("/users/me", headers=auth("garbage")).status_code, 401)

    def test_login_lockout_after_10_failures_is_per_account(self):
        _, _, victim = signup("victim")
        _, _, other = signup("other")
        codes = [
            client.post("/users/login", json={"email": victim, "password": "wrong-pass"}).status_code
            for _ in range(11)
        ]
        self.assertEqual(codes[:10], [401] * 10)
        self.assertEqual(codes[10], 429)
        # Even the right password is refused while locked.
        r = client.post("/users/login", json={"email": victim, "password": "password123"})
        self.assertEqual(r.status_code, 429)
        r = client.post("/users/login", json={"email": other, "password": "password123"})
        self.assertEqual(r.status_code, 200)


class GoogleAuthTests(unittest.TestCase):
    def _google(self, payload: dict):
        resp = MagicMock(status_code=200)
        resp.json.return_value = payload
        with patch("httpx.AsyncClient.get", new=AsyncMock(return_value=resp)):
            return client.post("/users/google", json={"id_token": "tok"})

    def _payload(self, email: str, **overrides) -> dict:
        base = {
            "iss": "https://accounts.google.com",
            "aud": _env.WEB_CLIENT_ID,
            "sub": "g-" + email,
            "email": email,
            "email_verified": "true",
        }
        base.update(overrides)
        return base

    def test_token_for_another_app_rejected(self):
        r = self._google(self._payload(_env.unique_email(), aud="other.apps.googleusercontent.com"))
        self.assertEqual(r.status_code, 401)

    def test_unverified_email_rejected(self):
        r = self._google(self._payload(_env.unique_email(), email_verified="false"))
        self.assertEqual(r.status_code, 401)

    def test_bad_issuer_rejected(self):
        r = self._google(self._payload(_env.unique_email(), iss="https://evil.example.com"))
        self.assertEqual(r.status_code, 401)

    def test_valid_token_links_existing_account(self):
        _, user_id, email = signup()
        r = self._google(self._payload(email))
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["user"]["id"], user_id)

    def test_valid_token_creates_new_account(self):
        r = self._google(self._payload(_env.unique_email("gnew")))
        self.assertEqual(r.status_code, 200)
        self.assertIn("access_token", r.json())


class ProfilePrivacyTests(unittest.TestCase):
    def test_stranger_cannot_see_contact_details(self):
        ta, ida, email_a = signup("alice")
        tb, _, _ = signup("bob")
        r = client.get(f"/users/{ida}", headers=auth(tb)).json()
        self.assertIsNone(r["email"])
        self.assertIsNone(r["phone"])
        self.assertIsNone(r["enrollment"])
        self.assertEqual(r["username"], email_a.split("@")[0])

    def test_self_and_friend_can_see_email(self):
        ta, ida, email_a = signup("alice")
        tb, idb, _ = signup("bob")
        self.assertEqual(client.get(f"/users/{ida}", headers=auth(ta)).json()["email"], email_a)
        req = client.post(f"/friends/request/{ida}", headers=auth(tb))
        self.assertEqual(req.status_code, 200, req.text)
        pending = client.get("/friends/pending", headers=auth(ta)).json()
        request_id = pending[0]["id"]
        self.assertEqual(client.put(f"/friends/request/{request_id}/accept", headers=auth(ta)).status_code, 200)
        self.assertEqual(client.get(f"/users/{ida}", headers=auth(tb)).json()["email"], email_a)


class ClubChatTests(unittest.TestCase):
    def setUp(self):
        self.owner, self.owner_id, _ = signup("owner")
        self.stranger, _, _ = signup("stranger")
        self.club_id = create_club(self.owner)

    def test_history_is_members_only(self):
        self.assertEqual(client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.stranger)).status_code, 403)
        self.assertEqual(client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.owner)).status_code, 200)

    def test_member_can_read_after_joining(self):
        self.assertEqual(client.post(f"/clubs/{self.club_id}/join", headers=auth(self.stranger)).status_code, 200)
        self.assertEqual(client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.stranger)).status_code, 200)

    def test_websocket_validation_edit_and_delete(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            ws.send_text(json.dumps({"content": "hi", "attachment_url": "javascript:alert(1)", "attachment_type": "evil"}))
            msg = ws.receive_json()["message"]
            self.assertEqual(msg["content"], "hi")
            self.assertIsNone(msg["attachment_url"])
            self.assertIsNone(msg["attachment_type"])

            ws.send_text("x" * 5000)
            self.assertEqual(len(ws.receive_json()["message"]["content"]), 4000)

            ws.send_text("   ")  # ignored
            ws.send_text("plain")
            msg = ws.receive_json()["message"]
            self.assertEqual(msg["content"], "plain")

            r = client.put(f"/clubs/{self.club_id}/chat/{msg['id']}", headers=auth(self.owner), json={"content": "edited"})
            self.assertEqual(r.status_code, 200, r.text)
            r = client.delete(f"/clubs/{self.club_id}/chat/{msg['id']}", headers=auth(self.owner))
            self.assertIn("everyone", r.json()["message"])

        history = client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.owner)).json()
        self.assertEqual(len(history), 3)

    def test_websocket_rejects_non_member_and_bad_token(self):
        for token in (self.stranger, "garbage"):
            with self.assertRaises(WebSocketDisconnect):
                with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={token}") as ws:
                    ws.receive_text()

    def test_chat_upload_rules(self):
        url = f"/clubs/{self.club_id}/chat/upload"
        r = client.post(url, headers=auth(self.owner), files={"file": ("x.exe", b"MZ", "application/octet-stream")})
        self.assertEqual(r.status_code, 400)
        r = client.post(url, headers=auth(self.owner), files={"file": ("big.png", b"0" * (10 * MB + 1), "image/png")})
        self.assertEqual(r.status_code, 400)
        r = client.post(url, headers=auth(self.owner), files={"file": ("ok.png", b"\x89PNG", "image/png")})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["type"], "image")
        r = client.post(url, headers=auth(self.stranger), files={"file": ("ok.png", b"\x89PNG", "image/png")})
        self.assertEqual(r.status_code, 403)


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.token, _, _ = signup("uploader")

    def test_generic_upload_limits_and_storage(self):
        r = client.post("/upload", headers=auth(self.token), files={"file": ("a.png", b"0" * (15 * MB + 1), "image/png")})
        self.assertEqual(r.status_code, 400)
        size = 3 * MB + 7
        r = client.post("/upload", headers=auth(self.token), files={"file": ("a.png", b"0" * size, "image/png")})
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual((Path("uploads") / r.json()["filename"]).stat().st_size, size)
        r = client.post("/upload", headers=auth(self.token), files={"file": ("a.html", b"<script>", "text/html")})
        self.assertEqual(r.status_code, 400)

    def test_club_gallery_upload(self):
        club_id = create_club(self.token)
        url = f"/clubs/{club_id}/gallery"
        r = client.post(url, headers=auth(self.token), files=[("files", ("g.png", b"0" * (15 * MB + 1), "image/png"))])
        self.assertEqual(r.status_code, 400)
        r = client.post(url, headers=auth(self.token), files=[("files", ("g.png", b"\x89PNG", "image/png"))])
        self.assertEqual(r.status_code, 200, r.text)

    def test_event_gallery_upload_and_permissions(self):
        event_id = create_event(self.token)
        url = f"/events/{event_id}/gallery"
        r = client.post(url, headers=auth(self.token), files=[("files", ("g.png", b"0" * (15 * MB + 1), "image/png"))])
        self.assertEqual(r.status_code, 400)
        r = client.post(url, headers=auth(self.token), files=[("files", ("g.png", b"\x89PNG", "image/png"))])
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["total"], 1)
        other, _, _ = signup("not-organizer")
        r = client.post(url, headers=auth(other), files=[("files", ("g.png", b"\x89PNG", "image/png"))])
        self.assertEqual(r.status_code, 403)
        r = client.get(url)
        self.assertEqual(r.status_code, 200)


class EventListTests(unittest.TestCase):
    def test_limit_is_clamped_not_rejected(self):
        self.assertEqual(client.get("/events/?limit=100000&skip=-5").status_code, 200)
        self.assertEqual(client.get("/events/?limit=0").status_code, 200)


class AdminTests(unittest.TestCase):
    def test_set_role_requires_header_key(self):
        _, _, email = signup("promote")
        params = {"email": email, "role": "organizer"}
        self.assertEqual(client.put("/admin/set-role", params={**params, "setup_key": _env.ADMIN_KEY}).status_code, 403)
        self.assertEqual(client.put("/admin/set-role", params=params, headers={"X-Admin-Setup-Key": "nope"}).status_code, 403)
        self.assertEqual(client.put("/admin/set-role", params=params, headers={"X-Admin-Setup-Key": _env.ADMIN_KEY}).status_code, 200)

    def test_duplicate_endpoint_removed_and_cleanup_is_post_only(self):
        self.assertIn(client.put("/users/set-role").status_code, (404, 405, 422))
        self.assertEqual(client.get("/admin/cleanup-broken-images", headers={"X-Admin-Setup-Key": _env.ADMIN_KEY}).status_code, 405)
        self.assertEqual(client.post("/admin/cleanup-broken-images", headers={"X-Admin-Setup-Key": _env.ADMIN_KEY}).status_code, 200)


class AuthenticatedPagesTests(unittest.TestCase):
    def test_pages_using_time_helpers_load(self):
        token, _, _ = signup("pages")
        for path in ("/analytics/me", "/analytics/heatmap", "/feed/", "/users/me/timeline", "/notifications", "/friends/"):
            self.assertEqual(client.get(path, headers=auth(token)).status_code, 200, path)


def create_post(token: str, **fields):
    body = {"content": "hello campus", **fields}
    return client.post("/feed/", headers=auth(token), json=body)


class FeedSecurityTests(unittest.TestCase):
    def setUp(self):
        self.owner, _, _ = signup("clubowner")
        self.stranger, _, _ = signup("stranger")
        self.club_id = create_club(self.owner)

    def test_only_members_can_post_as_club(self):
        r = create_post(self.stranger, club_id=self.club_id)
        self.assertEqual(r.status_code, 403)
        self.assertEqual(create_post(self.owner, club_id=self.club_id).status_code, 200)
        client.post(f"/clubs/{self.club_id}/join", headers=auth(self.stranger))
        self.assertEqual(create_post(self.stranger, club_id=self.club_id).status_code, 200)
        self.assertEqual(create_post(self.owner, club_id=999999).status_code, 404)

    def test_report_counts_each_account_once(self):
        post_id = create_post(self.owner).json()["id"]
        counts = [
            client.post(f"/feed/{post_id}/report", headers=auth(self.stranger)).json()["report_count"]
            for _ in range(12)
        ]
        self.assertEqual(counts, [1] * 12)
        feed_ids = [p["id"] for p in client.get("/feed/", headers=auth(self.owner)).json()]
        self.assertIn(post_id, feed_ids)

    def test_reported_post_can_still_be_deleted(self):
        post_id = create_post(self.owner).json()["id"]
        client.post(f"/feed/{post_id}/report", headers=auth(self.stranger))
        self.assertEqual(client.delete(f"/feed/{post_id}", headers=auth(self.owner)).status_code, 200)

    def test_unsafe_urls_rejected(self):
        for field, value in (
            ("link_url", "javascript:alert(1)"),
            ("image_url", "data:text/html,<script>x</script>"),
            ("banner_url", "file:///etc/passwd"),
        ):
            r = create_post(self.owner, **{field: value})
            self.assertEqual(r.status_code, 400, field)

    def test_scheme_less_link_normalized_and_spoofed_type_ignored(self):
        r = create_post(self.owner, link_url="youtube.com/watch?v=1", link_type="<script>")
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["link_url"], "https://youtube.com/watch?v=1")
        self.assertEqual(r.json()["link_type"], "youtube")

    def test_edit_cannot_add_unsafe_link(self):
        post_id = create_post(self.owner).json()["id"]
        r = client.patch(f"/feed/{post_id}", headers=auth(self.owner), json={"link_url": "javascript:alert(1)"})
        self.assertEqual(r.status_code, 400)

    def test_length_limits(self):
        self.assertEqual(create_post(self.owner, content="x" * 5001).status_code, 400)
        self.assertEqual(create_post(self.owner, content="x" * 5000).status_code, 200)
        self.assertEqual(create_post(self.owner, content="   ").status_code, 400)
        post_id = create_post(self.owner).json()["id"]
        r = client.post(f"/feed/{post_id}/comments", headers=auth(self.stranger), json={"content": "y" * 2001})
        self.assertEqual(r.status_code, 400)
        r = client.post(f"/feed/{post_id}/react", headers=auth(self.stranger), json={"emoji": "z" * 50})
        self.assertEqual(r.status_code, 400)
        r = client.post(f"/feed/{post_id}/react", headers=auth(self.stranger), json={"emoji": "fire"})
        self.assertEqual(r.status_code, 200)

    def test_poll_validation_and_votes(self):
        r = create_post(self.owner, poll_question="Best?", poll_options=["only one"])
        self.assertEqual(r.status_code, 400)
        r = create_post(self.owner, poll_question="Best?", poll_options=[str(i) for i in range(11)])
        self.assertEqual(r.status_code, 400)
        r = create_post(self.owner, poll_question="Best?", poll_options=["A", "B"])
        self.assertEqual(r.status_code, 200, r.text)
        post_id = r.json()["id"]
        for bad in (-1, 2, 999):
            v = client.post(f"/feed/{post_id}/poll/vote", headers=auth(self.stranger), json={"option_index": bad})
            self.assertEqual(v.status_code, 400, bad)
        v = client.post(f"/feed/{post_id}/poll/vote", headers=auth(self.stranger), json={"option_index": 1})
        self.assertEqual(v.status_code, 200)


class XpCapTests(unittest.TestCase):
    def test_post_xp_stops_after_daily_cap(self):
        token, _, _ = signup("xpfarmer")
        start = client.get("/users/me", headers=auth(token)).json()["xp"]
        for _ in range(8):
            self.assertEqual(create_post(token).status_code, 200)
        xp = client.get("/users/me", headers=auth(token)).json()["xp"]
        # 5 capped post awards x 20 XP; /users/me itself may add the 5 XP daily login once.
        self.assertIn(xp - start, (100, 105))


class ClubRulesTests(unittest.TestCase):
    def setUp(self):
        self.owner, _, _ = signup("owner2")
        self.member, self.member_id, _ = signup("member2")
        self.club_id = create_club(self.owner)
        client.post(f"/clubs/{self.club_id}/join", headers=auth(self.member))

    def test_role_allow_list(self):
        url = f"/clubs/{self.club_id}/members/{self.member_id}/role"
        for bad in ("superadmin", "owner", ""):
            self.assertEqual(client.put(url, headers=auth(self.owner), json={"role": bad}).status_code, 400, bad)
        r = client.put(url, headers=auth(self.owner), json={"role": "Moderator", "custom_role": "Tech Lead"})
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["role"], "moderator")
        r = client.put(url, headers=auth(self.owner), json={"role": "member", "custom_role": "x" * 51})
        self.assertEqual(r.status_code, 400)

    def test_club_fields_validated(self):
        r = client.put(f"/clubs/{self.club_id}", headers=auth(self.owner), json={"logo_url": "javascript:alert(1)"})
        self.assertEqual(r.status_code, 400)
        r = client.put(f"/clubs/{self.club_id}", headers=auth(self.owner), json={"name": "n" * 101})
        self.assertEqual(r.status_code, 400)
        r = client.post("/clubs/", headers=auth(self.owner), json={"name": "  ", "category": "tech"})
        self.assertEqual(r.status_code, 400)

    def test_removed_member_socket_is_closed(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.member}") as ws:
            ws.send_text("first")
            self.assertEqual(ws.receive_json()["message"]["content"], "first")
            r = client.delete(f"/clubs/{self.club_id}/members/{self.member_id}", headers=auth(self.owner))
            self.assertEqual(r.status_code, 200)
            ws.send_text("after removal")
            with self.assertRaises(WebSocketDisconnect):
                ws.receive_json()
        history = client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.owner)).json()
        self.assertEqual([m["content"] for m in history], ["first"])

    def test_chat_edit_length(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            ws.send_text("hi")
            mid = ws.receive_json()["message"]["id"]
        url = f"/clubs/{self.club_id}/chat/{mid}"
        self.assertEqual(client.put(url, headers=auth(self.owner), json={"content": "x" * 4001}).status_code, 400)
        self.assertEqual(client.put(url, headers=auth(self.owner), json={"content": " "}).status_code, 400)


class ChatPollTests(unittest.TestCase):
    def setUp(self):
        self.owner, _, _ = signup("pollowner")
        self.member, self.member_id, _ = signup("pollmember")
        self.stranger, _, _ = signup("pollstranger")
        self.club_id = create_club(self.owner)
        client.post(f"/clubs/{self.club_id}/join", headers=auth(self.member))

    def _send_poll(self, ws, question, options):
        ws.send_text(json.dumps({"poll": {"question": question, "options": options}}))
        return ws.receive_json()

    def _vote(self, token, message_id, index):
        return client.post(
            f"/clubs/{self.club_id}/chat/{message_id}/poll/vote",
            headers=auth(token), json={"option_index": index},
        )

    def test_invalid_polls_get_error_and_are_not_saved(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            for question, options in (
                ("", ["A", "B"]),
                ("Q?", ["only"]),
                ("Q?", [str(i) for i in range(11)]),
                ("Q?", ["Same", "same"]),
                ("Q?", ["A", "x" * 101]),
                ("q" * 301, ["A", "B"]),
            ):
                reply = self._send_poll(ws, question, options)
                self.assertEqual(reply["action"], "error", (question, options))
            ws.send_json({"poll": "not-a-dict"})
            self.assertEqual(ws.receive_json()["action"], "error")
        history = client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.owner)).json()
        self.assertEqual(history, [])

    def test_create_vote_and_change_vote(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.member}") as ws:
            reply = self._send_poll(ws, "  Meet when? ", [" Mon ", "Tue", "  "])
            self.assertEqual(reply["action"], "new")
            msg = reply["message"]
            self.assertEqual(msg["content"], "Meet when?")
            self.assertEqual(msg["poll"], {"question": "Meet when?", "options": ["Mon", "Tue"], "votes": {}})

            r = self._vote(self.owner, msg["id"], 1)
            self.assertEqual(r.status_code, 200, r.text)
            update = ws.receive_json()
            self.assertEqual(update["action"], "poll_vote")
            self.assertEqual(update["message_id"], msg["id"])
            self.assertEqual(list(update["poll"]["votes"].values()), [1])

            # Voting again changes the vote instead of adding one.
            self.assertEqual(self._vote(self.owner, msg["id"], 0).status_code, 200)
            self.assertEqual(list(ws.receive_json()["poll"]["votes"].values()), [0])

        for bad in (-1, 2):
            self.assertEqual(self._vote(self.owner, msg["id"], bad).status_code, 400, bad)
        self.assertEqual(self._vote(self.stranger, msg["id"], 0).status_code, 403)

        history = client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.member)).json()
        self.assertEqual(history[0]["poll"]["votes"], {next(iter(history[0]["poll"]["votes"])): 0})

    def test_plain_messages_have_no_poll_and_cannot_be_voted(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            ws.send_text("hello")
            msg = ws.receive_json()["message"]
        self.assertIsNone(msg["poll"])
        self.assertEqual(self._vote(self.owner, msg["id"], 0).status_code, 404)

    def test_poll_cannot_be_edited_and_delete_removes_it(self):
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            msg = self._send_poll(ws, "Pizza?", ["Yes", "No"])["message"]
        url = f"/clubs/{self.club_id}/chat/{msg['id']}"
        self.assertEqual(client.put(url, headers=auth(self.owner), json={"content": "x"}).status_code, 400)
        self.assertEqual(client.delete(url, headers=auth(self.owner)).status_code, 200)
        history = client.get(f"/clubs/{self.club_id}/chat", headers=auth(self.owner)).json()
        self.assertTrue(history[0]["is_deleted"])
        self.assertIsNone(history[0]["poll"])
        self.assertEqual(self._vote(self.member, msg["id"], 0).status_code, 404)

    def test_club_with_feed_and_chat_polls_can_be_deleted(self):
        r = create_post(self.owner, club_id=self.club_id, poll_question="Q?", poll_options=["A", "B"])
        self.assertEqual(r.status_code, 200, r.text)
        client.post(f"/feed/{r.json()['id']}/react", headers=auth(self.member), json={"emoji": "fire"})
        with client.websocket_connect(f"/clubs/{self.club_id}/chat/ws?token={self.owner}") as ws:
            self._send_poll(ws, "Q?", ["A", "B"])
        r = client.delete(f"/clubs/{self.club_id}", headers=auth(self.owner))
        self.assertEqual(r.status_code, 200, r.text)


class EventAndProfileValidationTests(unittest.TestCase):
    def test_event_registration_link_must_be_http(self):
        token, _, _ = signup("organizer")
        event_id = create_event(token)
        r = client.put(f"/events/{event_id}", headers=auth(token), json={"registration_url": "javascript:alert(1)"})
        self.assertEqual(r.status_code, 400)
        r = client.put(f"/events/{event_id}", headers=auth(token), json={"registration_url": "forms.gle/abc"})
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(client.get(f"/events/{event_id}").json()["registration_url"], "https://forms.gle/abc")
        r = client.put(f"/events/{event_id}", headers=auth(token), json={"title": "t" * 201})
        self.assertEqual(r.status_code, 400)

    def test_profile_fields_validated(self):
        token, _, _ = signup("profile")
        for body in ({"avatar_url": "javascript:alert(1)"}, {"banner_url": "data:image/svg+xml,x"}, {"bio": "b" * 501}, {"name": "n" * 101}):
            self.assertEqual(client.put("/users/me", headers=auth(token), json=body).status_code, 400, body)
        ok = client.put("/users/me", headers=auth(token), json={"avatar_url": "https://cdn.example.com/a.png", "banner_url": "", "bio": "hi"})
        self.assertEqual(ok.status_code, 200, ok.text)


@app.get("/__test_boom")
def _boom():
    raise RuntimeError("secret internal detail")


class ErrorAndCorsTests(unittest.TestCase):
    def test_500_hides_details_and_blocks_foreign_origin(self):
        r = client.get("/__test_boom", headers={"Origin": "https://evil.vercel.app"})
        self.assertEqual(r.status_code, 500)
        self.assertNotIn("secret", r.text)
        self.assertNotIn("access-control-allow-origin", r.headers)

    def test_500_keeps_cors_for_own_origin(self):
        r = client.get("/__test_boom", headers={"Origin": "https://zynkup-app.vercel.app"})
        self.assertEqual(r.headers.get("access-control-allow-origin"), "https://zynkup-app.vercel.app")

    def test_preflight(self):
        evil = client.options("/", headers={"Origin": "https://evil.vercel.app", "Access-Control-Request-Method": "GET"})
        self.assertIsNone(evil.headers.get("access-control-allow-origin"))
        own = client.options("/", headers={"Origin": "https://zynkup-app.vercel.app", "Access-Control-Request-Method": "GET"})
        self.assertEqual(own.headers.get("access-control-allow-origin"), "https://zynkup-app.vercel.app")


if __name__ == "__main__":
    unittest.main()
