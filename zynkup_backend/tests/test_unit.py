"""Unit tests: pure helpers, no HTTP."""
from tests import _env  # noqa: F401  (must be first: configures env)

import asyncio
import io
import unittest
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, UploadFile
from sqlalchemy import create_engine

from app.auth import create_access_token, require_admin_setup_key, verify_access_token
from app.database import normalize_database_url
from app.main import _is_allowed_origin
from app.timeutils import utcnow_naive
from app.uploads import read_upload_limited
from app.validation import check_length, safe_link, safe_url
from app.routes import users as users_routes


class DatabaseUrlTests(unittest.TestCase):
    def test_render_style_postgres_url_gets_psycopg2_driver(self):
        self.assertEqual(
            normalize_database_url("postgres://u:p@host:5432/db"),
            "postgresql+psycopg2://u:p@host:5432/db",
        )

    def test_bare_postgresql_url_gets_psycopg2_driver(self):
        # SQLAlchemy 2.1 defaults bare postgresql:// to psycopg (v3), which
        # isn't installed; this crashed the Render deploy.
        self.assertEqual(
            normalize_database_url("postgresql://u:p@host/db"),
            "postgresql+psycopg2://u:p@host/db",
        )

    def test_explicit_driver_and_sqlite_untouched(self):
        for url in (
            "postgresql+psycopg://u:p@host/db",
            "postgresql+psycopg2://u:p@host/db",
            "sqlite:///tmp/x.db",
        ):
            self.assertEqual(normalize_database_url(url), url)

    def test_normalized_url_builds_engine_with_psycopg2(self):
        # create_engine loads the DBAPI module without connecting.
        engine = create_engine(normalize_database_url("postgresql://u:p@localhost/db"))
        self.assertEqual(engine.dialect.driver, "psycopg2")
        engine.dispose()


class TimeUtilsTests(unittest.TestCase):
    def test_utcnow_naive_is_naive_utc(self):
        now = utcnow_naive()
        self.assertIsNone(now.tzinfo)
        aware = datetime.now(timezone.utc).replace(tzinfo=None)
        self.assertLess(abs((aware - now).total_seconds()), 2)

    def test_comparable_with_naive_db_timestamps(self):
        stored = datetime(2026, 1, 1, 12, 0, 0)  # how DB DateTime columns come back
        self.assertIsInstance(utcnow_naive() - stored, timedelta)


class UploadLimitTests(unittest.TestCase):
    def _upload(self, size: int) -> UploadFile:
        return UploadFile(file=io.BytesIO(b"a" * size), filename="f.png")

    def test_reads_multi_chunk_file_intact(self):
        size = 3 * 1024 * 1024 + 123
        data = asyncio.run(read_upload_limited(self._upload(size), 5 * 1024 * 1024))
        self.assertEqual(len(data), size)

    def test_exact_limit_is_allowed(self):
        limit = 2 * 1024 * 1024
        data = asyncio.run(read_upload_limited(self._upload(limit), limit))
        self.assertEqual(len(data), limit)

    def test_over_limit_raises_400(self):
        limit = 1024 * 1024
        with self.assertRaises(HTTPException) as ctx:
            asyncio.run(read_upload_limited(self._upload(limit + 1), limit))
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("1MB", ctx.exception.detail)

    def test_empty_file(self):
        self.assertEqual(asyncio.run(read_upload_limited(self._upload(0), 10)), b"")


class TokenTests(unittest.TestCase):
    def test_roundtrip(self):
        token = create_access_token({"sub": "42"})
        self.assertEqual(verify_access_token(token)["sub"], "42")

    def test_garbage_and_tampered_tokens_rejected(self):
        token = create_access_token({"sub": "42"})
        self.assertIsNone(verify_access_token("not-a-token"))
        self.assertIsNone(verify_access_token(token[:-2] + ("AA" if token[-2:] != "AA" else "BB")))


class AdminKeyTests(unittest.TestCase):
    def test_correct_key_passes(self):
        self.assertIsNone(require_admin_setup_key(_env.ADMIN_KEY))

    def test_missing_or_wrong_key_rejected(self):
        for key in (None, "", "wrong", _env.ADMIN_KEY + "x"):
            with self.assertRaises(HTTPException) as ctx:
                require_admin_setup_key(key)
            self.assertEqual(ctx.exception.status_code, 403)


class CorsOriginTests(unittest.TestCase):
    def test_own_deployments_allowed(self):
        for origin in (
            "https://zynkup.vercel.app",
            "https://zynkup-app.vercel.app",
            "https://zynkup-app-git-dev-trghcj.vercel.app",
            "http://localhost:3000",
        ):
            self.assertTrue(_is_allowed_origin(origin), origin)

    def test_other_origins_rejected(self):
        for origin in (
            "https://evil.vercel.app",
            "https://zynkup.vercel.app.evil.com",
            "https://notzynkup.vercel.app",
            "http://zynkup-app.vercel.app",
        ):
            self.assertFalse(_is_allowed_origin(origin), origin)


class LoginLimiterTests(unittest.TestCase):
    def test_window_drops_old_attempts(self):
        key = ("1.2.3.4", "limiter@example.com")
        users_routes._login_failures.pop(key, None)
        attempts = users_routes._login_failures[key]
        attempts.extend([0.0, 1.0])
        now = users_routes._LOGIN_WINDOW_SECONDS + 0.5
        self.assertEqual(len(users_routes._recent_failures(key, now)), 1)
        users_routes._login_failures.pop(key, None)

    def test_google_audience_defaults_used_when_env_blank(self):
        self.assertIn(_env.WEB_CLIENT_ID, users_routes.GOOGLE_CLIENT_IDS)


class ValidationTests(unittest.TestCase):
    def test_safe_url_accepts_http_and_https(self):
        self.assertEqual(safe_url(" https://a.com/x ", "U"), "https://a.com/x")
        self.assertEqual(safe_url("http://a.com", "U"), "http://a.com")
        self.assertIsNone(safe_url("", "U"))
        self.assertIsNone(safe_url(None, "U"))

    def test_safe_url_rejects_dangerous_schemes(self):
        for bad in (
            "javascript:alert(1)",
            "JAVASCRIPT:alert(1)",
            "data:text/html,<b>x</b>",
            "file:///etc/passwd",
            "intent://x#Intent;end",
            "ftp://a.com",
            "https://",
            "https://" + "a" * 3000 + ".com",
        ):
            with self.assertRaises(HTTPException, msg=bad) as ctx:
                safe_url(bad, "U")
            self.assertEqual(ctx.exception.status_code, 400)

    def test_safe_link_adds_https_but_still_blocks_schemes(self):
        self.assertEqual(safe_link("youtube.com/watch?v=1", "L"), "https://youtube.com/watch?v=1")
        for bad in ("javascript:alert(1)", "data:text/html,x", "vbscript:x"):
            with self.assertRaises(HTTPException):
                safe_link(bad, "L")

    def test_check_length(self):
        self.assertEqual(check_length("abc", 3, "F"), "abc")
        self.assertIsNone(check_length(None, 3, "F"))
        with self.assertRaises(HTTPException):
            check_length("abcd", 3, "F")


class DailyXpCapTests(unittest.TestCase):
    def test_caps_cover_repeatable_actions(self):
        from app.gamification import DAILY_XP_CAPS
        for action in ("create_post", "create_comment", "join_club"):
            self.assertIn(action, DAILY_XP_CAPS)


if __name__ == "__main__":
    unittest.main()
