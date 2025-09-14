import 'dart:async';
import 'local_storage_service.dart';

/// Demo authentication service for development
/// Provides mock authentication when Firebase is not configured
class DemoAuthService {
  static final DemoAuthService _instance = DemoAuthService._internal();
  factory DemoAuthService() => _instance;
  DemoAuthService._internal();

  final LocalStorageService _localStorage = LocalStorageService();
  final StreamController<DemoUser?> _userController = StreamController<DemoUser?>.broadcast();
  
  DemoUser? _currentUser;
  bool _isInitialized = false;

  // Stream for user authentication state
  Stream<DemoUser?> get userStream => _userController.stream;
  DemoUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;

  /// Initialize the demo auth service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if user is already logged in locally
      final isLoggedIn = await _localStorage.isLoggedIn();
      if (isLoggedIn) {
        final credentials = await _localStorage.getUserCredentials();
        if (credentials != null) {
          _currentUser = DemoUser(
            uid: 'demo_${credentials['email']!.hashCode}',
            email: credentials['email']!,
            displayName: credentials['email']!.split('@')[0],
          );
          _userController.add(_currentUser);
          print('Demo user restored from local storage: ${_currentUser!.email}');
          print('Demo user UID: ${_currentUser!.uid}');
        }
      } else {
        print('No demo user found in local storage');
      }
    } catch (e) {
      print('Demo auth initialization error: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Sign in with email and password (demo mode)
  Future<DemoUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('Demo auth: Attempting sign in with email: $email');
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // For demo purposes, accept any email/password combination
      // In a real app, you would validate against a server
      if (email.isNotEmpty && password.isNotEmpty) {
        // Basic email validation
        if (!email.contains('@') || !email.contains('.')) {
          throw Exception('Please enter a valid email address');
        }
        
        // Basic password validation
        if (password.length < 6) {
          throw Exception('Password must be at least 6 characters long');
        }
        
        final user = DemoUser(
          uid: 'demo_${email.hashCode}',
          email: email,
          displayName: email.split('@')[0],
        );
        
        _currentUser = user;
        _userController.add(user);
        
        // Save credentials locally
        await _localStorage.saveUserCredentials(email, password);
        
        print('Demo user signed in successfully: $email');
        return user;
      } else {
        throw Exception('Email and password are required');
      }
    } catch (e) {
      print('Demo sign in error: $e');
      rethrow;
    }
  }

  /// Create user with email and password (demo mode)
  Future<DemoUser?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      print('Demo auth: Attempting to create user with email: $email');
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // For demo purposes, accept any email/password combination
      if (email.isNotEmpty && password.isNotEmpty) {
        // Basic email validation
        if (!email.contains('@') || !email.contains('.')) {
          throw Exception('Please enter a valid email address');
        }
        
        // Basic password validation
        if (password.length < 6) {
          throw Exception('Password must be at least 6 characters long');
        }
        
        final user = DemoUser(
          uid: 'demo_${email.hashCode}',
          email: email,
          displayName: email.split('@')[0],
        );
        
        _currentUser = user;
        _userController.add(user);
        
        // Save credentials locally
        await _localStorage.saveUserCredentials(email, password);
        
        print('Demo user created successfully: $email');
        return user;
      } else {
        throw Exception('Email and password are required');
      }
    } catch (e) {
      print('Demo user creation error: $e');
      rethrow;
    }
  }

  /// Create a demo user for social sign-in
  Future<DemoUser?> createDemoUser({
    required String email,
    required String displayName,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = DemoUser(
        uid: 'demo_${email.hashCode}',
        email: email,
        displayName: displayName,
      );
      
      _currentUser = user;
      _userController.add(user);
      
      // Save credentials locally
      await _localStorage.saveUserCredentials(email, 'demo_password');
      
      print('Demo user created: $email');
      return user;
    } catch (e) {
      print('Demo user creation error: $e');
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    _currentUser = null;
    _userController.add(null);
    await _localStorage.logout();
    print('Demo user signed out');
  }

  /// Dispose resources
  void dispose() {
    _userController.close();
  }
}

/// Demo user model
class DemoUser {
  final String uid;
  final String email;
  final String? displayName;

  DemoUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  @override
  String toString() {
    return 'DemoUser(uid: $uid, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DemoUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
