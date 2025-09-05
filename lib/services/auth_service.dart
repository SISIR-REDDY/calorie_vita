import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'demo_auth_service.dart';
import 'local_storage_service.dart';

/// Unified authentication service that handles both Firebase and demo authentication
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DemoAuthService _demoAuth = DemoAuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  
  final StreamController<AuthUser?> _userController = StreamController<AuthUser?>.broadcast();
  
  AuthUser? _currentUser;
  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;

  // Stream for user authentication state
  Stream<AuthUser?> get userStream => _userController.stream;
  AuthUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('Auth service initialization started...');
    
    try {
      // Quick Firebase check with very short timeout
      _isFirebaseAvailable = await _checkFirebaseAvailability().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('Firebase check timed out, using demo auth');
          return false;
        },
      );
      
      if (_isFirebaseAvailable) {
        print('Firebase is available, using Firebase authentication');
        await _initializeFirebaseAuth();
      } else {
        print('Firebase not available, using demo authentication');
        await _demoAuth.initialize();
        await _initializeDemoAuth();
      }
    } catch (e) {
      print('Auth service initialization error: $e, falling back to demo mode');
      // Always fallback to demo auth
      try {
        await _demoAuth.initialize();
        await _initializeDemoAuth();
        _isFirebaseAvailable = false;
      } catch (demoError) {
        print('Demo auth also failed: $demoError');
        _isFirebaseAvailable = false;
      }
    }
    
    // Additional check: if Firebase is marked as available but we get API key errors,
    // force demo mode
    if (_isFirebaseAvailable) {
      try {
        // Test Firebase with a simple operation
        await _firebaseAuth.currentUser;
      } catch (e) {
        if (e.toString().contains('API key not valid') || 
            e.toString().contains('invalid API key') ||
            e.toString().contains('internal error')) {
          print('Firebase API key error detected, switching to demo mode');
          _isFirebaseAvailable = false;
          await _demoAuth.initialize();
          await _initializeDemoAuth();
        }
      }
    }
    
    _isInitialized = true;
    print('Auth service initialization completed. Firebase available: $_isFirebaseAvailable');
  }

  /// Check if Firebase is properly configured and available
  Future<bool> _checkFirebaseAvailability() async {
    try {
      // Try to get current user from Firebase
      final user = _firebaseAuth.currentUser;
      // If we can access Firebase without errors, it's available
      print('Firebase check successful, user: ${user?.email ?? 'null'}');
      return true;
    } catch (e) {
      print('Firebase not available: $e');
      // Check if it's an API key error
      if (e.toString().contains('API key not valid') || 
          e.toString().contains('invalid API key') ||
          e.toString().contains('internal error')) {
        print('Firebase API key invalid, forcing demo mode');
        return false;
      }
      return false;
    }
  }

  /// Initialize Firebase authentication
  Future<void> _initializeFirebaseAuth() async {
    // Check if there's already a current user
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      _currentUser = AuthUser.fromFirebaseUser(currentUser);
      _userController.add(_currentUser);
      print('Firebase current user found: ${currentUser.email}');
    }
    
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUser = AuthUser.fromFirebaseUser(user);
        _userController.add(_currentUser);
        print('Firebase user authenticated: ${user.email}');
      } else {
        _currentUser = null;
        _userController.add(null);
        print('Firebase user signed out');
      }
    });
  }

  /// Initialize demo authentication
  Future<void> _initializeDemoAuth() async {
    // Check if there's already a current demo user
    final currentDemoUser = _demoAuth.currentUser;
    if (currentDemoUser != null) {
      _currentUser = AuthUser.fromDemoUser(currentDemoUser);
      _userController.add(_currentUser);
      print('Demo current user found: ${currentDemoUser.email}');
    }
    
    _demoAuth.userStream.listen((DemoUser? user) {
      if (user != null) {
        _currentUser = AuthUser.fromDemoUser(user);
        _userController.add(_currentUser);
        print('Demo user authenticated: ${user.email}');
      } else {
        _currentUser = null;
        _userController.add(null);
        print('Demo user signed out');
      }
    });
  }

  /// Sign in with email and password
  Future<AuthUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('Attempting sign in with email: $email');
      
      if (_isFirebaseAvailable) {
        print('Using Firebase authentication');
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (credential.user != null) {
          _currentUser = AuthUser.fromFirebaseUser(credential.user!);
          _userController.add(_currentUser);
          print('Firebase sign in successful: ${_currentUser!.email}');
          return _currentUser;
        }
      } else {
        print('Using demo authentication');
        final demoUser = await _demoAuth.signInWithEmailAndPassword(email, password);
        if (demoUser != null) {
          _currentUser = AuthUser.fromDemoUser(demoUser);
          _userController.add(_currentUser);
          print('Demo sign in successful: ${_currentUser!.email}');
          return _currentUser;
        }
      }
      print('Sign in failed: No user returned');
      return null;
    } catch (e) {
      print('Sign in error: $e');
      
      // Check for Firebase API key errors and switch to demo mode
      if (e.toString().contains('API key not valid') || 
          e.toString().contains('invalid API key') ||
          e.toString().contains('internal error')) {
        print('Firebase API key error detected, switching to demo mode');
        _isFirebaseAvailable = false;
        // Retry with demo auth
        try {
          final demoUser = await _demoAuth.signInWithEmailAndPassword(email, password);
          if (demoUser != null) {
            _currentUser = AuthUser.fromDemoUser(demoUser);
            _userController.add(_currentUser);
            print('Demo sign in successful after Firebase error: ${_currentUser!.email}');
            return _currentUser;
          }
        } catch (demoError) {
          print('Demo auth also failed: $demoError');
        }
      }
      
      // Provide more specific error messages
      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this email address. Please create an account first.');
      } else if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address. Please check your email format.');
      } else if (e.toString().contains('too-many-requests')) {
        throw Exception('Too many failed attempts. Please try again later.');
      } else {
        throw Exception('Sign in failed: ${e.toString()}');
      }
    }
  }

  /// Create user with email and password
  Future<AuthUser?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      print('Attempting to create user with email: $email');
      
      if (_isFirebaseAvailable) {
        print('Using Firebase authentication for user creation');
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (credential.user != null) {
          _currentUser = AuthUser.fromFirebaseUser(credential.user!);
          _userController.add(_currentUser);
          print('Firebase user creation successful: ${_currentUser!.email}');
          return _currentUser;
        }
      } else {
        print('Using demo authentication for user creation');
        final demoUser = await _demoAuth.createUserWithEmailAndPassword(email, password);
        if (demoUser != null) {
          _currentUser = AuthUser.fromDemoUser(demoUser);
          _userController.add(_currentUser);
          print('Demo user creation successful: ${_currentUser!.email}');
          return _currentUser;
        }
      }
      print('User creation failed: No user returned');
      return null;
    } catch (e) {
      print('User creation error: $e');
      
      // Check for Firebase API key errors and switch to demo mode
      if (e.toString().contains('API key not valid') || 
          e.toString().contains('invalid API key') ||
          e.toString().contains('internal error')) {
        print('Firebase API key error detected, switching to demo mode');
        _isFirebaseAvailable = false;
        // Retry with demo auth
        try {
          final demoUser = await _demoAuth.createUserWithEmailAndPassword(email, password);
          if (demoUser != null) {
            _currentUser = AuthUser.fromDemoUser(demoUser);
            _userController.add(_currentUser);
            print('Demo user creation successful after Firebase error: ${_currentUser!.email}');
            return _currentUser;
          }
        } catch (demoError) {
          print('Demo auth also failed: $demoError');
        }
      }
      
      // Provide more specific error messages
      if (e.toString().contains('email-already-in-use')) {
        throw Exception('An account with this email already exists. Please sign in instead.');
      } else if (e.toString().contains('weak-password')) {
        throw Exception('Password is too weak. Please choose a stronger password.');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address. Please check your email format.');
      } else {
        throw Exception('Account creation failed: ${e.toString()}');
      }
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      if (_isFirebaseAvailable) {
        await _firebaseAuth.signOut();
      } else {
        await _demoAuth.signOut();
      }
      
      _currentUser = null;
      _userController.add(null);
      print('User signed out');
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (_isFirebaseAvailable) {
        await _firebaseAuth.sendPasswordResetEmail(email: email);
        print('Password reset email sent to: $email');
      } else {
        // In demo mode, just print a message
        print('Demo mode: Password reset email would be sent to: $email');
      }
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<AuthUser?> signInWithGoogle() async {
    try {
      print('Attempting Google sign in');
      
      if (_isFirebaseAvailable) {
        print('Using Firebase for Google sign in');
        // Trigger the authentication flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          print('Google sign in cancelled by user');
          return null;
        }

        print('Google user obtained: ${googleUser.email}');
        
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        
        if (userCredential.user != null) {
          _currentUser = AuthUser.fromFirebaseUser(userCredential.user!);
          _userController.add(_currentUser);
          print('Firebase Google sign in successful: ${_currentUser!.email}');
          return _currentUser;
        }
      } else {
        print('Using demo mode for Google sign in');
        // Demo mode - create a demo Google user
        final demoUser = await _demoAuth.createDemoUser(
          email: 'demo.google@gmail.com',
          displayName: 'Demo Google User',
        );
        if (demoUser != null) {
          _currentUser = AuthUser.fromDemoUser(demoUser);
          _userController.add(_currentUser);
          print('Demo Google sign in successful: ${_currentUser!.email}');
          return _currentUser;
        }
      }
      print('Google sign in failed: No user returned');
      return null;
    } catch (e) {
      print('Google sign in error: $e');
      // Provide more specific error messages
      if (e.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('sign_in_failed')) {
        throw Exception('Google sign in failed. Please try again.');
      } else {
        throw Exception('Google sign in failed: ${e.toString()}');
      }
    }
  }

  /// Sign in with Facebook
  Future<AuthUser?> signInWithFacebook() async {
    try {
      if (_isFirebaseAvailable) {
        // For now, we'll simulate Facebook sign-in
        // In a real app, you would integrate with Facebook SDK
        throw UnsupportedError('Facebook sign-in not implemented yet. Please use Google or Email sign-in.');
      } else {
        // Demo mode - create a demo Facebook user
        final demoUser = await _demoAuth.createDemoUser(
          email: 'demo.facebook@gmail.com',
          displayName: 'Demo Facebook User',
        );
        if (demoUser != null) {
          _currentUser = AuthUser.fromDemoUser(demoUser);
          _userController.add(_currentUser);
          return _currentUser;
        }
      }
      return null;
    } catch (e) {
      print('Facebook sign in error: $e');
      rethrow;
    }
  }

  /// Get authentication method being used
  String get authMethod => _isFirebaseAvailable ? 'Firebase' : 'Demo';
  
  /// Force demo mode for testing (useful when Firebase is not configured)
  void forceDemoMode() {
    _isFirebaseAvailable = false;
    print('Forced demo mode - Firebase disabled');
  }
  
  /// Check if we're in demo mode and show appropriate message
  String get authModeMessage {
    if (_isFirebaseAvailable) {
      return 'Using Firebase Authentication';
    } else {
      return 'Using Demo Mode - Firebase not configured';
    }
  }
  
  /// Get detailed status message for debugging
  String get detailedStatus {
    if (_isFirebaseAvailable) {
      return '✅ Firebase Authentication Active';
    } else {
      return '⚠️ Demo Mode - Firebase needs configuration\n\nTo enable real authentication:\n1. Go to Firebase Console\n2. Add Android app with package: com.sisirlabs.calorievita\n3. Download google-services.json\n4. Update firebase_options.dart';
    }
  }

  /// Dispose resources
  void dispose() {
    _userController.close();
    _demoAuth.dispose();
  }
}

/// Unified user model that works with both Firebase and demo authentication
class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool isEmailVerified;
  final DateTime? lastSignInTime;
  final DateTime? creationTime;
  final bool isDemoUser;

  AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.isEmailVerified = false,
    this.lastSignInTime,
    this.creationTime,
    this.isDemoUser = false,
  });

  /// Create AuthUser from Firebase User
  factory AuthUser.fromFirebaseUser(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
      lastSignInTime: user.metadata.lastSignInTime,
      creationTime: user.metadata.creationTime,
      isDemoUser: false,
    );
  }

  /// Create AuthUser from Demo User
  factory AuthUser.fromDemoUser(DemoUser user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isEmailVerified: true, // Demo users are always "verified"
      isDemoUser: true,
    );
  }

  @override
  String toString() {
    return 'AuthUser(uid: $uid, email: $email, displayName: $displayName, isDemoUser: $isDemoUser)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
