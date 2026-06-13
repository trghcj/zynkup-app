# ZynkUp 🎯

## Overview
ZynkUp is a smart networking and event management platform built using Flutter (Web/Mobile) and a FastAPI backend. It helps users connect, interact, manage events, and build communities efficiently through a modern, scalable, and real-time system.

## Architecture

```mermaid
graph TD
    A[Flutter App] -->|REST / WebSockets| B[FastAPI Backend]
    B --> C[Firebase Auth]
    B --> D[PostgreSQL/Firebase DB]
    B --> E[Notification Services]
```

## Features
- **🔐 Secure User Authentication** (JWT-based)
- **🧭 Event Management:** Create, register, and manage campus events with QR passes.
- **🤝 Campus Clubs:** Create clubs, join communities, and manage members with Role-based access (Admin/Member).
- **💬 Real-Time Club Chat:** Instantly chat with club members using WebSockets, featuring dynamic role badges and avatars.
- **🧑‍🤝‍🧑 Friend Connections:** Send, accept, and manage friend requests.
- **🏆 Gamified XP System:** Earn XP by engaging with the platform.
- **🖼️ Cloud Media:** Seamless image uploads and hosting powered by Cloudinary.
- **⚡ Fast & Scalable Backend:** Built on Python FastAPI with PostgreSQL (Supabase).
- **🪶 Clean, Responsive Flutter UI:** Beautiful, animated, glassmorphism UI that works on Web, Android, and iOS.

## Tech Stack
- **Frontend:** Flutter (Dart) - *Web & Mobile*
- **Backend:** FastAPI (Python)
- **Database:** PostgreSQL (Hosted on Supabase)
- **Real-Time:** WebSockets (FastAPI)
- **Storage:** Cloudinary API

## Screenshots

### Discover Page
![Discover](assets/screenshots/discover.jpeg)

### Tickets Page
![Tickets](assets/screenshots/tickets.jpeg)

### Feed Page
![Feed](assets/screenshots/feed.jpeg)

### Notifications Page
![Notifications](assets/screenshots/notification.jpeg)

### Login Screen
![Login Screen](assets/screenshots/login.jpeg)

### Club Page
![Club Page](assets/screenshots/club.jpeg)

## Setup Guide

### 1️⃣ Clone the repository
```bash
git clone https://github.com/trghcj/zynkup-app.git
cd zynkup-app
```

### 2️⃣ Setup Backend (FastAPI)
Ensure you create a `.env` file in the `zynkup_backend` directory containing your `DATABASE_URL`, `JWT_SECRET`, and `CLOUDINARY` keys.

```bash
cd zynkup_backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install -r requirements.txt
uvicorn app.main:app --reload
```
*Backend will run locally at: `http://127.0.0.1:8000`*

### 3️⃣ Run Flutter App
```bash
cd ..
flutter pub get
flutter run -d chrome
```

## Folder Structure
```text
zynkup/
│
├── lib/                 # Flutter frontend source code
├── zynkup_backend/      # FastAPI backend source code
│   ├── app/             # Routers, models, and websocket logic
│   └── requirements.txt 
│
├── README.md
└── .gitignore
```

## Future Scope
- [ ] 🔔 Push notifications
- [ ] 🤖 AI-based networking recommendations
- [ ] 📅 Advanced calendar integrations

## 🤝 Contributing
Contributions are welcome! Feel free to fork this repo, create a feature branch, and submit a pull request.

## ⭐ Support
If you like this project, give it a star ⭐ on GitHub!
