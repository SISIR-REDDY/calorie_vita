import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'health_connect_manager.dart';
import 'logger_service.dart';

/// Firebase authentication service
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid', // Required for Firebase authentication
      // Google Fit scopes removed - using Health Connect instead
      // Health Connect doesn't require OAuth scopes, avoiding "unverified app" warning
    ],
    // Let Google Sign-In use the default configuration from google-services.json
  );
  static final LoggerService _logger = LoggerService();

  final StreamController<AuthUser?> _userController =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;
  String? _verificationId; // For phone authentication
  Timer? _tokenValidationTimer; // Periodic token validation

  // Stream for user authentication state
  Stream<AuthUser?> get userStream => _userController.stream;
  AuthUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('Auth service initialization started...');
    print('🔧 Google Sign-In configuration check...');
    print('🔧 Package name: com.sisirlabs.calorievita');
    print('🔧 SHA-1 fingerprint: fc8f2fd7b4c4072afe837b115676feaf70fc7cfd');

    try {
      // Quick Firebase check with very short timeout
      _isFirebaseAvailable = await _checkFirebaseAvailability().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('Firebase check timed out');
          return false;
        },
      );

      if (_isFirebaseAvailable) {
        print('Firebase is available, using Firebase authentication');
        await _initializeFirebaseAuth();
      } else {
        print('Firebase not available');
      }
    } catch (e) {
      print('Auth service initialization error: $e');
      _isFirebaseAvailable = false;
    }

    _isInitialized = true;
    print(
        'Auth service initialization completed. Firebase available: $_isFirebaseAvailable');
  }

  /// Check if Firebase is properly configured and available
  Future<bool> _checkFirebaseAvailability() async {
    try {
      // Try to get current user from Firebase
      _firebaseAuth.currentUser;
      return true;
    } catch (e) {
      print('Firebase availability check failed: $e');
      return false;
    }
  }

  /// Initialize Firebase authentication
  Future<void> _initializeFirebaseAuth() async {
    // Check if there's already a current user
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      // Validate the user's token to ensure they still exist
      final isValid = await _validateUserToken(currentUser);
      if (isValid) {
        _currentUser = AuthUser.fromFirebaseUser(currentUser);
        _userController.add(_currentUser);
        print('Firebase current user found: ${currentUser.email}');
      } else {
        // User was deleted or token is invalid, sign out
        print('User token validation failed, signing out');
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
        _currentUser = null;
        _userController.add(null);
      }
    }

    // Listen to Firebase auth state changes
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

    // Listen to ID token changes (fires more frequently and catches token revocations)
    _firebaseAuth.idTokenChanges().listen((User? user) async {
      if (user != null) {
        // Validate token when it changes
        final isValid = await _validateUserToken(user);
        if (!isValid) {
          print('User token invalidated, signing out');
          await _firebaseAuth.signOut();
          await _googleSignIn.signOut();
          _currentUser = null;
          _userController.add(null);
          _stopTokenValidationTimer();
        } else {
          _currentUser = AuthUser.fromFirebaseUser(user);
          _userController.add(_currentUser);
          _startTokenValidationTimer();
        }
      } else {
        _currentUser = null;
        _userController.add(null);
        _stopTokenValidationTimer();
      }
    });

    // Start periodic token validation if user is already logged in
    if (_currentUser != null) {
      _startTokenValidationTimer();
    }
  }

  /// Start periodic token validation (every 5 minutes)
  void _startTokenValidationTimer() {
    _stopTokenValidationTimer(); // Stop existing timer if any
    
    _tokenValidationTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        final isValid = await _validateUserToken(currentUser);
        if (!isValid) {
          print('Periodic token validation failed, signing out');
          await _firebaseAuth.signOut();
          await _googleSignIn.signOut();
          _currentUser = null;
          _userController.add(null);
          _stopTokenValidationTimer();
        }
      } else {
        _stopTokenValidationTimer();
      }
    });
  }

  /// Stop periodic token validation
  void _stopTokenValidationTimer() {
    _tokenValidationTimer?.cancel();
    _tokenValidationTimer = null;
  }

  /// Validate user token by attempting to refresh it
  /// Returns false if user was deleted or token is invalid
  Future<bool> _validateUserToken(User user) async {
    try {
      // Try to get a fresh ID token - this will fail if user was deleted
      await user.getIdToken(true); // Force refresh
      return true;
    } catch (e) {
      print('Token validation failed: $e');
      // Check for specific error codes that indicate user was deleted
      if (e.toString().contains('user-not-found') ||
          e.toString().contains('user-disabled') ||
          e.toString().contains('invalid-credential') ||
          e.toString().contains('invalid-user-token')) {
        return false;
      }
      // For other errors, assume token is still valid (might be network issue)
      return true;
    }
  }

  /// Sign in with email and password
  Future<AuthUser?> signInWithEmailAndPassword(
      String email, String password) async {
    if (!_isFirebaseAvailable) {
      print('Firebase not available for sign in');
      return null;
    }

    try {
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
    } catch (e) {
      print('Firebase sign in error: $e');
      rethrow;
    }

    return null;
  }

  /// Create user with email and password
  Future<AuthUser?> createUserWithEmailAndPassword(
      String email, String password) async {
    if (!_isFirebaseAvailable) {
      print('Firebase not available for user creation');
      return null;
    }

    try {
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
    } catch (e) {
      print('Firebase user creation error: $e');
      rethrow;
    }

    return null;
  }

  /// Sign out with complete cleanup including Google Fit
  Future<void> signOut() async {
    try {
      _logger.info('Starting complete sign out process');
      
      // Stop token validation timer
      _stopTokenValidationTimer();
      
      // Disconnect Health Connect (with timeout to prevent hanging)
      _logger.info('Disconnecting Health Connect services');
      final healthConnectManager = HealthConnectManager();
      await healthConnectManager.signOut().timeout(const Duration(seconds: 10));
      
      // Sign out from Firebase
      _logger.info('Signing out from Firebase');
      await _firebaseAuth.signOut();
      
      // Sign out from Google Sign-In
      _logger.info('Signing out from Google Sign-In');
      await _googleSignIn.signOut();
      
      // Clear user data
      _currentUser = null;
      _userController.add(null);
      
      // Add a small delay to ensure all services are properly cleaned up
      await Future.delayed(const Duration(milliseconds: 200));
      
      _logger.info('Complete sign out successful');
    } catch (e) {
      _logger.error('Sign out error', {'error': e.toString()});
      
      // Force clear user data even if sign out fails
      _currentUser = null;
      _userController.add(null);
      _stopTokenValidationTimer();
      
      // Don't rethrow to prevent UI blocking
      _logger.warning('Sign out completed with errors, but user data cleared');
    }
  }

  /// Sign out from Google Sign-In only (keeps Firebase auth if exists)
  Future<void> signOutFromGoogleSignInOnly() async {
    try {
      _logger.info('Signing out from Google Sign-In only');
      await _googleSignIn.signOut();
      _logger.info('Google Sign-In sign out successful');
    } catch (e) {
      _logger.error('Google Sign-In sign out error', {'error': e.toString()});
    }
  }

  /// Sign in with Google
  Future<AuthUser?> signInWithGoogle() async {
    if (!_isFirebaseAvailable) {
      print('Firebase not available for Google sign in');
      return null;
    }

    try {
      // Sign out from Google Sign-In first to force account picker
      // This ensures user always sees account selection
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google sign in cancelled');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _currentUser = AuthUser.fromFirebaseUser(userCredential.user!);
        _userController.add(_currentUser);
        print('Google sign in successful: ${_currentUser!.email}');
        return _currentUser;
      }
    } catch (e) {
      print('Google sign in error: $e');
      rethrow;
    }

    return null;
  }

  /// Send phone verification code
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    if (!_isFirebaseAvailable) {
      print('Firebase not available for phone verification');
      return;
    }

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential =
              await _firebaseAuth.signInWithCredential(credential);
          if (userCredential.user != null) {
            _currentUser = AuthUser.fromFirebaseUser(userCredential.user!);
            _userController.add(_currentUser);
            print('Phone verification completed: ${_currentUser!.email}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Phone verification failed: $e');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          print('Phone verification code sent');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print('Phone verification error: $e');
      rethrow;
    }
  }

  /// Verify phone OTP
  Future<AuthUser?> verifyPhoneOTP(String otp) async {
    if (!_isFirebaseAvailable || _verificationId == null) {
      print('Firebase not available or verification ID missing');
      return null;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _currentUser = AuthUser.fromFirebaseUser(userCredential.user!);
        _userController.add(_currentUser);
        print('Phone OTP verification successful: ${_currentUser!.email}');
        return _currentUser;
      }
    } catch (e) {
      print('Phone OTP verification error: $e');
      rethrow;
    }

    return null;
  }

  /// Sign in with Facebook (placeholder - requires Facebook SDK)
  Future<AuthUser?> signInWithFacebook() async {
    print('Facebook sign in not implemented - requires Facebook SDK');
    return null;
  }

  /// Dispose resources
  void dispose() {
    _userController.close();
  }
}

/// User authentication data model
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isEmailVerified;
  final DateTime? lastSignInTime;
  final DateTime? creationTime;

  AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isEmailVerified = false,
    this.lastSignInTime,
    this.creationTime,
  });

  /// Create AuthUser from Firebase User
  factory AuthUser.fromFirebaseUser(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
      lastSignInTime: user.metadata.lastSignInTime,
      creationTime: user.metadata.creationTime,
    );
  }

  @override
  String toString() {
    return 'AuthUser(uid: $uid, email: $email, displayName: $displayName)';
  }
}