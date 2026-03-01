import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════
// CANCEL ORDER PAGE — Cancel with cashback processing.
//
// Cashback Policy:
//   - Cancelled before pickup   → 100% refund
//   - Cancelled after pickup    →  50% refund
//   - Cancelled after processing→   0% refund (no refund)
//
// Cashback goes to user's wallet (stored in Firestore).
// Required fields collected for bank cashback if wallet
// balance is below a threshold.
// ═══════════════════════════════════════════════════════════

const _cNavy = Color(0xFF080F1E);
const _cCard = Color(0xFF111827);
const _cBorder = Color(0xFF1C2537);
const _cBlue = Color(0xFF1B4FD8);
const _cBlueSoft = Color(0xFF3B82F6);
const _cGreen = Color(0xFF10B981);
const _cAmber = Color(0xFFF59E0B);
const _cRose = Color(0xFFEF4444);

class CancelOrderPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const CancelOrderPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<CancelOrderPage> createState() => _CancelOrderPageState();
}

class _CancelOrderPageState extends State<CancelOrderPage> {
  int _step = 0; // 0 = reason, 1 = cashback details, 2 = confirm, 3 = done

  // Step 0 — Reason
  String? _selectedReason;
  final _otherReasonCtrl = TextEditingController();

  // Step 1 — Cashback bank details (only needed if refundMethod == 'bank')
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _confirmAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  String _refundMethod = 'wallet'; // 'wallet' | 'bank' | 'upi'

  bool _isProcessing = false;

  final _bankFormKey = GlobalKey<FormState>();

  final _reasons = [
    'Changed my mind',
    'Ordered by mistake',
    'Found a better price elsewhere',
    'Delay in service',
    'Poor quality in previous order',
    'Emergency / personal reason',
    'Other',
  ];

  // ── Cashback calculation ───────────────────────────────────
  double get _orderTotal =>
      (widget.orderData['total'] ?? widget.orderData['totalAmount'] ?? 0).toDouble();

  String get _orderStatus => widget.orderData['status'] ?? 'confirmed';

  /// Returns cashback percentage based on order stage
  double get _cashbackPercent {
    switch (_orderStatus) {
      case 'confirmed':
        return 1.0; // 100%
      case 'pickup':
        return 1.0; // still before actual pickup started
      case 'processing':
        return 0.5; // 50%
      case 'ready':
      case 'out_for_delivery':
      case 'delivered':
        return 0.0; // 0%
      default:
        return 1.0;
    }
  }

  double get _cashbackAmount => _orderTotal * _cashbackPercent;

  bool get _canCancel =>
      !['delivered', 'cancelled'].contains(_orderStatus);

  String get _cashbackLabel {
    if (_cashbackPercent == 1.0) return '100% Refund';
    if (_cashbackPercent == 0.5) return '50% Refund';
    return 'No Refund';
  }

  Color get _cashbackColor {
    if (_cashbackPercent == 1.0) return _cGreen;
    if (_cashbackPercent == 0.5) return _cAmber;
    return _cRose;
  }

  String get _cashbackReason {
    switch (_orderStatus) {
      case 'confirmed':
      case 'pickup':
        return 'Order cancelled before processing started.';
      case 'processing':
        return 'Order already picked up & being processed. 50% refund applies.';
      default:
        return 'Order is too far along to be cancelled.';
    }
  }

