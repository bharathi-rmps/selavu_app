# Expense Tracker

A simple and intuitive Flutter mobile application for tracking your daily expenses.

## Features

- Add expenses with title, amount, and date
- View list of all expenses
- See total expenses
- Clean and modern UI
- **Firebase integration** - Cloud Firestore for data persistence (optional)

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)

### Installation

1. Clone or download this repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Firebase Setup (Optional)

This app includes Firebase configuration for cloud data persistence. To enable Firebase:

1. Follow the detailed guide in [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
2. Replace placeholder config files with your Firebase project files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. Enable Firestore Database in Firebase Console

**Note**: The app currently uses local state. To use Firebase, integrate `lib/services/firebase_service.dart` into your UI.

## Project Structure

```
lib/
  ├── main.dart              # Entry point and main app
  ├── models/
  │   └── expense.dart      # Expense data model
  ├── services/
  │   └── firebase_service.dart # Firebase service for cloud storage
  └── screens/
      └── home_screen.dart  # Main expense tracking screen
```

## License

This project is open source and available for personal use.

