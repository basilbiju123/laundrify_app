import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════
// FEEDBACK PAGE — User can submit complaints, suggestions,
// compliments, or general feedback. Stored in Firestore.
// ═══════════════════════════════════════════════════════════

const _fBlue = Color(0xFF1B4FD8);
const _fBlueSoft = Color(0xFF3B82F6);
const _fGreen = Color(0xFF10B981);
const _fAmber = Color(0xFFF59E0B);
const _fRose = Color(0xFFEF4444);

class FeedbackPage extends StatefulWidget {
  /// Optionally pre-fill an order ID if feedback is about a specific order
  final String? orderId;
  final String? orderSummary;

  const FeedbackPage({super.key, this.orderId, this.orderSummary});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();

  String _selectedCategory = 'complaint';
  int _rating = 0;
  bool _isSubmitting = false;
  bool _submitted = false;

  final _categories = [
    {
      'id': 'complaint',
      'label': 'Complaint',
      'icon': Icons.report_problem_rounded,
      'color': _fRose,
    },
    {
      'id': 'suggestion',
      'label': 'Suggestion',
      'icon': Icons.lightbulb_rounded,
      'color': _fAmber,
    },
    {
      'id': 'compliment',
      'label': 'Compliment',
      'icon': Icons.thumb_up_rounded,
      'color': _fGreen,
    },
    {
      'id': 'general',
      'label': 'General',
      'icon': Icons.chat_bubble_rounded,
      'color': _fBlueSoft,
    },
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please give a star rating before submitting.'),
          backgroundColor: _fRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final feedbackData = {
        'userId': user.uid,
        'userName': userData['name'] ?? user.displayName ?? 'Anonymous',
        'userEmail': userData['email'] ?? user.email ?? '',
        'userPhone': userData['phone'] ?? '',
        'category': _selectedCategory,
        'rating': _rating,
        'message': _messageCtrl.text.trim(),
        'orderId': widget.orderId ?? '',
        'orderSummary': widget.orderSummary ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Always write to user's own subcollection — always permitted
      final userFeedbackRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('feedbacks')
          .doc();
      await userFeedbackRef.set({...feedbackData, 'feedbackId': userFeedbackRef.id});

      // Also attempt top-level write for admin dashboard visibility.
      // Requires Firestore rule: allow create if request.auth.uid == request.resource.data.userId
      try {
        await FirebaseFirestore.instance.collection('feedbacks').add({
          ...feedbackData,
          'userFeedbackPath': 'users/${user.uid}/feedbacks/${userFeedbackRef.id}',
        });
      } catch (_) {
        // Top-level write denied by rules — user subcollection write already succeeded
      }

      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: _fRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: _submitted ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  // ── Success Screen ────────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _fGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _fGreen.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.check_circle_rounded, color: _fGreen, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thank You!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your feedback has been submitted successfully.\nOur team will review it and get back to you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _fBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Back to Orders',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form View ─────────────────────────────────────────────
  Widget _buildFormView() {
    final t = AppColors.of(context);
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feedback', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('We love hearing from you', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order reference banner
                  if (widget.orderId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _fBlueSoft.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _fBlueSoft.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: _fBlueSoft, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Regarding Order', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                Text(
                                  '#${widget.orderId!.substring(0, 8).toUpperCase()}${widget.orderSummary != null ? '  •  ${widget.orderSummary}' : ''}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Category selector
                  const Text(
                    'Feedback Type',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _categories.map((cat) {
                      final t = AppColors.of(context);
                      final isSelected = _selectedCategory == cat['id'];
                      final color = cat['color'] as Color;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat['id'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.15) : t.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? color.withValues(alpha: 0.5) : t.cardBdr,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(cat['icon'] as IconData, color: isSelected ? color : const Color(0xFF475569), size: 22),
                                const SizedBox(height: 6),
                                Text(
                                  cat['label'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? color : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Star Rating
                  const Text(
                    'Overall Rating',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBdr),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final filled = i < _rating;
                            return GestureDetector(
                              onTap: () => setState(() => _rating = i + 1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: filled ? const Color(0xFFF5C518) : const Color(0xFF334155),
                                  size: 40,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _rating == 0
                              ? 'Tap to rate'
                              : _rating == 1
                                  ? '😞  Very Unsatisfied'
                                  : _rating == 2
                                      ? '😕  Unsatisfied'
                                      : _rating == 3
                                          ? '😐  Neutral'
                                          : _rating == 4
                                              ? '😊  Satisfied'
                                              : '😄  Very Satisfied',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _rating == 0 ? const Color(0xFF475569) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Message
                  const Text(
                    'Your Message',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tell us about your experience, what went wrong, or how we can improve...',
                      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                      filled: true,
                      fillColor: t.card,
                      counterStyle: const TextStyle(color: Color(0xFF475569)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: t.cardBdr),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: t.cardBdr),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _fBlueSoft, width: 1.5),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your message';
                      if (v.trim().length < 10) return 'Message too short (min 10 characters)';
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fBlue,
                        disabledBackgroundColor: _fBlue.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Feedback',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
