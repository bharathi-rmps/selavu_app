import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email, password, and display name
  Future<UserCredential> signUpWithEmail(String email, String password, String displayName) async {
    try {
      // Check Firebase initialization
      if (Firebase.apps.isEmpty) {
        debugPrint('ERROR: Firebase apps list is empty');
        throw Exception('Firebase is not initialized. Please check your Firebase configuration.');
      }
      
      debugPrint('Firebase apps count: ${Firebase.apps.length}');
      
      // Debug: Check if we can access Firebase Auth
      try {
        final currentUser = _auth.currentUser;
        debugPrint('Firebase Auth instance accessible. Current user: ${currentUser?.email ?? 'none'}');
        debugPrint('Firebase Auth app name: ${_auth.app.name}');
      } catch (e) {
        debugPrint('Firebase Auth check error: $e');
        throw Exception('Cannot access Firebase Auth. Error: $e');
      }
      
      debugPrint('Attempting to create user with email: ${email.trim()}');
      debugPrint('Network check: Starting signup request...');
      
      // Check if display name is unique before creating user
      final firebaseService = FirebaseService();
      final isUnique = await firebaseService.isDisplayNameUnique(displayName);
      if (!isUnique) {
        throw Exception('Display name "$displayName" is already taken. Please choose a different name.');
      }
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ERROR: Signup timeout after 30 seconds');
          throw Exception('Network timeout. Please check:\n1. Your internet connection\n2. Emulator network access\n3. Try: adb shell ping 8.8.8.8');
        },
      );
      
      debugPrint('SUCCESS: User created successfully: ${userCredential.user?.email}');
      
      // Create user document in Firestore with email, display name, and initial cash balance
      if (userCredential.user != null) {
        try {
          await firebaseService.createUserDocument(
            userCredential.user!.uid,
            userCredential.user!.email ?? email.trim(),
            displayName.trim(),
          );
          debugPrint('SUCCESS: User document created in Firestore');
        } catch (e) {
          debugPrint('WARNING: Failed to create user document: $e');
          // Don't fail signup if Firestore document creation fails
          // User is already created in Auth, document can be created later
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR: FirebaseAuthException: ${e.code} - ${e.message}');
      debugPrint('ERROR: Full exception: $e');
      throw Exception(_handleAuthException(e));
    } on Exception catch (e) {
      debugPrint('ERROR: Exception during signup: $e');
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
        throw Exception('Network timeout. Please check:\n1. Your internet connection\n2. Emulator has internet access\n3. Try: adb shell ping 8.8.8.8');
      }
      if (errorMessage.contains('Network') || errorMessage.contains('network')) {
        throw Exception('Network error. Please check:\n1. Your internet connection\n2. Emulator network settings\n3. Firebase Authentication is enabled in Firebase Console');
      }
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('ERROR: Unexpected error during signup: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout') || errorMessage.contains('Timeout') || errorMessage.contains('Network') || errorMessage.contains('network')) {
        throw Exception('Network error. Please check:\n1. Your internet connection\n2. Emulator has internet access\n3. Firebase Authentication is enabled\n4. Try: adb shell ping 8.8.8.8');
      }
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup') || errorMessage.contains('Unable to resolve host')) {
        throw Exception('Cannot connect to Firebase servers. Please check:\n1. Your internet connection\n2. Emulator network settings\n3. DNS resolution');
      }
      throw Exception('Error signing up: ${errorMessage.replaceFirst('Exception: ', '').replaceFirst('Exception:', '')}');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('ERROR: Firebase apps list is empty');
        throw Exception('Firebase is not initialized. Please check your Firebase configuration.');
      }
      debugPrint('Attempting to sign in with email: ${email.trim()}');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ERROR: Signin timeout after 30 seconds');
          throw Exception('Network timeout. Please check:\n1. Your internet connection\n2. Emulator network access\n3. Try: adb shell ping 8.8.8.8');
        },
      );
      debugPrint('SUCCESS: User signed in successfully: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR: FirebaseAuthException: ${e.code} - ${e.message}');
      throw Exception(_handleAuthException(e));
    } catch (e) {
      debugPrint('ERROR: Signin error: $e');
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout') || errorMessage.contains('Timeout') || errorMessage.contains('Network') || errorMessage.contains('network')) {
        throw Exception('Network error. Please check:\n1. Your internet connection\n2. Emulator network settings\n3. Try: adb shell ping 8.8.8.8');
      }
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup') || errorMessage.contains('Unable to resolve host')) {
        throw Exception('Cannot connect to server. Please check:\n1. Your internet connection\n2. Emulator network settings\n3. DNS resolution');
      }
      throw Exception('Error signing in: ${errorMessage.replaceFirst('Exception: ', '').replaceFirst('Exception:', '')}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.\n\nPlease enable it:\n1. Go to Firebase Console\n2. Authentication > Sign-in method\n3. Enable Email/Password provider';
      case 'network-request-failed':
        return 'Network error. Please check:\n1. Emulator has internet access\n2. Your MacBook internet connection\n3. Firebase Authentication is enabled in Firebase Console\n4. Try: adb shell ping 8.8.8.8\n5. Check if firewall is blocking connections';
      case 'unavailable':
        return 'Firebase service temporarily unavailable. Please try again later.';
      case 'internal-error':
        return 'Firebase internal error. Please check:\n1. Firebase project is active\n2. google-services.json is correct\n3. Try restarting the app';
      default:
        return 'Error: ${e.code}\n${e.message ?? 'Please check Firebase Console settings'}';
    }
  }
}

