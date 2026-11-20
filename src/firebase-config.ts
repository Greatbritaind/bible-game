// The class-session (multiplayer) server: a free Firebase project ("road-to-jerusalem").
// These values only say which project to use; the database rules (firebase-rules.json) are what
// protect it. Players sign in anonymously: no names, emails or passwords are collected.
export const firebaseConfig = {
  apiKey: "AIzaSyB5bXa7gTKmR1cQSodBpMhG9WxHHicJ6ZY",
  authDomain: "road-to-jerusalem.firebaseapp.com",
  databaseURL: "https://road-to-jerusalem-default-rtdb.firebaseio.com",
  projectId: "road-to-jerusalem",
  storageBucket: "road-to-jerusalem.firebasestorage.app",
  messagingSenderId: "1008887862628",
  appId: "1:1008887862628:web:ffcef53a5c6e18b266d671",
};

/** How long a class session lasts after the teacher starts it (same as the password relock). */
export const SESSION_MS = 3 * 60 * 60 * 1000;
