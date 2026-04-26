# ZynkUp 🎯

ZynkUp is a smart networking and event management platform built using **Flutter** and a **FastAPI backend**.
It helps users connect, interact, and manage events efficiently through a modern and scalable system.

---

## 😄 Features

* 🔐 Secure user authentication (JWT-based)
* 🧭 Event creation and participation
* ⚡ Fast and scalable backend using FastAPI
* 🔄 API-based real-time-like data updates
* 🪶 Clean, responsive Flutter UI
* 📱 Works on Android and iOS

---

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** FastAPI (Python)
* **Database:** SQLite / PostgreSQL
* **API:** REST APIs

---

## 📦 Getting Started

### 1️⃣ Clone the repository

```bash
git clone https://github.com/trghcj/zynkup-app.git
cd zynkup-app
```

---

### 2️⃣ Setup Backend (FastAPI)

```bash
cd zynkup_backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install -r requirements.txt
uvicorn app.main:app --reload
```

Backend will run at:

```
http://127.0.0.1:8000
```

---

### 3️⃣ Run Flutter App

```bash
cd ..
flutter pub get
flutter run
```

---

## 🔗 API Configuration

Make sure your Flutter app is pointing to:

```
http://127.0.0.1:8000
```

> ⚠️ For real devices, replace with your local IP (e.g. `http://192.168.x.x:8000`)

---

## 📂 Project Structure

```
zynkup/
│
├── lib/                # Flutter frontend
├── zynkup_backend/    # FastAPI backend
│   ├── app/
│   └── requirements.txt
│
├── README.md
└── .gitignore
```

---

## 🧠 Future Improvements

* 🔔 Push notifications
* 🤖 AI-based networking recommendations
* 🌐 Deployment (Docker / Cloud)

---

## 🤝 Contributing

Contributions are welcome! Feel free to fork this repo and submit a pull request.

---

## ⭐ Support

If you like this project, give it a star ⭐ on GitHub!