  @override
  void dispose() {
    _otherReasonCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  // ── Step navigation ────────────────────────────────────────
  void _nextStep() {
    if (_step == 0) {
      if (_selectedReason == null) {
        _showSnack('Please select a reason', _cRose);
        return;
      }
      if (_selectedReason == 'Other' && _otherReasonCtrl.text.trim().isEmpty) {
        _showSnack('Please describe your reason', _cRose);
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_refundMethod == 'bank') {
        if (!_bankFormKey.currentState!.validate()) return;
      } else if (_refundMethod == 'upi') {
        if (_upiCtrl.text.trim().isEmpty) {
          _showSnack('Please enter your UPI ID', _cRose);
          return;
        }
      }
      setState(() => _step = 2);
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Confirm Cancellation ──────────────────────────────────
  Future<void> _confirmCancellation() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final db = FirebaseFirestore.instance;

      // 1. Mark order as cancelled
      final reason = _selectedReason == 'Other'
          ? _otherReasonCtrl.text.trim()
          : _selectedReason!;

      final cancelData = <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cashbackAmount': _cashbackAmount,
        'cashbackPercent': (_cashbackPercent * 100).toInt(),
        'refundMethod': _refundMethod,
        'refundStatus': 'initiated', // initiated | processed | failed
      };

      // Add refund details based on method
      if (_refundMethod == 'bank') {
        cancelData['refundBankDetails'] = {
          'accountName': _accountNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'bankName': _bankNameCtrl.text.trim(),
        };
      } else if (_refundMethod == 'upi') {
        cancelData['refundUpiId'] = _upiCtrl.text.trim();
      }

      // Update under global orders and user's subcollection
      final batch = db.batch();

      // User's order subcollection
      final userOrderRef = db
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(widget.orderId);
      batch.update(userOrderRef, cancelData);

      // Global orders collection (if exists)
      final globalOrderRef = db.collection('orders').doc(widget.orderId);
      batch.update(globalOrderRef, cancelData);

      // 2. If wallet refund: add to user wallet balance
      if (_refundMethod == 'wallet' && _cashbackAmount > 0) {
        final userRef = db.collection('users').doc(user.uid);
        batch.set(
          userRef,
          {'walletBalance': FieldValue.increment(_cashbackAmount)},
          SetOptions(merge: true),
        );

        // Wallet transaction record
        final txnRef = db
            .collection('users')
            .doc(user.uid)
            .collection('walletTransactions')
            .doc();
        batch.set(txnRef, {
          'type': 'cashback',
          'amount': _cashbackAmount,
          'description': 'Cashback for cancelled order #${widget.orderId.substring(0, 8).toUpperCase()}',
          'orderId': widget.orderId,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'completed',
        });
      }

      // 3. Refund record in top-level collection for admin visibility
      final refundRef = db.collection('refunds').doc();
      batch.set(refundRef, {
        'userId': user.uid,
        'orderId': widget.orderId,
        'orderTotal': _orderTotal,
        'cashbackAmount': _cashbackAmount,
        'cashbackPercent': (_cashbackPercent * 100).toInt(),
        'refundMethod': _refundMethod,
        'refundStatus': _refundMethod == 'wallet' ? 'completed' : 'initiated',
        'cancellationReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        if (_refundMethod == 'bank') 'bankDetails': {
          'accountName': _accountNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'bankName': _bankNameCtrl.text.trim(),
        },
        if (_refundMethod == 'upi') 'upiId': _upiCtrl.text.trim(),
      });

      await batch.commit();

      setState(() {
        _isProcessing = false;
        _step = 3;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Cancellation failed: $e', _cRose);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_step < 3) _buildStepIndicator(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _step == 0 ? Navigator.pop(context) : _prevStep(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cancel Order',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              Text(
                '#${widget.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step Indicator ─────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = ['Reason', 'Refund', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < _step ? _cBlue : _cBorder,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < _step;
          final active = idx == _step;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done ? _cBlue : active ? _cBlue.withValues(alpha: 0.2) : _cCard,
              shape: BoxShape.circle,
              border: Border.all(color: (done || active) ? _cBlue : _cBorder, width: 1.5),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }

  // ── Body Router ───────────────────────────────────────────
  Widget _buildBody() {
    if (!_canCancel) return _buildCannotCancel();
    switch (_step) {
      case 0: return _buildReasonStep();
      case 1: return _buildRefundStep();
      case 2: return _buildConfirmStep();
      case 3: return _buildDoneStep();
      default: return const SizedBox();
    }
  }

  // ── Cannot Cancel ─────────────────────────────────────────
  Widget _buildCannotCancel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cRose.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _cRose.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.block_rounded, color: _cRose, size: 52),
          ),
          const SizedBox(height: 20),
          const Text('Cannot Cancel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            _orderStatus == 'delivered'
                ? 'This order has already been delivered.'
                : 'This order has already been cancelled.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.6),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Go Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── STEP 0: Reason ────────────────────────────────────────
  Widget _buildReasonStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Cashback preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cashbackColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cashbackColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.account_balance_wallet_rounded, color: _cashbackColor, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cashbackLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _cashbackColor)),
                  const SizedBox(height: 2),
                  Text(_cashbackReason, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '₹${_cashbackAmount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _cashbackColor),
                ),
                Text(
                  'of ₹${_orderTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 24),
          const Text('Reason for Cancellation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          const SizedBox(height: 10),

          ..._reasons.map((r) {
            final selected = _selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = r),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? _cBlue.withValues(alpha: 0.1) : _cCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? _cBlue.withValues(alpha: 0.5) : _cBorder, width: selected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _cBlue : Colors.transparent,
                      border: Border.all(color: selected ? _cBlue : const Color(0xFF334155), width: 2),
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 12) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF94A3B8)))),
                ]),
              ),
            );
          }),

          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _otherReasonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Please describe your reason...',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                filled: true, fillColor: _cCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cBlueSoft, width: 1.5)),
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── STEP 1: Refund Method ─────────────────────────────────
  Widget _buildRefundStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _bankFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const Text('Refund Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          const SizedBox(height: 10),

          // Method selector
          ...[
            {'id': 'wallet', 'label': 'Laundrify Wallet', 'sub': 'Instant — No details needed', 'icon': Icons.account_balance_wallet_rounded, 'color': _cGreen},
            {'id': 'upi', 'label': 'UPI Transfer', 'sub': 'Within 24 hours', 'icon': Icons.phone_android_rounded, 'color': _cBlueSoft},
            {'id': 'bank', 'label': 'Bank Transfer (NEFT)', 'sub': '3–5 working days', 'icon': Icons.account_balance_rounded, 'color': _cAmber},
          ].map((m) {
            final selected = _refundMethod == m['id'];
            final color = m['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _refundMethod = m['id'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.1) : _cCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? color.withValues(alpha: 0.5) : _cBorder, width: selected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(m['icon'] as IconData, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xFF94A3B8))),
                      Text(m['sub'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ],
                  )),
                  if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
                ]),
              ),
            );
          }),

          const SizedBox(height: 20),

          // UPI field
          if (_refundMethod == 'upi') ...[
            const Text('UPI Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            _buildField(controller: _upiCtrl, label: 'UPI ID', hint: 'yourname@upi', icon: Icons.phone_android_rounded),
            const SizedBox(height: 8),
            _infoBox('Enter your UPI ID (e.g. 9876543210@okaxis). The refund will be processed within 24 hours.', _cBlueSoft),
          ],

          // Bank fields
          if (_refundMethod == 'bank') ...[
            const Text('Bank Account Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            _buildField(controller: _accountNameCtrl, label: 'Account Holder Name', hint: 'Full name as in bank', icon: Icons.person_rounded, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            _buildField(controller: _bankNameCtrl, label: 'Bank Name', hint: 'e.g. State Bank of India', icon: Icons.account_balance_rounded, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            _buildField(
              controller: _accountNumberCtrl,
              label: 'Account Number',
              hint: 'Enter account number',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 9) return 'Account number too short';
                return null;
              },
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: _confirmAccountCtrl,
              label: 'Confirm Account Number',
              hint: 'Re-enter account number',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v != _accountNumberCtrl.text) return 'Account numbers do not match';
                return null;
              },
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: _ifscCtrl,
              label: 'IFSC Code',
              hint: 'e.g. SBIN0001234',
              icon: Icons.tag_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) {
                  return 'Invalid IFSC code format';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _infoBox('Bank transfers take 3–5 working days. Ensure all details are correct. Incorrect details may delay or fail the refund.', _cAmber),
          ],

          if (_refundMethod == 'wallet')
            _infoBox('₹${_cashbackAmount.toStringAsFixed(0)} will be added to your Laundrify Wallet instantly after cancellation.', _cGreen),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Review & Confirm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── STEP 2: Confirm ───────────────────────────────────────
  Widget _buildConfirmStep() {
    final reason = _selectedReason == 'Other' ? _otherReasonCtrl.text.trim() : _selectedReason!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),

        // Warning
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cRose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cRose.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: _cRose, size: 22),
            SizedBox(width: 12),
            Expanded(child: Text('This action is irreversible. Once cancelled, the order cannot be restored.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5))),
          ]),
        ),

        const SizedBox(height: 20),
        const Text('Order Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
        _summaryRow('Order ID', '#${widget.orderId.substring(0, 8).toUpperCase()}'),
        _summaryRow('Order Total', '₹${_orderTotal.toStringAsFixed(2)}'),
        _summaryRow('Current Status', _orderStatus.toUpperCase()),
        _summaryRow('Cancellation Reason', reason),

        const SizedBox(height: 16),
        const Text('Cashback Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cashbackColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cashbackColor.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Cashback Amount', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              Text('₹${_cashbackAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _cashbackColor)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Refund Method', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              Text(
                _refundMethod == 'wallet' ? 'Laundrify Wallet' : _refundMethod == 'upi' ? 'UPI Transfer' : 'Bank Transfer',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ]),
            if (_refundMethod == 'upi') ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('UPI ID', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                Text(_upiCtrl.text.trim(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ],
            if (_refundMethod == 'bank') ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Account', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                Text('****${_accountNumberCtrl.text.trim().length > 4 ? _accountNumberCtrl.text.trim().substring(_accountNumberCtrl.text.trim().length - 4) : _accountNumberCtrl.text.trim()}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('IFSC', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                Text(_ifscCtrl.text.trim().toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ],
          ]),
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _confirmCancellation,
            style: ElevatedButton.styleFrom(
              backgroundColor: _cRose,
              disabledBackgroundColor: _cRose.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isProcessing
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Confirm Cancellation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── STEP 3: Done ──────────────────────────────────────────
  Widget _buildDoneStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _cashbackColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _cashbackColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(Icons.check_circle_rounded, color: _cashbackColor, size: 64),
          ),
          const SizedBox(height: 24),
          const Text('Order Cancelled', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 10),
          if (_cashbackAmount > 0) ...[
            Text(
              '₹${_cashbackAmount.toStringAsFixed(0)} cashback initiated',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _cashbackColor),
            ),
            const SizedBox(height: 6),
            Text(
              _refundMethod == 'wallet'
                  ? 'Added to your Laundrify Wallet instantly.'
                  : _refundMethod == 'upi'
                      ? 'UPI transfer will be completed within 24 hours.'
                      : 'Bank transfer will be completed in 3–5 working days.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.6),
            ),
          ] else
            const Text(
              'No refund applicable for this stage of the order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.6),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _cBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back to Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 18),
          filled: true, fillColor: _cCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cBlueSoft, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cRose)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cRose, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
      ]),
    );
  }

  Widget _infoBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.5))),
      ]),
    );
  }
}
