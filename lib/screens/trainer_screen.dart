import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../services/chat_history_manager.dart';
import '../ui/app_colors.dart';
import '../mixins/google_fit_sync_mixin.dart';

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;

  Message({
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}

class AITrainerScreen extends StatefulWidget {
  const AITrainerScreen({super.key});

  @override
  State<AITrainerScreen> createState() => _AITrainerScreenState();
}

class ChatSession {
  final String id;
  final String title;
  final List<Message> messages;
  final DateTime timestamp;
  final String userId;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'messages': messages
          .map((m) => {
                'sender': m.sender,
                'text': m.text,
                'timestamp': m.timestamp.millisecondsSinceEpoch,
              })
          .toList(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'userId': userId,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      messages: (map['messages'] as List<dynamic>?)
              ?.map((m) => Message(
                    sender: m['sender'] ?? '',
                    text: m['text'] ?? '',
                    timestamp: DateTime.fromMillisecondsSinceEpoch(
                        m['timestamp'] ?? 0),
                  ))
              .toList() ??
          [],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      userId: map['userId'] ?? '',
    );
  }
}

class _AITrainerScreenState extends State<AITrainerScreen>
    with GoogleFitSyncMixin, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final ChatHistoryManager _chatHistoryManager = ChatHistoryManager();

  bool isDark = false;
  bool isLoading = false;
  bool isPremium = true; // Set to true for demo purposes
  bool isLoadingHistory = false;
  Map<String, dynamic>? _userProfile;

  List<Message> messages = [
    Message(
        sender: 'Sisir',
        text:
            'Hey there! I\'m Trainer Sisir, your personal fitness and nutrition coach. I\'m here to help you reach your health goals with personalized advice and support. What would you like to work on today? 💪',
        timestamp: DateTime.now()),
  ];

  List<ChatSession> chatSessions = [];
  String? currentSessionId;
  DateTime? _lastHistoryLoad;
  String? _lastLoadedUserId; // Track the last loaded user ID
  Map<String, dynamic>? _currentFitnessData;
  StateSetter? _currentModalState; // Store current modal state for updates
  final ValueNotifier<List<ChatSession>> _chatSessionsNotifier = ValueNotifier<List<ChatSession>>([]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumStatus();
    _loadUserProfile();
    // Load chat history from cache first, then check for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatHistory(); // This will try cache first, then Firebase
    });
    initializeGoogleFitSync();
  }

  /// Override mixin method to handle Google Fit data updates
  @override
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    super.onGoogleFitDataUpdate(syncData);

    // Store fitness data for AI trainer to use in recommendations
    _currentFitnessData = syncData;
    print(
        'Trainer screen: Updated with Google Fit data - Steps: ${syncData['steps']}');
  }

  /// Override mixin method to handle Google Fit connection changes
  @override
  void onGoogleFitConnectionChanged(bool isConnected) {
    super.onGoogleFitConnectionChanged(isConnected);
    print(
        'Trainer screen: Google Fit connection changed - Connected: $isConnected');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clear modal state reference to prevent setState after dispose
    _currentModalState = null;
    // Dispose ValueNotifier
    _chatSessionsNotifier.dispose();
    // Save current session when leaving the screen (silently)
    if (currentSessionId != null && messages.length > 1) {
      // Fire and forget - don't await in dispose
      _saveCurrentSessionSilently().catchError((e) {
        print('Error saving session on dispose: $e');
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reload chat history when app becomes active
      _checkUserAndReloadHistory();
    }
  }

  Future<void> _checkPremiumStatus() async {
    // Simulate premium check - in real app, this would check user's subscription
    if (mounted) {
      setState(() {
        isPremium = true; // Set to true for demo purposes
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final profile = await _firebaseService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadChatHistory({bool forceRefresh = false}) async {
    if (!isPremium) return;

    // Don't reload if already loading
    if (isLoadingHistory) return;

    if (mounted) {
      setState(() {
        isLoadingHistory = true;
      });
    }

    try {
      // Use the enhanced chat history manager
      final history = await _chatHistoryManager.getChatHistory(
        forceRefresh: forceRefresh,
        limit: 20, // Reduced limit for better performance
      );

      // Convert to ChatSession objects
      final sessions = history.map((data) {
        try {
          final title = data['title'] ?? '';
          final messages = data['messages'] as List<dynamic>? ?? [];
          
          // Convert messages to Message objects
          final messageList = messages.map((msg) => Message(
            sender: msg['sender'] ?? 'user',
            text: msg['text'] ?? '',
            timestamp: msg['timestamp'] is int 
                ? DateTime.fromMillisecondsSinceEpoch(msg['timestamp'])
                : DateTime.now(),
          )).toList();
          
          return ChatSession(
            id: data['id'] ?? '',
            userId: _auth.currentUser?.uid ?? '',
            title: title,
            messages: messageList,
            timestamp: data['timestamp'] is int 
                ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'])
                : DateTime.now(),
          );
        } catch (e) {
          print('Error converting chat data: $e');
          return null;
        }
      }).where((session) => session != null).cast<ChatSession>().toList();

      if (mounted) {
        setState(() {
          chatSessions = sessions;
          _lastHistoryLoad = DateTime.now();
        });
      }

      print('Chat history loaded: ${sessions.length} sessions');
    } catch (e) {
      print('Error loading chat history: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingHistory = false;
        });
      }
    }
  }

  /// Force reload chat history (useful after login/logout)
  Future<void> _forceReloadChatHistory() async {
    print('Force reloading chat history...');
    _lastHistoryLoad = null; // Clear cache
    await _loadChatHistory(forceRefresh: true);
  }

  /// Check if user has changed and reload chat history if needed
  Future<void> _checkUserAndReloadHistory() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid != _lastLoadedUserId) {
      print('User changed, reloading chat history for: ${currentUser.uid}');
      _lastLoadedUserId = currentUser.uid;
      // Only reload if we don't have any current sessions
      if (chatSessions.isEmpty) {
        await _forceReloadChatHistory();
      }
    }
  }

  /// Cache chat sessions to local storage
  Future<void> _cacheChatSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = 'chat_sessions_${user.uid}';
      final sessionsJson = chatSessions.map((session) => session.toMap()).toList();
      final sessionsString = jsonEncode(sessionsJson);
      
      await prefs.setString(cacheKey, sessionsString);
      await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('Chat sessions cached locally');
    } catch (e) {
      print('Error caching chat sessions: $e');
    }
  }

  /// Load chat sessions from local cache
  Future<bool> _loadChatSessionsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return false;

      final cacheKey = 'chat_sessions_${user.uid}';
      final sessionsString = prefs.getString(cacheKey);
      final cacheTimestamp = prefs.getInt('${cacheKey}_timestamp') ?? 0;
      
      if (sessionsString != null) {
        // Check if cache is recent (less than 1 hour old)
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < 3600000) { // 1 hour in milliseconds
          final sessionsJson = jsonDecode(sessionsString) as List;
          final sessions = sessionsJson
              .map((json) => ChatSession.fromMap(json))
              .toList();
          
          if (mounted) {
            setState(() {
              chatSessions = sessions;
              _lastHistoryLoad = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
            });
          }
          print('Chat sessions loaded from cache: ${sessions.length} sessions');
          return true; // Cache was used
        }
      }
      return false; // Cache was not used
    } catch (e) {
      print('Error loading chat sessions from cache: $e');
      return false;
    }
  }

  /// Clear chat sessions cache
  Future<void> _clearChatSessionsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;

      final cacheKey = 'chat_sessions_${user.uid}';
      await prefs.remove(cacheKey);
      await prefs.remove('${cacheKey}_timestamp');
      print('Chat sessions cache cleared');
    } catch (e) {
      print('Error clearing chat sessions cache: $e');
    }
  }

  /// Force refresh the chat history UI
  void _refreshChatHistoryUI() {
    if (mounted) {
      // Immediate UI refresh without delay
      setState(() {
        // Force rebuild by updating a dummy variable
        // This ensures the chat history bottom sheet refreshes
      });
    }
  }

  Future<void> _saveCurrentSession() async {
    if (!isPremium) return;

    // Only save if there are user messages (more than just the welcome message)
    final userMessages = messages.where((msg) => msg.sender == 'user').toList();
    if (userMessages.isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final sessionId =
          currentSessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final firstUserMessage = userMessages.first;

      final title = firstUserMessage.text.length > 30
          ? '${firstUserMessage.text.substring(0, 30)}...'
          : firstUserMessage.text;

      final session = ChatSession(
        id: sessionId,
        title: title,
        messages: messages,
        timestamp: DateTime.now(),
        userId: user.uid,
      );

      // Update local history immediately for instant UI update
      if (mounted) {
        setState(() {
          currentSessionId = sessionId;
          chatSessions.removeWhere((s) => s.id == sessionId);
          chatSessions.insert(0, session);
          if (chatSessions.length > 10) {
            chatSessions = chatSessions.take(10).toList();
          }
        });
      }
      
      // Use ChatHistoryManager for consistent storage
      await _chatHistoryManager.saveChatSession(session.toMap());
      
      // Update modal if it's open and still mounted
      if (_currentModalState != null && mounted) {
        try {
          _currentModalState!(() {});
        } catch (e) {
          print('Error updating modal state: $e');
          _currentModalState = null; // Clear invalid reference
        }
      }

      // Cleanup old sessions in background (non-blocking)
      _cleanupOldSessions();

    } catch (e) {
      print('Error preparing chat session: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving chat: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentSessionSilently() async {
    if (!isPremium) return;

    // Only save if there are user messages (more than just the welcome message)
    final userMessages = messages.where((msg) => msg.sender == 'user').toList();
    if (userMessages.isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final sessionId =
          currentSessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final firstUserMessage = userMessages.first;

      final title = firstUserMessage.text.length > 30
          ? '${firstUserMessage.text.substring(0, 30)}...'
          : firstUserMessage.text;

      final session = ChatSession(
        id: sessionId,
        title: title,
        messages: messages,
        timestamp: DateTime.now(),
        userId: user.uid,
      );

      // Update local history immediately for instant UI update (without triggering refresh)
      if (mounted) {
        setState(() {
          currentSessionId = sessionId;
          chatSessions.removeWhere((s) => s.id == sessionId);
          chatSessions.insert(0, session);
          if (chatSessions.length > 10) {
            chatSessions = chatSessions.take(10).toList();
          }
        });
      }
      
      // Use ChatHistoryManager for consistent storage (silently)
      _chatHistoryManager.saveChatSession(session.toMap());
      
      // Update modal if it's open and still mounted
      if (_currentModalState != null && mounted) {
        try {
          _currentModalState!(() {});
        } catch (e) {
          print('Error updating modal state: $e');
          _currentModalState = null; // Clear invalid reference
        }
      }

      // Cleanup old sessions in background (non-blocking)
      _cleanupOldSessions();
    } catch (e) {
      print('Error preparing chat session: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving chat: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _cleanupOldSessions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.length > 5) {
        // Sort by timestamp and get the oldest ones to delete
        final sortedDocs = querySnapshot.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['timestamp'] as int? ?? 0;
            final bTime = b.data()['timestamp'] as int? ?? 0;
            return aTime.compareTo(bTime); // Ascending order (oldest first)
          });

        final docsToDelete = sortedDocs.skip(5);
        final batch = _firestore.batch();

        for (final doc in docsToDelete) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error cleaning up old sessions: $e');
    }
  }

  Future<void> _loadSession(ChatSession session) async {
    if (mounted) {
      setState(() {
        messages = List.from(session.messages);
        currentSessionId = session.id;
      });
    }

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (mounted) {
      setState(() {
        messages
            .add(Message(sender: 'user', text: text, timestamp: DateTime.now()));
        isLoading = true;
      });
    }
    _controller.clear();

    await Future.delayed(const Duration(milliseconds: 300));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    String reply;
    try {
      // Check if still mounted before making AI call
      if (!mounted) return;
      
      // Convert messages to conversation history format
      final conversationHistory = messages
          .where((msg) =>
              msg.sender != 'Sisir' ||
              !msg.text.contains('Hey there! I\'m Trainer Sisir'))
          .map((msg) => {
                'role': msg.sender == 'user' ? 'user' : 'assistant',
                'content': msg.text,
              })
          .toList();

      reply = await AIService.askTrainerSisir(
        text,
        userProfile: _userProfile,
        conversationHistory: conversationHistory,
        currentFitnessData: _currentFitnessData,
      );
    } catch (e) {
      reply = 'Sorry, there was a problem connecting to the AI service.';
    }

    if (mounted) {
      setState(() {
        messages.add(
            Message(sender: 'Sisir', text: reply, timestamp: DateTime.now()));
        isLoading = false;
      });
    }

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Save session after getting response (with error handling)
    try {
      if (mounted) {
        await _saveCurrentSession();
      }
    } catch (e) {
      print('Error saving session after message: $e');
      // Don't show error to user as this is background operation
    }
  }

  void _startNewChat() {
    // Save current session before starting new one (without triggering refresh)
    if (currentSessionId != null && messages.length > 1) {
      // Fire and forget - don't await in synchronous method
      _saveCurrentSessionSilently().catchError((e) {
        print('Error saving session before new chat: $e');
      });
    }

    if (mounted) {
      setState(() {
        messages = [
          Message(
              sender: 'Sisir',
            text:
                'Hey there! I\'m Trainer Sisir, your personal fitness and nutrition coach. I\'m here to help you reach your health goals with personalized advice and support. What would you like to work on today? 💪',
            timestamp: DateTime.now()),
        ];
        currentSessionId = null;
      });
    }
  }

  void _showChatHistory() {
    // Check if user has changed and reload if needed
    _checkUserAndReloadHistory();
    
    // Initialize ValueNotifier with current chatSessions
    _chatSessionsNotifier.value = List.from(chatSessions);
    
    // Show the bottom sheet immediately with existing data
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Store the setModalState for use in save operations
          _currentModalState = setModalState;
          return _buildHistoryBottomSheet(setModalState);
        },
      ),
    ).whenComplete(() {
      // Clear the modal state reference when modal is dismissed
      _currentModalState = null;
    });

    // Don't reload chat history when popup opens to preserve current state
    // The chatSessions list already contains the most recent data
  }

  Widget _buildHistoryBottomSheet([StateSetter? setModalState]) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.chat,
                  color: kAccentBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Chat History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : kTextDark,
                  ),
                ),
                const Spacer(),
                if (isPremium && chatSessions.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showDeleteAllDialog(setModalState),
                    icon: Icon(
                      Icons.delete_sweep,
                      color: Colors.red[600],
                      size: 18,
                    ),
                    label: Text(
                      'Clear All',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!isPremium)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildHistoryContent(setModalState),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent([StateSetter? setModalState]) {
    if (!isPremium) {
      return _buildPremiumLockScreen();
    }

    // Show empty state immediately if no data (no loading state for empty)
    // Force loading state to false when showing empty state
    if (chatSessions.isEmpty) {
      // Ensure no loading state when showing empty
      if (isLoadingHistory) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              isLoadingHistory = false;
            });
          }
        });
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No chat history yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with Trainer Sisir!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startNewChat();
              },
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startNewChat();
              },
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
          Expanded(
            child: ValueListenableBuilder<List<ChatSession>>(
              valueListenable: _chatSessionsNotifier,
              builder: (context, sessions, child) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _buildSessionCard(session, setModalState);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumLockScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock,
                size: 48,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Upgrade to Premium',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'to view your past chats',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _upgradeToPremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Upgrade Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(ChatSession session, [StateSetter? setModalState]) {
    final isCurrentSession = currentSessionId == session.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentSession ? kAccentBlue : Colors.grey.withOpacity(0.3),
          width: isCurrentSession ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kAccentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.chat_bubble,
            color: kAccentBlue,
            size: 20,
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : kTextDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDateTime(session.timestamp),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentSession)
              const Icon(
                Icons.check_circle,
                color: kAccentBlue,
                size: 20,
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red[400],
                size: 18,
              ),
              onPressed: () => _showDeleteDialog(session, setModalState),
              tooltip: 'Delete chat',
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          _loadSession(session);
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _upgradeToPremium() {
    // Placeholder for premium upgrade functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Premium upgrade feature coming soon!'),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showDeleteDialog(ChatSession session, [StateSetter? setModalState]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          title: Text(
            'Delete Chat',
            style: TextStyle(
              color: isDark ? Colors.white : kTextDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${session.title}"? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSession(session, setModalState);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllDialog([StateSetter? setModalState]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          title: Text(
            'Clear All Chats',
            style: TextStyle(
              color: isDark ? Colors.white : kTextDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete all chat history? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllSessions(setModalState);
              },
              child: Text(
                'Clear All',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteSession(ChatSession session, [StateSetter? setModalState]) {
    // Check if this is the current session before deleting
    final isCurrentSession = currentSessionId == session.id;
    
    // Optimistic update - remove from UI immediately
    if (mounted) {
      // Update ValueNotifier first for instant modal update
      final updatedSessions = chatSessions.where((s) => s.id != session.id).toList();
      _chatSessionsNotifier.value = updatedSessions;
      
      setState(() {
        chatSessions = updatedSessions;
        isLoadingHistory = false;
        
        // If this was the current session, reset to new chat state immediately
        if (isCurrentSession) {
          messages = [
            Message(
                sender: 'Sisir',
              text:
                  'Hey there! I\'m Trainer Sisir, your personal fitness and nutrition coach. I\'m here to help you reach your health goals with personalized advice and support. What would you like to work on today? 💪',
              timestamp: DateTime.now()),
          ];
          currentSessionId = null;
        }
      });
    }

    // Show success message immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chat deleted successfully'),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );

    // Delete using ChatHistoryManager for consistent cache/Firebase update (fire and forget)
    _chatHistoryManager.deleteChatSession(session.id).catchError((e) {
      print('Error deleting session: $e');
    });
  }

  void _deleteAllSessions([StateSetter? setModalState]) {
    // Optimistic update - clear UI immediately
    if (mounted) {
      // Update ValueNotifier first for instant modal update
      _chatSessionsNotifier.value = [];
      
      setState(() {
        chatSessions.clear();
        isLoadingHistory = false; // Ensure no loading state after clearing
        _startNewChat();
      });
    }

    // ValueNotifier already handles modal updates, no need for setModalState

    // Show success message immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All chats cleared successfully'),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );

    // Delete using ChatHistoryManager for consistent cache/Firebase update (fire and forget)
    _chatHistoryManager.clearChatHistory().catchError((e) {
      print('Error clearing all sessions: $e');
      // Don't show error to user since UI already updated optimistically
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDark ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : kSoftWhite,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : kSoftWhite,
          elevation: 0,
          title: Row(
            children: [
              Image.asset(
                'calorie_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Text('Trainer Sisir',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : kTextDark)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat, color: kAccentBlue),
              tooltip: 'Chat History',
              onPressed: _showChatHistory,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == messages.length && isLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }
                  final msg = messages[i];
                  return _buildEnhancedChatBubble(msg);
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ask Trainer Sisir... ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey[800]
                            : kAccentBlue.withOpacity(0.08),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) async => await _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: kAccentBlue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                      tooltip: 'Send',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedChatBubble(Message msg) {
    final isUser = msg.sender == 'user';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [kAccentBlue, kAccentBlue.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          isDark ? Colors.grey[800]! : Colors.white,
                          isDark ? Colors.grey[700]! : Colors.grey[50]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isUser
                      ? kAccentBlue.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : (isDark ? Colors.white : kTextDark),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
