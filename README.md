# ZynkUp

<p align="center">
  <a href="release/Zynkup.apk"><img src="https://img.shields.io/badge/Download-Universal%20APK-4CAF50?style=for-the-badge" alt="Download APK"></a>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-4CAF50?style=for-the-badge" alt="Platform: Android and Web">
  <img src="https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge" alt="Built with Flutter">
  <img src="https://img.shields.io/badge/API-FastAPI-009688?style=for-the-badge" alt="API: FastAPI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License: MIT"></a>
</p>

ZynkUp is a campus event and community platform for college students. Students discover and register for events, join and follow clubs, chat with club members, and share updates on a campus feed. Organizers create events, manage co-hosts, and check attendees in with QR passes.

**Web app:** [zynkup-app.vercel.app](https://zynkup-app.vercel.app)

## Download (Android)

| Architecture | Devices | Download |
| :--- | :--- | :--- |
| ARM64-v8a (recommended) | Most modern Android phones and tablets | [zynkup-arm64-v8a-release.apk](release/zynkup-arm64-v8a-release.apk) |
| ARMEABI-v7a | Older 32-bit Android devices | [zynkup-armeabi-v7a-release.apk](release/zynkup-armeabi-v7a-release.apk) |
| x86_64 | Android emulators and Chromebooks | [zynkup-x86_64-release.apk](release/zynkup-x86_64-release.apk) |
| Universal | Any Android device (larger download) | [Zynkup.apk](release/Zynkup.apk) |

If you are unsure which to choose, use the universal APK. Android may ask you to allow installation from unknown sources before installing.

## Features

**Events**
- Browse, search and register for campus events, including inter-college competitions
- QR-code tickets with organizer-side scanning for attendance
- Co-host management with verified-email access for organizers from other colleges
- Event galleries for photos and documents after the event

**Clubs and communities**
- Create, join or follow clubs, with a "My Clubs" hub (Created, Joined, Following) and category filters
- Members-only real-time club chat with attachments, message editing and deletion
- Custom member titles (for example "Tech Lead") on top of owner, admin and member permission levels
- Push and in-app notifications to followers when a club posts an event or update

**Campus feed**
- Posts with photos, polls, reactions and comments
- Link previews for YouTube, Instagram and general web links
- Bookmarks for events and posts

**Profiles and engagement**
- Profile with banner, avatar, college and activity timeline
- XP, levels and daily streaks earned through participation
- Friend requests, with contact details visible only to friends

## Architecture

```mermaid
graph TD
    A[Flutter app<br/>Android and Web] -->|REST + WebSocket, JWT| B[FastAPI backend<br/>Render]
    A -->|Google Sign-In| G[Google OAuth]
    B -->|Verify Google ID token| G
    B --> C[(PostgreSQL)]
    B -->|Image and file uploads| D[Cloudinary]
    B -->|Push notifications| E[Firebase Cloud Messaging]
    E --> A
    F[Firebase Cloud Functions] -->|Event approval alerts| E
```

- The app signs users in with email and password or Google. The backend verifies credentials and issues its own JWT, which the app keeps in secure storage.
- Club chat runs over WebSockets. Everything else is REST.
- Media is stored in Cloudinary when it is configured, otherwise on the server's local disk.

## Tech stack

| Layer | Technology |
| :--- | :--- |
| Mobile and web app | Flutter (Dart) |
| Backend API | FastAPI (Python), SQLAlchemy, PyJWT |
| Database | PostgreSQL (SQLite for local development and tests) |
| Media storage | Cloudinary |
| Notifications | Firebase Cloud Messaging, Firebase Cloud Functions |
| Hosting | Render (API), Vercel and Firebase Hosting (web) |
| CI | GitHub Actions: Flutter analyze and test, backend tests on SQLite and Postgres, CodeQL |

## Screenshots

<p align="center">
  <img src="assets/screenshots/discover.jpeg" width="200" alt="Discover">
  <img src="assets/screenshots/tickets.jpeg" width="200" alt="Tickets">
  <img src="assets/screenshots/feed.jpeg" width="200" alt="Feed">
  <img src="assets/screenshots/notification.jpeg" width="200" alt="Notifications">
  <img src="assets/screenshots/login.jpeg" width="200" alt="Login">
  <img src="assets/screenshots/profile.jpeg" width="200" alt="Profile">
</p>

## Getting started

### Prerequisites

- Flutter SDK (Dart 3.8 or later)
- Python 3.11
- PostgreSQL, or Docker to run it with `docker-compose`

### 1. Clone the repository

```bash
git clone https://github.com/trghcj/zynkup-app.git
cd zynkup-app
```

### 2. Run the backend

Create `zynkup_backend/.env` (see [.env.example](.env.example)):

| Variable | Required | Purpose |
| :--- | :--- | :--- |
| `DATABASE_URL` | Yes | PostgreSQL connection string, for example `postgresql://user:pass@localhost:5432/zynkup` |
| `JWT_SECRET` | Yes | Secret used to sign login tokens. Use a random value of at least 32 characters |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | Token lifetime (default 1440) |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | No | Media storage. Without them, uploads are saved locally |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | No | Path to a Firebase service account JSON file, needed for push notifications |
| `GOOGLE_CLIENT_ID` | No | Comma-separated Google OAuth client IDs to accept (defaults to the app's own) |
| `CORS_ORIGINS`, `CORS_ORIGIN_REGEX` | No | Allowed web origins (default: the ZynkUp Vercel deployments and localhost) |
| `PUBLIC_BACKEND_URL` | No | Public base URL used for links to locally stored uploads |
| `ADMIN_SETUP_KEY` | No | Enables admin maintenance endpoints, sent in the `X-Admin-Setup-Key` header |

Then start the API:

```bash
cd zynkup_backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The API runs at `http://127.0.0.1:8000`, with interactive documentation at `/docs`.

Alternatively, run PostgreSQL and the backend together with Docker. This reads its settings from `.env.docker`:

```bash
docker-compose up --build
```

### 3. Run the Flutter app

Add `android/app/google-services.json` from the Firebase Console. It enables push notifications and Google Sign-In on Android.

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Without `API_BASE_URL`, the app connects to the production API. On the Android emulator, use `http://10.0.2.2:8000` to reach a backend running on your computer.

### 4. Build Android APKs

```bash
flutter build apk --release --split-per-abi   # one smaller APK per CPU architecture
flutter build apk --release                   # one universal APK
```

Output is written to `build/app/outputs/flutter-apk/`.

## Testing

```bash
# Flutter
flutter analyze
flutter test

# Backend: unit and integration tests (uses a temporary SQLite database)
cd zynkup_backend
python -m unittest discover -s tests -t . -v
```

To run the backend tests against PostgreSQL instead, set `TEST_DATABASE_URL` to a PostgreSQL connection string. CI runs the backend tests on both databases for every backend change.

## Project structure

```text
zynkup-app/
├── lib/                    Flutter app
│   ├── core/               API client, theme, shared widgets, utilities
│   ├── features/           Feature modules: auth, events, clubs, feed, profile, notifications, analytics
│   └── main.dart           Entry point
├── test/                   Flutter tests
├── zynkup_backend/         FastAPI backend
│   ├── app/                Routes, models, auth and helpers
│   └── tests/              Backend unit and integration tests
├── functions/              Firebase Cloud Functions
├── release/                Prebuilt Android APKs
├── android/, ios/, web/    Platform projects
└── .github/workflows/      CI and deployment pipelines
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md), then open a pull request against `main`. Make sure `flutter analyze`, `flutter test` and the backend tests pass before submitting.

## Security

Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md), not in public issues.

## License

ZynkUp is released under the [MIT License](LICENSE).
