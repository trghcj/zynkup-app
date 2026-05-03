importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCg7ZsRbg0o5HJ7S5LVEwNQaYciEl-hmEY",
  authDomain: "zynkup-app.firebaseapp.com",
  projectId: "zynkup-app",
  storageBucket: "zynkup-app.firebasestorage.app",
  messagingSenderId: "659234851207",
  appId: "1:659234851207:web:39cc56f3416de5bc43eb22"
});

const messaging = firebase.messaging();