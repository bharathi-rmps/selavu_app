# Firebase Setup Guide

This guide will help you set up Firebase for the Expense Tracker app.

## Prerequisites

1. A Google account
2. Flutter CLI installed
3. Firebase CLI installed (optional, but recommended)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard:
   - Enter project name (e.g., "Expense Tracker")
   - Enable/disable Google Analytics (optional)
   - Click "Create project"

## Step 2: Add Android App

1. In Firebase Console, click the Android icon (or "Add app" → Android)
2. Register your app:
   - **Android package name**: `com.example.expense_tracker`
   - **App nickname**: Expense Tracker (optional)
   - **Debug signing certificate SHA-1**: (optional for now)
3. Click "Register app"
4. Download `google-services.json`
5. Place the downloaded file at: `android/app/google-services.json`
   - Replace the placeholder file that's currently there

## Step 3: Add iOS App

1. In Firebase Console, click the iOS icon (or "Add app" → iOS)
2. Register your app:
   - **iOS bundle ID**: Check your `ios/Runner.xcodeproj` or use `com.example.expenseTracker`
   - **App nickname**: Expense Tracker (optional)
3. Click "Register app"
4. Download `GoogleService-Info.plist`
5. Place the downloaded file at: `ios/Runner/GoogleService-Info.plist`
   - Replace the placeholder file that's currently there

## Step 4: Enable Firestore Database

1. In Firebase Console, go to "Build" → "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location for your database
5. Click "Enable"

**Important**: For production, set up proper Firestore security rules!

## Step 5: Install FlutterFire CLI (Recommended)

```bash
dart pub global activate flutterfire_cli
```

## Step 6: Configure FlutterFire (Alternative Method)

If you prefer using FlutterFire CLI instead of manual setup:

```bash
flutterfire configure
```

This will:
- Automatically detect your Firebase projects
- Generate `lib/firebase_options.dart`
- Configure both Android and iOS

**Note**: If you use FlutterFire CLI, you may need to update `main.dart` to use the generated options:

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ExpenseTrackerApp());
}
```

## Step 7: Install Dependencies

```bash
flutter pub get
```

## Step 8: Verify Setup

1. Run the app:
   ```bash
   flutter run
   ```

2. Try adding an expense - it should sync to Firestore

3. Check Firebase Console → Firestore Database to see your data

## Troubleshooting

### Android Issues

- **Error: "google-services.json not found"**
  - Make sure `google-services.json` is in `android/app/` directory
  - Verify the package name matches in `google-services.json` and `build.gradle`

- **Build errors**
  - Run `flutter clean` and `flutter pub get`
  - Make sure Google Services plugin is added in `android/build.gradle`

### iOS Issues

- **Error: "GoogleService-Info.plist not found"**
  - Make sure `GoogleService-Info.plist` is in `ios/Runner/` directory
  - Verify it's added to Xcode project (should be automatic)

- **Build errors**
  - Run `flutter clean` and `flutter pub get`
  - Open `ios/Runner.xcworkspace` in Xcode and check for errors
  - Run `pod install` in `ios/` directory if needed

### General Issues

- **Firebase not initializing**
  - Check that config files are correct
  - Verify internet connection
  - Check Firebase Console for project status

## Security Rules (Important!)

For production, update your Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /expenses/{expenseId} {
      allow read, write: if request.auth != null; // Requires authentication
      // Or for public access (NOT recommended for production):
      // allow read, write: if true;
    }
  }
}
```

## Next Steps

- Consider adding Firebase Authentication for user-specific expenses
- Set up proper Firestore security rules
- Add error handling and offline support
- Implement data synchronization indicators

