# Calico Mobile — Flutter

Cross-platform tutoring app built with Flutter. Connects students with tutors, surfaces smart recommendations, and manages tutoring sessions.

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | >= 3.11 |
| Dart SDK | >= 3.11 |
| Android Studio / VS Code | Latest stable |
| Android device or emulator | API 21+ |
| NestJS backend running | See `/backend` |

---

## Setup

### 1. Install dependencies

```bash
cd calico_mobile_flutter
flutter pub get
```

### 2. Configure Firebase (required for Android)

The app uses Firebase Auth for login and Google Sign-In. Without this step the app will not build or authenticate.

1. Go to the [Firebase Console](https://console.firebase.google.com) and open the project.
2. In **Project settings → Your apps**, select the Android app.
3. Download `google-services.json`.
4. Place the file at:
   ```
   calico_mobile_flutter/android/app/google-services.json
   ```
5. Make sure your debug SHA-1 fingerprint is registered in Firebase. You can get it with:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Then add the SHA-1 in Firebase → Project settings → Your apps → Add fingerprint.

> `google-services.json` is excluded from version control. Each developer must download their own copy from Firebase.

### 3. Set the backend URL

Open `lib/core/network/api_client.dart` and update `_baseUrl` to point to the machine running the NestJS backend:

```dart
// For a physical Android device use your machine's LAN IP, not localhost
static const String _baseUrl = 'http://192.168.x.x:3000';

// For an emulator you can use:
// static const String _baseUrl = 'http://10.0.2.2:3000';
```

### 4. Run the app

```bash
flutter run
```

To target a specific device:

```bash
flutter devices          # list connected devices
flutter run -d <device-id>
```

---

## Using the App

### Register / Login

- Open the app and register with your full name, email, and password, or log in if you already have an account.
- Google Sign-In is also available on the login screen.
- After a successful login you are taken to the Home screen.

### Home Screen

- Displays your enrolled **Courses** and your **Upcoming Sessions**.
- A banner at the top adapts its greeting and message based on the time of day and whether you have sessions scheduled.
- Use the search bar to filter courses by name or code.

### Course Detail

Tap any course to open its detail screen. Below the course information you will find two smart feature sections described below.

### Session Detail

Tap any session card to see full details: date, assigned tutor, course, and current status.

### Profile

Tap the **Profile** tab in the bottom navigation bar to view your student profile. You can edit your personal description from this screen.

---

## Smart Features

These sections appear inside each **Course Detail** screen and are driven by live backend data.

---

### Your Go-To Tutor

**What it shows:** The tutor you have booked the most times for this specific course, provided that tutor has an open availability slot in the next 48 hours.

**How it works:**
1. The app calls `GET /analytics/returning-tutor?student=<uid>&course=<courseId>`.
2. The backend aggregates your completed tutoring sessions for that course, ranks tutors by booking count, and returns the top-ranked one with an upcoming slot.
3. The card shows the tutor's name, rating, location, next available time slot, countdown, and total number of past bookings with them.

**When it is hidden:** If you have no session history for the course, or your most-booked tutor has no upcoming availability, this section does not appear.

> **For teammates:** Add any additional details about this feature here — edge cases, backend logic notes, or UI decisions.

---

### Top Rated & Available Soon

**What it shows:** A horizontal carousel of tutors who have a rating above 4.5 and at least one open availability slot in the next 4 hours for this course.

**How it works:**
1. The app calls `GET /analytics/available-tutors?course=<courseId>`.
2. The backend filters tutors by rating threshold and upcoming availability window.
3. Each card shows tutor name, rating, location, the next time slot, and a live countdown.

**When it is hidden:** If no tutor meets both criteria the section is not rendered. A loading spinner is shown while the request is in progress.

> **For teammates:** Add any additional details about this feature here — filtering criteria, sorting logic, or UI decisions.

---

## Dependencies

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase SDK initialization |
| `firebase_auth` | Authentication token management |
| `google_sign_in` | Google OAuth2 sign-in flow |
| `http` | HTTP client for backend requests |
| `google_fonts` | Lexend typeface |
| `url_launcher` | Opens external links (tutor application form) |

---

## Project Structure

```
lib/
├── core/               # Shared across all features
│   ├── network/        # ApiClient — single HTTP façade
│   ├── constants/      # Colors, text styles
│   ├── validators/     # Client-side form validation
│   └── widgets/        # Reusable UI components
└── features/
    ├── auth/           # Login, register, Google Sign-In
    ├── home/           # Courses, sessions, smart features
    └── profile/        # Student profile view and edit
```
