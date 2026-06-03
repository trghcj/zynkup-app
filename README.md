# ZynkUp 🎯

ZynkUp is a smart networking and event management platform built using Flutter (Web/Mobile) and a FastAPI backend. It helps users connect, interact, manage events, and build communities efficiently through a modern, scalable, and real-time system.

## 😄 Features
- **🔐 Secure User Authentication** (JWT-based)
- **🧭 Event Management:** Create, register, and manage campus events with QR passes.
- **🤝 Campus Clubs:** Create clubs, join communities, and manage members with Role-based access (Admin/Member).
- **💬 Real-Time Club Chat:** Instantly chat with club members using WebSockets, featuring dynamic role badges and avatars.
- **🧑‍🤝‍🧑 Friend Connections:** Send, accept, and manage friend requests.
- **🏆 Gamified XP System:** Earn XP by engaging with the platform (e.g., +40 XP for creating clubs, +5 XP for making friends).
- **🖼️ Cloud Media:** Seamless image uploads and hosting powered by Cloudinary.
- **⚡ Fast & Scalable Backend:** Built on Python FastAPI with PostgreSQL (Supabase).
- **🪶 Clean, Responsive Flutter UI:** Beautiful, animated, glassmorphism UI that works on Web, Android, and iOS.

## 🛠️ Tech Stack
- **Frontend:** Flutter (Dart) - *Web & Mobile*
- **Backend:** FastAPI (Python)
- **Database:** PostgreSQL (Hosted on Supabase)
- **Real-Time:** WebSockets (FastAPI)
- **Storage:** Cloudinary API

## 📦 Getting Started

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

## 🔗 API Configuration
Make sure your Flutter app is pointing to your backend. By default, API calls are directed to:
```
http://127.0.0.1:8000
```
⚠️ *For real mobile devices or emulators, replace with your local IP (e.g., `http://192.168.x.x:8000`) or your live production URL.*

## 📂 Project Structure
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

## 🚀 Deployment
- **Frontend:** Hosted and automatically deployed via **Vercel** (`flutter build web`).
- **Backend:** Hosted via **Render** web services.
- **Database:** Hosted via **Supabase** (PostgreSQL).

## 🧠 Future Improvements
- [ ] 🔔 Push notifications
- [ ] 🤖 AI-based networking recommendations
- [ ] 📅 Advanced calendar integrations

## 🤝 Contributing
Contributions are welcome! Feel free to fork this repo, create a feature branch, and submit a pull request.

## ⭐ Support
If you like this project, give it a star ⭐ on GitHub!
