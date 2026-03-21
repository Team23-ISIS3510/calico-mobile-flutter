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
=======
# 🐱 Calico – Flutter Mobile App

Calico is a centralized peer-tutoring marketplace for university students. This repository contains the Flutter mobile client, which connects to the shared NestJS backend.

---

## 👥 Team

| Name | Email |
|------|-------|
| Paola Catherine Jimenez Jaque | p.jimenezj@uniandes.edu.co |
| Maria Lucia Benavides Domínguez | m.benavidesd@uniandes.edu.co |

---

| Requirement | Description | Owner |
|---|---|---|
| **a. Sensor** | 1 functionality that uses at least one sensor in the phone | NA |
| **b. Type 2 BQ** | 1 functionality that answers type 2 questions | María Lucia Benavides Domínguez & Paola Catherine Jimenez Jaque |
| **c. Context-Aware** | 1 functionality that is context aware | Paola Catherine Jimenez Jaque |
| **d. Smart Feature** | 1 functionality that is considered smart features | María Lucia Benavides Domínguez |
| **e. Authentication** | 1 functionality that allows users authentication | María Lucia Benavides Domínguez & Paola Catherine Jimenez Jaque |
| **f. External Services** | 1 functionality that uses external services (different from authentication, connected to backend) | María Lucia Benavides Domínguez & Paola Catherine Jimenez Jaque |

## 📋 Prerequisites

Before running the app, make sure you have the following installed:

| Tool | Version | Link |
|------|---------|------|
| Flutter SDK | ≥ 3.11.1 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ≥ 3.11.1 | Included with Flutter |
| Xcode (iOS) | Latest | Mac App Store |
| Chrome (Web) | Latest | For web debugging |

---

## ⚙️ Setup

### 1. Clone the repository
```bash
git clone https://github.com/Team23-ISIS3510/calico-mobile-flutter.git
cd calico-mobile-flutter/calico_mobile_flutter
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Firebase configuration

The app requires Firebase to be configured. Place the following files in their respective directories:

| File | Location | Platform |
|------|----------|----------|
| `GoogleService-Info.plist` | `ios/Runner/` | iOS |
| `google-services.json` | `android/app/` | Android |

> ⚠️ These files are not committed to the repository. Ask a team member for access.

### 4. Backend

Make sure the backend is running locally before launching the app:
```bash
# In the backend repository
npm run start:dev
```

The app connects to `http://localhost:3000` by default. You can change this in:
```
lib/core/network/api_client.dart
```

---

## 🚀 Running the App

### Web (recommended for development)
```bash
flutter run -d chrome
```

### macOS
```bash
flutter run -d macos
```

### iOS Simulator (requires Xcode)
```bash
flutter run -d ios
```

### List available devices
```bash
flutter devices
```

---

## 🔑 Google Sign-In Configuration

Google Sign-In requires additional setup depending on the platform.

### Web
The web client ID must be set in `login_controller.dart`:
```dart
final googleUser = await GoogleSignIn(
  clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
).signIn();
```

You can find the Web Client ID in:
**Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration**

### Enable People API (required for web)
Google Sign-In on web requires the **People API** to be enabled. Without it, the sign-in flow will fail with a `403` error.

1. Go to [Google Cloud Console](https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=YOUR_PROJECT_ID)
2. Select your Firebase project
3. Click **Enable**
4. Wait a few minutes for the change to propagate

> ⚠️ This is only required for web. iOS and Android do not need the People API.

### Authorized Domains (web)
Make sure `localhost` is listed as an authorized domain in Firebase:

**Firebase Console → Authentication → Settings → Authorized domains**

---

## 🏗️ Project Structure
```
lib/
├── core/
│   ├── network/api_client.dart              ← single HTTP façade (GET/POST/PATCH)
│   ├── errors/app_exception.dart            ← unified error type
│   ├── validators/form_validators.dart      ← client-side validation rules
│   └── widgets/                             ← shared reusable widgets
│
└── features/
    ├── auth/
    │   ├── domain/
    │   │   ├── models/
    │   │   │   ├── login_request.dart
    │   │   │   └── register_request.dart
    │   │   └── repositories/
    │   │       └── auth_repository.dart          ← abstract contract
    │   ├── data/repositories/
    │   │   └── auth_repository_impl.dart          ← HTTP impl
    │   └── presentation/
    │       ├── controllers/
    │       │   ├── login_controller.dart          ← ChangeNotifier
    │       │   └── register_controller.dart       ← ChangeNotifier
    │       └── screens/
    │           ├── login_screen.dart              ← StatefulWidget
    │           └── register_screen.dart           ← StatefulWidget
    │
    ├── home/
    │   ├── domain/repositories/
    │   │   ├── course_repository.dart
    │   │   ├── session_repository.dart
    │   │   └── analytics_repository.dart
    │   ├── data/
    │   │   ├── models/
    │   │   │   ├── course_model.dart
    │   │   │   ├── session_model.dart
    │   │   │   └── available_tutor_model.dart
    │   │   └── repositories/
    │   │       ├── course_repository_impl.dart
    │   │       ├── session_repository_impl.dart
    │   │       └── analytics_repository_impl.dart
    │   └── presentation/
    │       ├── controllers/home_controller.dart
    │       ├── screens/
    │       │   ├── home_screen.dart
    │       │   ├── course_detail_screen.dart
    │       │   └── session_detail_screen.dart
    │       └── widgets/
    │           ├── booking_bottom_sheet.dart
    │           ├── course_card.dart
    │           ├── session_card.dart
    │           └── tutor_carousel_card.dart
    │
    └── profile/
        ├── domain/
        │   ├── models/user_profile.dart
        │   └── repositories/profile_repository.dart
        ├── data/repositories/
        │   └── profile_repository_impl.dart
        └── presentation/
            ├── controllers/profile_controller.dart
            └── screens/profile_screen.dart
```

---

## 🔧 Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.6.0 | Firebase initialization |
| `firebase_auth` | ^5.3.1 | Authentication |
| `google_sign_in` | ^6.2.1 | Google OAuth flow |
| `google_fonts` | ^6.2.1 | Lexend font family |
| `http` | ^1.2.2 | HTTP requests |
| `url_launcher` | ^6.3.0 | Open external links |

---

## 🐛 Troubleshooting

### `flutter` command not found
Add Flutter to your PATH. In `~/.zshrc`:
```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
```
Then run `source ~/.zshrc`.

### VS Code terminal doesn't find `flutter`
```bash
source ~/.zprofile
```
Or add Flutter to `~/.zshrc` as shown above.

### `Failed to fetch` on web
Make sure the backend is running with:
```bash
npm run start:dev  # NOT npm run start
```
`npm run start` uses the compiled `dist/` and may lack CORS headers.

### Google Sign-In fails with `403` on web
Enable the **People API** in Google Cloud Console — see the [Google Sign-In Configuration](#-google-sign-in-configuration) section above.

### `GoogleService-Info.plist` missing
Ask a team member for the Firebase configuration files. They are excluded from version control for security reasons.

---

## 🔗 Related Repositories

| Repository | Link |
|-----------|------|
| 🤖 Kotlin App | [calico-mobile-kotlin](https://github.com/Team23-ISIS3510/calico-mobile-kotlin) |
| ⚙️ Backend | [backend](https://github.com/Team23-ISIS3510/backend) |
