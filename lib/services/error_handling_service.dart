import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive error handling and offline support service
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  // Getters
  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Handle Firebase Auth errors
  String handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }

  /// Handle Firestore errors
  String handleFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Please check your account permissions.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timeout. Please check your internet connection.';
      case 'resource-exhausted':
        return 'Service quota exceeded. Please try again later.';
      case 'failed-precondition':
        return 'Operation failed due to a precondition.';
      case 'aborted':
        return 'Operation was aborted. Please try again.';
      case 'out-of-range':
        return 'Value is out of range.';
      case 'unimplemented':
        return 'This operation is not implemented.';
      case 'internal':
        return 'Internal server error. Please try again later.';
      case 'data-loss':
        return 'Data loss occurred. Please contact support.';
      case 'unauthenticated':
        return 'Authentication required. Please sign in again.';
      default:
        return 'A database error occurred: ${e.message}';
    }
  }

  /// Handle network errors
  String handleNetworkError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network settings.';
    } else if (error is TimeoutException) {
      return 'Request timeout. Please check your internet connection.';
    } else if (error is HttpException) {
      return 'Network error: ${error.message}';
    } else {
      return 'Network error occurred. Please try again.';
    }
  }

  /// Handle general errors
  String handleGeneralError(dynamic error) {
    if (error is FirebaseAuthException) {
      return handleAuthError(error);
    } else if (error is FirebaseException) {
      return handleFirestoreError(error);
    } else if (error is SocketException || error is TimeoutException || error is HttpException) {
      return handleNetworkError(error);
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  /// Show error dialog
  void showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar
  void showErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show loading dialog
  void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Check connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _connectivityController.add(isConnected);
      return isConnected;
    } catch (e) {
      _connectivityController.add(false);
      return false;
    }
  }

  /// Retry operation with exponential backoff
  Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int retryCount = 0;
    Duration delay = initialDelay;

    while (retryCount < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          rethrow;
        }
        
        // Exponential backoff
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  /// Handle operation with error handling
  Future<T?> handleOperation<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    bool showLoadingDialog = true,
    bool showSuccessMessage = false,
    bool showErrorDialog = true,
  }) async {
    try {
      if (showLoadingDialog && loadingMessage != null) {
        this.showLoadingDialog(context, loadingMessage);
      }

      final result = await operation();

      if (showLoadingDialog) {
        hideLoadingDialog(context);
      }

      if (showSuccessMessage && successMessage != null) {
        showSuccessSnackBar(context, successMessage);
      }

      return result;
    } catch (e) {
      if (showLoadingDialog) {
        hideLoadingDialog(context);
      }

      final errorMessage = handleGeneralError(e);
      _errorController.add(errorMessage);

      if (showErrorDialog) {
        this.showErrorDialog(context, errorMessage);
      } else {
        showErrorSnackBar(context, errorMessage);
      }

      return null;
    }
  }

  /// Handle operation with retry
  Future<T?> handleOperationWithRetry<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    bool showLoadingDialog = true,
    bool showSuccessMessage = false,
    bool showErrorDialog = true,
    int maxRetries = 3,
  }) async {
    try {
      if (showLoadingDialog && loadingMessage != null) {
        this.showLoadingDialog(context, loadingMessage);
      }

      final result = await retryOperation(operation, maxRetries: maxRetries);

      if (showLoadingDialog) {
        hideLoadingDialog(context);
      }

      if (showSuccessMessage && successMessage != null) {
        showSuccessSnackBar(context, successMessage);
      }

      return result;
    } catch (e) {
      if (showLoadingDialog) {
        hideLoadingDialog(context);
      }

      final errorMessage = handleGeneralError(e);
      _errorController.add(errorMessage);

      if (showErrorDialog) {
        this.showErrorDialog(context, errorMessage);
      } else {
        showErrorSnackBar(context, errorMessage);
      }

      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivityController.close();
    _errorController.close();
  }
}
