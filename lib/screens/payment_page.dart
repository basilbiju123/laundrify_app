import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard.dart';

// Razorpay is supported on Android/iOS only.
// On Web we use a simulated checkout UI (redirect to Razorpay Standard Checkout).
// To enable real Razorpay on Android/iOS: replace YOUR_RAZORPAY_TEST_KEY below.
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) '../services/razorpay_web_stub.dart';

// ════════════════════════════════════════════════════════════
// PAYMENT PAGE — Online (UPI / Card / NetBanking) + COD
// Android/iOS: Razorpay native SDK
// Web: Simulated checkout (same UX, order saved to Firestore)
// ════════════════════════════════════════════════════════════

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final int totalItems;
  final List<Map<String, dynamic>> services;
  final String pickupDate;
  final String pickupTime;
  final String deliveryDate;
  final String deliveryTime;
  final String paymentMethod;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.totalItems,
    required this.services,
    required this.pickupDate,
    required this.pickupTime,
    this.deliveryDate = '',
    this.deliveryTime = '',
    required this.paymentMethod,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg   = Color(0xFFF0F4FF);

  bool _isProcessing = false;
  bool _paymentDone  = false;
  String? _orderId;
  String _onlineOption = 'upi';

  // Razorpay (Android/iOS only)
  Razorpay? _razorpay;
  static const _razorpayTestKey = 'rzp_test_XXXXXXXXXXXXXXXX';

  final _upiCtrl        = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl    = TextEditingController();
  final _cardNameCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR,   _handleRazorpayError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _upiCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardNameCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => widget.services.fold(0.0, (t, svc) {
    final items = (svc['items'] as List?) ?? [];
    return t + items.fold(0.0, (s, i) {
      final m = i as Map;
      return s + ((m['qty'] ?? 0) as num) * ((m['price'] ?? 0) as num);
    });
  });

  @override
  Widget build(BuildContext context) {
    if (_paymentDone) return _successScreen();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          widget.paymentMethod == 'cod' ? 'Confirm Order' : 'Payment',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _orderSummaryCard(),
            const SizedBox(height: 20),
            if (widget.paymentMethod == 'online') _onlineSection(),
            if (widget.paymentMethod == 'cod')    _codSection(),
            const SizedBox(height: 32),
            _payButton(),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.security_rounded, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Text('Payments are 100% secure & encrypted',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _orderSummaryCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Order Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 14),
      ...widget.services.map((svc) {
        final items = ((svc['items'] as List?) ?? []).where((i) => ((i as Map)['qty'] ?? 0) > 0).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(svc['title'] ?? svc['serviceName'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          Text('${items.length} items', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ]));
      }),
      const Divider(height: 20),
      _billRow('Subtotal', _subtotal),
      _billRow('Delivery Fee', 40.0),
      _billRow('GST (18%)', _subtotal * 0.18),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _navy)),
        Text('₹${widget.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _navy)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: Color(0xFF1B4FD8), size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text('Pickup: ${widget.pickupDate} at ${widget.pickupTime}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B4FD8)))),
        ]),
      ),
    ]),
  );

  Widget _billRow(String label, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      Text('₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
    ]),
  );

  Widget _onlineSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
    const SizedBox(height: 14),
    Row(children: [
      _optionTab('upi',        'UPI',         Icons.account_balance_wallet_rounded),
      const SizedBox(width: 10),
      _optionTab('card',       'Card',        Icons.credit_card_rounded),
      const SizedBox(width: 10),
      _optionTab('netbanking', 'Net Banking', Icons.account_balance_rounded),
    ]),
    const SizedBox(height: 16),
    if (_onlineOption == 'upi')        _upiForm(),
    if (_onlineOption == 'card')       _cardForm(),
    if (_onlineOption == 'netbanking') _netBankingInfo(),
  ]);

  Widget _optionTab(String value, String label, IconData icon) {
    final active = _onlineOption == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _onlineOption = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _gold.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _gold : const Color(0xFFE8EDF5), width: active ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: active ? const Color(0xFF92700A) : const Color(0xFF94A3B8), size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: active ? _navy : const Color(0xFF94A3B8))),
          ]),
        ),
      ),
    );
  }

  Widget _upiForm() => Container(
    padding: const EdgeInsets.all(18), decoration: _cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Enter UPI ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 10),
      TextField(controller: _upiCtrl, decoration: _inputDeco('yourname@upi', Icons.alternate_email_rounded)),
      const SizedBox(height: 14),
      const Text('Popular UPI Apps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      const SizedBox(height: 10),
      Wrap(spacing: 10, children: ['GPay', 'PhonePe', 'Paytm', 'BHIM'].map((app) {
        return GestureDetector(
          onTap: () {
            _upiCtrl.text = app == 'GPay' ? 'yourname@okicici'
                : app == 'PhonePe' ? 'yourname@ybl'
                : app == 'Paytm'   ? 'yourname@paytm' : 'yourname@upi';
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8EDF5))),
            child: Text(app, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B4FD8))),
          ),
        );
      }).toList()),
    ]),
  );

  Widget _cardForm() => Container(
    padding: const EdgeInsets.all(18), decoration: _cardDeco(),
    child: Column(children: [
      TextField(controller: _cardNameCtrl, decoration: _inputDeco('Cardholder Name', Icons.person_outline_rounded)),
      const SizedBox(height: 12),
      TextField(
        controller: _cardNumberCtrl, keyboardType: TextInputType.number, maxLength: 19,
        decoration: _inputDeco('Card Number', Icons.credit_card_rounded, counter: false),
        onChanged: (v) {
          final digits = v.replaceAll(' ', '');
          final buf = StringBuffer();
          for (int i = 0; i < digits.length; i++) {
            if (i > 0 && i % 4 == 0) buf.write(' ');
            buf.write(digits[i]);
          }
          if (buf.toString() != v) {
            _cardNumberCtrl.value = TextEditingValue(
                text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
          }
        },
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _cardExpiryCtrl, keyboardType: TextInputType.number,
            maxLength: 5, decoration: _inputDeco('MM/YY', Icons.date_range_rounded, counter: false))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _cardCvvCtrl, keyboardType: TextInputType.number,
            maxLength: 3, obscureText: true, decoration: _inputDeco('CVV', Icons.lock_outline_rounded, counter: false))),
      ]),
    ]),
  );

  Widget _netBankingInfo() => Container(
    padding: const EdgeInsets.all(20), decoration: _cardDeco(),
    child: Column(children: [
      const Icon(Icons.account_balance_rounded, color: Color(0xFF1B4FD8), size: 40),
      const SizedBox(height: 12),
      const Text('Net Banking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      const Text('You will be redirected to your bank\'s secure payment gateway.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: ['SBI', 'HDFC', 'ICICI', 'Axis', 'Kotak', 'PNB'].map((b) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8EDF5))),
              child: Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
            );
          }).toList()),
    ]),
  );

  Widget _codSection() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD1FAE5)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
          child: const Icon(Icons.money_rounded, color: Color(0xFF10B981), size: 36)),
      const SizedBox(height: 16),
      const Text('Cash on Delivery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 8),
      const Text('Pay with cash when your clothes are delivered back to you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(children: const [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Exact change appreciated. Delivery agent carries limited change.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4))),
        ]),
      ),
    ]),
  );

  Widget _payButton() => SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _navy, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
      ),
      onPressed: _isProcessing ? null : _processPayment,
      child: _isProcessing
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.paymentMethod == 'cod' ? Icons.check_circle_rounded : Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.paymentMethod == 'cod' ? 'CONFIRM ORDER' : 'PAY ₹${widget.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ]),
    ),
  );

  Widget _successScreen() => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 100, height: 100,
                decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 60)),
            const SizedBox(height: 24),
            const Text('Order Placed!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _navy)),
            const SizedBox(height: 12),
            Text(
              widget.paymentMethod == 'cod'
                  ? 'Your order has been confirmed.\nPay cash on delivery.'
                  : 'Payment successful!\nYour order is confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 16),
            if (_orderId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)),
                child: Text('Order ID: #${_orderId!.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
              ),
            const SizedBox(height: 36),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const DashboardPage()), (r) => false),
                child: const Text('GO TO HOME',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
            ),
          ],
        )),
      ),
    ),
  );

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );

  InputDecoration _inputDeco(String hint, IconData icon, {bool counter = true}) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EDF5))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EDF5))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold, width: 1.5)),
    filled: true, fillColor: const Color(0xFFF8FAFF), isDense: true, counterText: counter ? null : '',
  );

  // ── Razorpay Handlers (Android/iOS only) ──────────────────────
  void _handleRazorpaySuccess(PaymentSuccessResponse response) {
    _writeOrderToFirestore(
      razorpayPaymentId: response.paymentId,
      razorpayOrderId:   response.orderId,
      razorpaySignature: response.signature,
    );
  }

  void _handleRazorpayError(PaymentFailureResponse response) async {
    if (mounted) {
      setState(() => _isProcessing = false);
      _snack('Payment failed: ${response.message ?? "Please try again"}');
      await _saveAbandonedCart();
    }
  }

  void _handleRazorpayWallet(ExternalWalletResponse response) {
    if (mounted) _snack('Processing via ${response.walletName}...');
  }

  // ── Core payment entry ─────────────────────────────────────────
  Future<void> _processPayment() async {
    // COD — write order directly
    if (widget.paymentMethod == 'cod') {
      setState(() => _isProcessing = true);
      await _writeOrderToFirestore();
      return;
    }

    // Validate fields
    if (_onlineOption == 'upi' && _upiCtrl.text.trim().isEmpty) {
      _snack('Please enter your UPI ID'); return;
    }
    if (_onlineOption == 'card') {
      if (_cardNumberCtrl.text.replaceAll(' ', '').length < 16) { _snack('Please enter a valid 16-digit card number'); return; }
      if (_cardExpiryCtrl.text.length < 5) { _snack('Please enter card expiry (MM/YY)'); return; }
      if (_cardCvvCtrl.text.length < 3)    { _snack('Please enter CVV'); return; }
    }

    setState(() => _isProcessing = true);

    if (kIsWeb) {
      // Web: simulate payment (show processing → write order)
      // In production: integrate Razorpay Standard Checkout JS SDK
      await _simulateWebPayment();
    } else {
      // Mobile: use Razorpay native SDK
      _openRazorpay();
    }
  }

  Future<void> _simulateWebPayment() async {
    // Show a simulated "processing" state for 1.5 seconds then complete
    // In production replace this with Razorpay Standard Checkout JS:
    // https://razorpay.com/docs/payment-gateway/web-integration/standard/
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _writeOrderToFirestore(razorpayPaymentId: 'web_sim_${DateTime.now().millisecondsSinceEpoch}');
  }

  void _openRazorpay() {
    final user = FirebaseAuth.instance.currentUser;
    final options = <String, dynamic>{
      'key': _razorpayTestKey,
      'amount': (widget.totalAmount * 100).toInt(),
      'name': 'Laundrify',
      'description': 'Laundry Service - ${widget.totalItems} items',
      'currency': 'INR',
      'prefill': {'contact': '', 'email': user?.email ?? ''},
      if (_onlineOption == 'upi')        'method': {'upi': true,  'card': false, 'netbanking': false, 'wallet': false},
      if (_onlineOption == 'card')       'method': {'upi': false, 'card': true,  'netbanking': false, 'wallet': false},
      if (_onlineOption == 'netbanking') 'method': {'upi': false, 'card': false, 'netbanking': true,  'wallet': false},
      'theme': {'color': '#080F1E'},
      'modal': {'backdropclose': false},
    };
    try {
      _razorpay!.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      _snack('Unable to open payment. Please try again.');
    }
  }

  Future<void> _writeOrderToFirestore({
    String? razorpayPaymentId, String? razorpayOrderId, String? razorpaySignature,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final db = FirebaseFirestore.instance;

      final items = <Map<String, dynamic>>[];
      for (final svc in widget.services) {
        for (final item in ((svc['items'] as List?) ?? [])) {
          final m = item as Map;
          if ((m['qty'] ?? 0) > 0) {
            items.add({'itemName': m['name'] ?? '', 'serviceName': svc['title'] ?? svc['serviceName'] ?? '',
                'quantity': m['qty'] ?? 1, 'price': m['price'] ?? 0});
          }
        }
      }

      final docRef = await db.collection('orders').add({
        'userId': user.uid, 'customerName': user.displayName ?? '',
        'customerEmail': user.email ?? '', 'items': items,
        'totalAmount': widget.totalAmount, 'totalItems': widget.totalItems,
        'status': 'pending', 'paymentMethod': widget.paymentMethod,
        'paymentStatus': widget.paymentMethod == 'cod' ? 'pending' : 'paid',
        'pickupDate': widget.pickupDate, 'pickupTime': widget.pickupTime,
        if (widget.deliveryDate.isNotEmpty) 'deliveryDate': widget.deliveryDate,
        if (widget.deliveryTime.isNotEmpty) 'deliveryTime': widget.deliveryTime,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpayOrderId   != null) 'razorpayOrderId':   razorpayOrderId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': [{'status': 'pending', 'note': 'Order placed via ${widget.paymentMethod.toUpperCase()}'}],
      });

      final pts = (widget.totalAmount / 10).floor();
      await db.collection('users').doc(user.uid).update({
        'loyaltyPoints': FieldValue.increment(pts),
        'totalOrders':   FieldValue.increment(1),
        'totalSpent':    FieldValue.increment(widget.totalAmount),
      });
      await db.collection('users').doc(user.uid).collection('loyalty_history').add({
        'type': 'earn', 'points': pts,
        'description': 'Earned for order #${docRef.id.substring(0, 8).toUpperCase()}',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await db.collection('notifications').add({
        'title': 'Order Confirmed! 🎉',
        'message': 'Your order #${docRef.id.substring(0, 6).toUpperCase()} has been placed successfully.',
        'userId': user.uid, 'orderId': docRef.id, 'type': 'order_update',
        'createdAt': FieldValue.serverTimestamp(), 'isRead': false,
      });

      if (mounted) setState(() { _orderId = docRef.id; _paymentDone = true; _isProcessing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _snack('Order creation failed. Your cart has been saved.');
        await _saveAbandonedCart();
      }
    }
  }

  Future<void> _saveAbandonedCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .collection('abandoned_carts').add({
        'services': widget.services, 'totalAmount': widget.totalAmount,
        'totalItems': widget.totalItems, 'pickupDate': widget.pickupDate,
        'pickupTime': widget.pickupTime, 'paymentMethod': widget.paymentMethod,
        'status': 'abandoned', 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF0A1628),
  ));
}
