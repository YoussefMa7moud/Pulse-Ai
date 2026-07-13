import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/database_service.dart';
import '../../../data/collections/chat_message.dart';
import '../../providers/providers.dart';
import '../../providers/data_providers.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import 'package:go_router/go_router.dart';

/// AI Coach screen — every response is grounded in the user's real
/// health data (injected into every system prompt).
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  // In-memory conversation history for multi-turn context
  final List<Map<String, String>> _conversationHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = ref.read(databaseProvider);
    final stored = await db.getChatHistory();
    setState(() {
      _messages.addAll(stored);
      // Rebuild conversation history for the AI from stored messages
      for (final msg in stored.take(20)) {
        _conversationHistory.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _textController.clear();

    final db = ref.read(databaseProvider);
    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await db.addChatMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    // Add to in-memory conversation history
    _conversationHistory.add({'role': 'user', 'content': text});

    try {
      final aiService = ref.read(aiServicesProvider);

      // Every response is grounded in the full health data
      final response = await aiService.askCoach(
        userQuestion: text,
        conversationHistory: _conversationHistory
            .take(_conversationHistory.length - 1) // exclude the message we just added
            .toList(),
      );

      // Add assistant response to conversation history
      _conversationHistory.add({'role': 'assistant', 'content': response});

      final aiMsg = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      await db.addChatMessage(aiMsg);
      setState(() {
        _messages.add(aiMsg);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      final errorMsg = ChatMessage(
        text: 'Sorry, I encountered an error. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      await db.addChatMessage(errorMsg);
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
    }
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

  void _clearChat() async {
    final db = ref.read(databaseProvider);
    await db.clearChatHistory();
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch today's metric to show a context badge
    final metricAsync = ref.watch(todayMetricsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Health Coach'),
            metricAsync.when(
              data: (m) => Text(
                'Answers based on your health data',
                style: TextStyle(
                    fontSize: 11, color: PulseTheme.recoveryHigh),
              ),
              loading: () => Text('Loading health data...',
                  style: TextStyle(fontSize: 11, color: PulseTheme.secondary)),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: PulseTheme.secondary),
            tooltip: 'Clear conversation',
            onPressed: _clearChat,
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: PulseTheme.primary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Health context badge ──────────────────────────────────────
              metricAsync.when(
                data: (m) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: PulseTheme.recoveryHigh.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: PulseTheme.recoveryHigh.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.health_and_safety,
                          color: PulseTheme.recoveryHigh, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _buildContextBadge(m),
                          style: TextStyle(
                              color: PulseTheme.recoveryHigh, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              // ── Messages ─────────────────────────────────────────────────
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) =>
                            _buildMessageBubble(_messages[i]),
                      ),
              ),

              // ── Suggested questions ───────────────────────────────────────
              if (_messages.isEmpty) _buildSuggestions(),

              // ── Loading indicator ─────────────────────────────────────────
              if (_isLoading)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PulseTheme.accent),
                      ),
                      const SizedBox(width: 10),
                      Text('Analysing your health data...',
                          style: TextStyle(
                              color: PulseTheme.secondary, fontSize: 12)),
                    ],
                  ),
                ),

              // ── Input bar ────────────────────────────────────────────────
              _buildInputBar(),
            ],
          ),
        ),
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
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                PulseTheme.accent.withOpacity(0.2),
                Colors.transparent,
              ]),
            ),
            child: Icon(Icons.chat_bubble_outline,
                color: PulseTheme.accent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Ask me anything about your health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Every answer is based on your real\nhealth data',
            textAlign: TextAlign.center,
            style: TextStyle(color: PulseTheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'Why is my recovery low today?',
      'How was my sleep quality last night?',
      'Am I overtraining? Check my strain.',
      'What should I do to reduce my stress score?',
      'Analyse my heart rate variability trend',
      'Is my VO2 Max improving?',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: suggestions
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(s,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: PulseTheme.surface,
                    side: BorderSide(
                        color: PulseTheme.accent.withOpacity(0.3)),
                    onPressed: () => _sendMessage(s),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  PulseTheme.accent.withOpacity(0.3),
                  PulseTheme.sleepPrimary.withOpacity(0.3),
                ]),
              ),
              child: Icon(Icons.auto_awesome,
                  size: 16, color: PulseTheme.accent),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? PulseTheme.accent.withOpacity(0.15)
                    : PulseTheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isUser
                      ? PulseTheme.accent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? PulseTheme.accent : PulseTheme.primary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PulseTheme.accent.withOpacity(0.15),
              ),
              child: Icon(Icons.person, size: 18, color: PulseTheme.accent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: PulseTheme.surface.withOpacity(0.6),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: PulseTheme.isDark ? Colors.white : Colors.black87),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: 'Ask about your health data...',
                hintStyle:
                    TextStyle(color: PulseTheme.secondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: PulseTheme.background.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [PulseTheme.accent, PulseTheme.sleepPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a compact context badge showing key metrics from today's data.
  String _buildContextBadge(m) {
    final parts = <String>[];
    if (m.restingHeartRate != null) {
      parts.add('RHR ${m.restingHeartRate!.toStringAsFixed(0)}');
    }
    if (m.totalSleepMinutes != null) {
      final h = m.totalSleepMinutes! ~/ 60;
      final min = m.totalSleepMinutes! % 60;
      parts.add('Sleep ${h}h${min}m');
    }
    if (m.stressScore != null) {
      parts.add('Stress ${m.stressScore!.toStringAsFixed(0)}');
    }
    if (m.bloodOxygenSpO2 != null) {
      parts.add('SpO2 ${m.bloodOxygenSpO2!.toStringAsFixed(0)}%');
    }
    if (parts.isEmpty) return 'Health data loaded';
    return parts.join(' · ');
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
