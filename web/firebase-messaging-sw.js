// Firebase Cloud Messaging Service Worker for Web
// Auto-populated with config from firebase_options.dart

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            "AIzaSyCUDKRMGAKJ7vnpzky9Z8vfQQruDlhAB0k",
  authDomain:        "laundrify-d34c0.firebaseapp.com",
  projectId:         "laundrify-d34c0",
  storageBucket:     "laundrify-d34c0.firebasestorage.app",
  messagingSenderId: "875682938754",
  appId:             "1:875682938754:web:287231a25ae5bbfa16d99b",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const { title, body } = payload.notification ?? {};
  if (title) {
    self.registration.showNotification(title, {
      body: body ?? '',
      icon: '/icons/Icon-192.png',
    });
  }
});
