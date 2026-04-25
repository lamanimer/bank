import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session.dart';
import '../services/ai_service.dart';

class PocketAssistantScreen extends StatefulWidget {
  const PocketAssistantScreen({super.key});

  @override
  State<PocketAssistantScreen> createState() => _PocketAssistantScreenState();
}

class _PocketAssistantScreenState extends State<PocketAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  final List<String> _questions = [
    "Where am I spending the most?",
    "How can I save more money?",
    "What should I improve this month?",
    "How close am I to my goals?",
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || _loading) return;

    final user = await Session.loadUser();
    final userId = Session.getUserId(user);

    if (userId == null || userId.isEmpty) return;

    final leanTx = await Session.getLeanTransactions();
    final manualTx = await Session.getManualTransactions(userId: userId);
    final transactions = [...manualTx, ...leanTx];

    final goals = await Session.getGoalsForUser(userId: userId);
    final totals = await Session.getTotals();

    setState(() {
      _messages.add({"role": "user", "text": message});
      _loading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final reply = await AiService.askAssistant(
        userId: userId,
        question: message,
        transactions: transactions,
        goals: goals.map((g) => g.toJson()).toList(),
        totals: totals,
      );

      setState(() {
        _messages.add({"role": "assistant", "text": reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": "Something went wrong. Please try again.",
        });
      });
    } finally {
      setState(() {
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg["role"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFD9EAFE)
              : const Color.fromRGBO(255, 255, 255, 0.82),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(80, 40, 120, 0.08),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.55),
          ),
        ),
        child: Text(
          msg["text"] ?? "",
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B103C),
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.82),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(80, 40, 120, 0.08),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(),
            const SizedBox(width: 4),
            _dot(),
            const SizedBox(width: 4),
            _dot(),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF8F7BFF),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8DAFF),
            Color(0xFFD8C4FF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(90, 40, 150, 0.12),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 30,
              color: Color(0xFF5F44B3),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pocket Assistant",
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2B103C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Your smart finance companion",
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromRGBO(43, 16, 60, 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Ask about your spending, savings, goals, and habits.",
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromRGBO(43, 16, 60, 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionChip(String q) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _sendMessage(q),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color.fromRGBO(222, 205, 255, 0.82),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.65),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(80, 40, 120, 0.06),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          q,
          style: GoogleFonts.baloo2(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF3A1B52),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFEAF3);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Pocket Assistant",
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2B103C),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      if (_messages.isEmpty) ...[
                        _buildWelcomeCard(),
                        const SizedBox(height: 16),
                        Text(
                          "Try asking one of these",
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3A1B52),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              _questions.map(_buildQuestionChip).toList(),
                        ),
                        const SizedBox(height: 18),
                      ],
                      ..._messages.map(_buildBubble),
                      if (_loading) _buildTypingBubble(),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 234, 243, 0.95),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(80, 40, 120, 0.06),
                        blurRadius: 14,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.86),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(80, 40, 120, 0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2B103C),
                            ),
                            decoration: InputDecoration(
                              hintText: "Ask Pocket Assistant...",
                              hintStyle: GoogleFonts.baloo2(
                                fontWeight: FontWeight.w700,
                                color:
                                    const Color.fromRGBO(43, 16, 60, 0.45),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _sendMessage(_controller.text),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFB89CFF),
                                Color(0xFF8F7BFF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(100, 70, 220, 0.22),
                                blurRadius: 14,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}