import 'package:flutter/material.dart';
import '../widgets/chat_bubble.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../ui/app_colors.dart';

class TrainerSisirScreen extends StatefulWidget {
  const TrainerSisirScreen({super.key});

  @override
  State<TrainerSisirScreen> createState() => _TrainerSisirScreenState();
}

class _TrainerSisirScreenState extends State<TrainerSisirScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool isLoading = false;
  bool isDark = false;
  String? currentUserId;
  String currentSessionId = '';
  Map<String, dynamic> userProfile = {};
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> recentSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Get current user ID
    currentUserId = _firebaseService.getCurrentUserId();
    
    if (currentUserId != null) {
      // Generate new session ID
      currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Load user profile
      await _loadUserProfile();
      
      // Load recent chat sessions
      await _loadRecentSessions();
      
      // Load chat history
      _loadChatHistory();
      
      // Add welcome message if no chat history
      if (messages.isEmpty) {
        _addWelcomeMessage();
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (currentUserId == null) return;
    
    try {
      final profile = await _firebaseService.getUserProfile(currentUserId!);
      setState(() {
        userProfile = profile;
      });
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadRecentSessions() async {
    if (currentUserId == null) return;
    
    try {
      final sessions = await _firebaseService.getRecentChatSessions(currentUserId!);
      setState(() {
        recentSessions = sessions;
      });
    } catch (e) {
      print('Error loading recent sessions: $e');
    }
  }

  void _loadChatHistory() {
    if (currentUserId == null) return;
    
    _firebaseService.getTrainerChatHistory(currentUserId!).listen((chatHistory) {
      setState(() {
        messages = chatHistory;
      });
      
      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _addWelcomeMessage() {
    final userName = userProfile['name'] ?? 'there';
    final welcomeMessage = {
      'id': 'welcome',
      'sender': 'Sisir',
      'text': 'Hey $userName! 👋 I\'m Trainer Sisir, your personal fitness and nutrition coach. I\'m here to help you achieve your fitness goals with personalized advice. What would you like to know today? 💪',
      'timestamp': DateTime.now(),
    };
    
    setState(() {
      messages.add(welcomeMessage);
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentUserId == null) return;

    // Add user message to UI
    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': 'user',
      'text': text,
      'timestamp': DateTime.now(),
      'sessionId': currentSessionId,
    };

    setState(() {
      messages.add(userMessage);
      isLoading = true;
      _controller.clear();
    });

    // Save user message to Firebase
    try {
      await _firebaseService.saveTrainerChatMessage(currentUserId!, userMessage);
    } catch (e) {
      print('Error saving user message: $e');
    }

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Get AI response
      final aiResponse = await GeminiService.getPersonalizedResponse(
        userQuery: text,
        userProfile: userProfile,
        conversationHistory: messages.map((msg) => {
          'sender': msg['sender'],
          'text': msg['text'],
          'timestamp': msg['timestamp'],
        }).toList(),
      );

      // Add AI response to UI
      final sisirMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + '_sisir',
        'sender': 'Sisir',
        'text': aiResponse,
        'timestamp': DateTime.now(),
        'sessionId': currentSessionId,
      };

      setState(() {
        messages.add(sisirMessage);
        isLoading = false;
      });

      // Save AI response to Firebase
      try {
        await _firebaseService.saveTrainerChatMessage(currentUserId!, sisirMessage);
      } catch (e) {
        print('Error saving AI response: $e');
      }

    } catch (e) {
      // Handle error
      final errorMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + '_error',
        'sender': 'Sisir',
        'text': 'Sorry, I\'m having trouble connecting right now. Please try again in a moment! 🤖',
        'timestamp': DateTime.now(),
      };

      setState(() {
        messages.add(errorMessage);
        isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  Future<void> _clearChatHistory() async {
    if (currentUserId == null) return;

    try {
      await _firebaseService.clearTrainerChatHistory(currentUserId!);
      setState(() {
        messages.clear();
        recentSessions.clear();
      });
      _addWelcomeMessage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to clear chat history'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startNewChatSession() async {
    if (currentUserId == null) return;

    // Generate new session ID
    currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    setState(() {
      messages.clear();
    });
    
    _addWelcomeMessage();
    
    // Clean up old chat history to keep only last 5 sessions
    await _firebaseService.cleanupOldChatHistory(currentUserId!);
    
    // Reload recent sessions
    await _loadRecentSessions();
  }

  Future<void> _loadChatSession(String sessionId) async {
    if (currentUserId == null) return;

    try {
      // Set current session ID
      currentSessionId = sessionId;
      
      // Load messages for this specific session
      final sessionMessages = await _firebaseService
          .getTrainerChatHistory(currentUserId!)
          .first
          .then((allMessages) => allMessages
              .where((msg) => msg['sessionId'] == sessionId)
              .toList());

      setState(() {
        messages = sessionMessages;
      });

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error loading chat session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load chat session'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showChatHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChatHistoryDrawer(),
    );
  }

  Widget _buildChatHistoryDrawer() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.history,
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
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: kAccentBlue,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _startNewChatSession();
                  },
                  tooltip: 'New Chat',
                ),
              ],
            ),
          ),
          
          // Chat sessions list
          Expanded(
            child: recentSessions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recentSessions.length,
                    itemBuilder: (context, index) {
                      final session = recentSessions[index];
                      final isCurrentSession = session['sessionId'] == currentSessionId;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isCurrentSession
                              ? kAccentBlue.withOpacity(0.1)
                              : (isDark ? Colors.grey[800] : kSurfaceColor),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrentSession
                              ? Border.all(color: kAccentBlue, width: 1)
                              : null,
                          boxShadow: kCardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCurrentSession
                                  ? kAccentBlue
                                  : (isDark ? Colors.grey[700] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: isCurrentSession
                                  ? Colors.white
                                  : (isDark ? Colors.grey[300] : Colors.grey[600]),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            session['title'] ?? 'Chat Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : kTextDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                session['lastMessage'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : kTextSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.message,
                                    size: 14,
                                    color: isDark ? Colors.white60 : kTextTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${session['messageCount'] ?? 0} messages',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : kTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: isDark ? Colors.white60 : kTextTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(session['lastMessageTime']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : kTextTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isCurrentSession
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kAccentBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: isDark ? Colors.white60 : kTextTertiary,
                                ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadChatSession(session['sessionId']);
                          },
                        ),
                      );
                    },
                  ),
          ),
          
          // Footer with clear all button
          if (recentSessions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showClearAllDialog();
                      },
                      icon: Icon(Icons.delete_outline, color: kErrorColor),
                      label: Text(
                        'Clear All',
                        style: TextStyle(color: kErrorColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kErrorColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kAccentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: kAccentBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Chat History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with Trainer Sisir\nto see your chat history here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : kTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startNewChatSession();
            },
            icon: const Icon(Icons.add),
            label: const Text('Start New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Chats',
          style: TextStyle(
            color: isDark ? Colors.white : kTextDark,
          ),
        ),
        content: Text(
          'Are you sure you want to delete all your chat history? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.white70 : kTextSecondary,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: kErrorColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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
              CircleAvatar(
                backgroundColor: kAccentBlue,
                child: const Icon(Icons.directions_run, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Trainer Sisir',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : kTextDark,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.history, color: kAccentBlue),
              tooltip: 'Chat History',
              onPressed: _showChatHistoryDrawer,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: kAccentBlue),
              tooltip: 'New Chat',
              onPressed: _startNewChatSession,
            ),
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: kAccentBlue,
              ),
              onPressed: () => setState(() => isDark = !isDark),
              tooltip: isDark ? 'Light mode' : 'Dark mode',
            ),
          ],
        ),
        body: Column(
          children: [
            // Profile info banner (if profile data exists)
            if (userProfile.isNotEmpty) _buildProfileBanner(),
            
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length && isLoading) {
                    return _buildTypingIndicator();
                  }
                  
                  final message = messages[index];
                  return ChatBubble(
                    text: message['text'] ?? '',
                    sender: message['sender'] == 'user' ? 'You' : 'Sisir',
                    timestamp: message['timestamp'] ?? DateTime.now(),
                    isUser: message['sender'] == 'user',
                  );
                },
              ),
            ),
            
            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBanner() {
    final name = userProfile['name'] ?? 'User';
    final fitnessGoals = userProfile['fitnessGoals'] ?? 'General fitness';
    
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kPrimaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Goal: $fitnessGoals',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : kSurfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: kCardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(kAccentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sisir is thinking...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : kTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: isDark ? Colors.grey[850] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.mic_none, color: kAccentBlue),
            onPressed: () {
              // TODO: Implement voice input
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voice input coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Voice (coming soon)',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ask Trainer Sisir...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark 
                    ? Colors.grey[800] 
                    : kAccentBlue.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: kAccentBlue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: isLoading ? null : _sendMessage,
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}
