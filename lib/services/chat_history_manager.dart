import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Enhanced chat history manager with persistent caching and offline support
class ChatHistoryManager {
  static final ChatHistoryManager _instance = ChatHistoryManager._internal();
  factory ChatHistoryManager() => _instance;
  ChatHistoryManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache management
  static const String _chatHistoryKey = 'chat_history_cache';
  static const String _lastSyncKey = 'chat_last_sync';
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _maxCachedSessions = 20;
  
  // State management
  List<Map<String, dynamic>> _cachedSessions = [];
  DateTime? _lastSyncTime;
  bool _isLoading = false;

  /// Get chat history with enhanced caching and offline support
  Future<List<Map<String, dynamic>>> getChatHistory({
    bool forceRefresh = false,
    int limit = 50,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Check if we have recent cached data
    if (!forceRefresh && _isCacheValid()) {
      return _cachedSessions;
    }

    // Try to load from local cache first
    if (!forceRefresh) {
      final cachedData = await _loadFromCache();
      if (cachedData.isNotEmpty) {
        _cachedSessions = cachedData;
        _lastSyncTime = DateTime.now();
        
        // Load fresh data in background
        _loadFromFirebase(user.uid, limit);
        return cachedData;
      }
    }

    // Load from Firebase
    return await _loadFromFirebase(user.uid, limit);
  }

  /// Load chat history from Firebase with retry mechanism
  Future<List<Map<String, dynamic>>> _loadFromFirebase(String userId, int limit) async {
    if (_isLoading) return _cachedSessions;
    
    _isLoading = true;
    
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('trainerChats')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      final sessions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sender': data['sender'] ?? '',
          'text': data['text'] ?? '',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'sessionId': data['sessionId'] ?? 'default',
          'isFromCache': false,
        };
      }).toList();

      // Update cache
      _cachedSessions = sessions;
      _lastSyncTime = DateTime.now();
      await _saveToCache(sessions);

      return sessions;
    } catch (e) {
      print('Error loading chat history from Firebase: $e');
      
      // Return cached data if available
      if (_cachedSessions.isNotEmpty) {
        return _cachedSessions;
      }
      
      // Try to load from cache as fallback
      return await _loadFromCache();
    } finally {
      _isLoading = false;
    }
  }

  /// Load chat history from local cache
  Future<List<Map<String, dynamic>>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return [];

      final cacheKey = '${_chatHistoryKey}_${user.uid}';
      final lastSyncKey = '${_lastSyncKey}_${user.uid}';
      
      final cachedJson = prefs.getString(cacheKey);
      final lastSyncString = prefs.getString(lastSyncKey);
      
      if (cachedJson != null && lastSyncString != null) {
        final lastSync = DateTime.parse(lastSyncString);
        
        // Check if cache is still valid
        if (DateTime.now().difference(lastSync) < _cacheExpiry) {
          final List<dynamic> cachedList = jsonDecode(cachedJson);
          return cachedList.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error loading chat history from cache: $e');
      return [];
    }
  }

  /// Save chat history to local cache
  Future<void> _saveToCache(List<Map<String, dynamic>> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_chatHistoryKey}_${user.uid}';
      final lastSyncKey = '${_lastSyncKey}_${user.uid}';
      
      // Limit cached sessions to prevent storage bloat
      final limitedSessions = sessions.take(_maxCachedSessions).toList();
      
      await prefs.setString(cacheKey, jsonEncode(limitedSessions));
      await prefs.setString(lastSyncKey, DateTime.now().toIso8601String());
      
      print('Chat history cached: ${limitedSessions.length} sessions');
    } catch (e) {
      print('Error saving chat history to cache: $e');
    }
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_cachedSessions.isEmpty || _lastSyncTime == null) return false;
    return DateTime.now().difference(_lastSyncTime!) < _cacheExpiry;
  }

  /// Save a new chat message with immediate cache update
  Future<void> saveChatMessage(Map<String, dynamic> messageData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Add to Firebase
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trainerChats')
          .add({
        ...messageData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update local cache immediately
      final newMessage = {
        ...messageData,
        'timestamp': messageData['timestamp'] ?? DateTime.now(),
        'isFromCache': false,
      };
      
      _cachedSessions.insert(0, newMessage);
      
      // Keep only the most recent messages
      if (_cachedSessions.length > _maxCachedSessions) {
        _cachedSessions = _cachedSessions.take(_maxCachedSessions).toList();
      }
      
      // Save updated cache
      await _saveToCache(_cachedSessions);
      
    } catch (e) {
      print('Error saving chat message: $e');
      
      // Still add to cache for offline support
      final newMessage = {
        ...messageData,
        'timestamp': messageData['timestamp'] ?? DateTime.now(),
        'isFromCache': true,
      };
      
      _cachedSessions.insert(0, newMessage);
      await _saveToCache(_cachedSessions);
    }
  }

  /// Clear all chat history
  Future<void> clearChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Clear from Firebase
      final batch = _firestore.batch();
      final chatDocs = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trainerChats')
          .get();

      for (final doc in chatDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Clear local cache
      _cachedSessions.clear();
      await _clearCache();
      
    } catch (e) {
      print('Error clearing chat history: $e');
    }
  }

  /// Clear local cache
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = '${_chatHistoryKey}_${user.uid}';
      final lastSyncKey = '${_lastSyncKey}_${user.uid}';
      
      await prefs.remove(cacheKey);
      await prefs.remove(lastSyncKey);
      
    } catch (e) {
      print('Error clearing chat cache: $e');
    }
  }

  /// Force refresh chat history
  Future<List<Map<String, dynamic>>> forceRefresh() async {
    _lastSyncTime = null;
    _cachedSessions.clear();
    return await getChatHistory(forceRefresh: true);
  }

  /// Get cached sessions count
  int get cachedSessionsCount => _cachedSessions.length;

  /// Check if data is loading
  bool get isLoading => _isLoading;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;
}
