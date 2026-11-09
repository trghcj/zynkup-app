"""Test environment. Import this module before anything from `app`.

Points the app at a throwaway SQLite database and blanks out every external
service. Variables are set to "" rather than removed, because app.main calls
load_dotenv(), which would otherwise fill them from a developer's real .env
(e.g. upload to the real Cloudinary account).
"""
import os
import sys
import tempfile
import uuid
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
TMP_DIR = Path(tempfile.mkdtemp(prefix="zynkup-tests-"))

# TEST_DATABASE_URL lets CI run the same suite against a real Postgres
# (like Render). Default is a throwaway SQLite file.
os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL") or (
    "sqlite:///" + (TMP_DIR / "test.db").as_posix()
)
os.environ["JWT_SECRET"] = "test-secret-" + "x" * 40
os.environ["JWT_ALGORITHM"] = "HS256"
os.environ["ADMIN_SETUP_KEY"] = "test-admin-key-" + "k" * 24
os.environ["ENV"] = "test"
for name in (
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
    "GOOGLE_CLIENT_ID",
    "FIREBASE_SERVICE_ACCOUNT_PATH",
    "PUBLIC_BACKEND_URL",
):
    os.environ[name] = ""
# Use the app's built-in CORS defaults (these are not secrets and not in .env).
os.environ.pop("CORS_ORIGINS", None)
os.environ.pop("CORS_ORIGIN_REGEX", None)

# app.main writes uploads to ./uploads relative to the working directory.
os.chdir(TMP_DIR)
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

ADMIN_KEY = os.environ["ADMIN_SETUP_KEY"]
WEB_CLIENT_ID = "659234851207-o80f3633j9f09j79d0ml7376o7v4iv58.apps.googleusercontent.com"


def unique_email(prefix: str = "user") -> str:
    return f"{prefix}-{uuid.uuid4().hex[:10]}@example.com"
