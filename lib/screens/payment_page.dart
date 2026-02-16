import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/firestore_service.dart';
import '../services/cart_service.dart';

const _pNavy = Color(0xFF080F1E);
const _pNavyMid = Color(0xFF0D1F3C);
const _pBlue = Color(0xFF1B4FD8);
const _pGold = Color(0xFFF5C518);
const _pGreen = Color(0xFF10B981);
const _pRed = Color(0xFFEF4444);
const _pSurface = Color(0xFFF0F4FF);
const _pDark = Color(0xFF0A1628);
const _pMid = Color(0xFF475569);
const _pFade = Color(0xFF94A3B8);

class PaymentPage extends StatefulWidget {
  final String orderId;
  final String orderDate;
  final String orderTime;
  final List<Map<String, dynamic>> services;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final double total;
  final String pickupDate;
  final String pickupTime;
  final String deliveryDate;
  final String deliveryTime;
  final String address;
  final String addressLabel;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.orderDate,
    required this.orderTime,
    required this.services,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.total,
    required this.pickupDate,
    required this.pickupTime,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.address,
    required this.addressLabel,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;
  String selectedPaymentMethod = "UPI"; // Default selection
  bool isProcessing = false;

  final List<Map<String, dynamic>> paymentMethods = [
    {
      'id': 'UPI',
      'name': 'UPI Payment',
      'icon': Icons.account_balance_wallet_rounded,
      'subtitle': 'Google Pay, PhonePe, Paytm',
      'color': Color(0xFF6C63FF),
    },
    {
      'id': 'Card',
      'name': 'Credit/Debit Card',
      'icon': Icons.credit_card_rounded,
      'subtitle': 'Visa, MasterCard, RuPay',
      'color': Color(0xFFFF6B6B),
    },
    {
      'id': 'NetBanking',
      'name': 'Net Banking',
      'icon': Icons.account_balance_rounded,
      'subtitle': 'All major banks',
      'color': Color(0xFF4ECDC4),
    },
    {
      'id': 'Wallet',
      'name': 'Digital Wallet',
      'icon': Icons.wallet_rounded,
      'subtitle': 'Paytm, PhonePe, Amazon Pay',
      'color': Color(0xFFFFA726),
    },
    {
      'id': 'COD',
      'name': 'Cash on Delivery',
      'icon': Icons.payments_outlined,
      'subtitle': 'Pay when your order arrives',
      'color': Color(0xFF059669),
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Save to abandoned cart immediately when payment page is opened
    _saveToAbandonedCart();
  }

  Future<void> _saveToAbandonedCart() async {
    try {
      await CartService().saveAbandonedCart(
        orderId: widget.orderId,
        services: widget.services,
        subtotal: widget.subtotal,
        deliveryFee: widget.deliveryFee,
        gst: widget.gst,
        total: widget.total,
        pickupDate: widget.pickupDate,
        pickupTime: widget.pickupTime,
        deliveryDate: widget.deliveryDate,
        deliveryTime: widget.deliveryTime,
        address: widget.address,
        addressLabel: widget.addressLabel,
      );
    } catch (_) {
      // Fail silently
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() => isProcessing = false);
    // Payment successful
    _showSuccessSheet(response.paymentId ?? '');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Payment failed: ${response.message ?? "Unknown error"}')),
        ]),
        backgroundColor: _pRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet: ${response.walletName}'),
        backgroundColor: _pGreen,
      ),
    );
  }

  void _processPayment() {
    // Handle COD separately — no Razorpay needed
    if (selectedPaymentMethod == 'COD') {
      _handleCodPayment();
      return;
    }

    setState(() => isProcessing = true);

    // Razorpay payment options
    var options = {
      'key': 'YOUR_RAZORPAY_KEY_HERE', // Replace with your Razorpay key
      'amount': (widget.total * 100).toInt(), // Amount in paise
      'name': 'Laundrify',
      'description': 'Order ${widget.orderId}',
      'order_id': widget.orderId,
      'prefill': {
        'contact': '9876543210', // Get from user profile
        'email': 'user@example.com' // Get from user profile
      },
      'theme': {
        'color': '#080F1E',
      }
    };

    // Set payment method preference
    if (selectedPaymentMethod == 'UPI') {
      options['method'] = 'upi';
    } else if (selectedPaymentMethod == 'Card') {
      options['method'] = 'card';
    } else if (selectedPaymentMethod == 'NetBanking') {
      options['method'] = 'netbanking';
    } else if (selectedPaymentMethod == 'Wallet') {
      options['method'] = 'wallet';
    }
    // COD is handled separately above

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _pRed,
        ),
      );
    }
  }

  void _handleCodPayment() {
    setState(() => isProcessing = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => isProcessing = false);
      _showSuccessSheet('COD-${widget.orderId}');
    });
  }

  void _showSuccessSheet(String paymentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PaymentSuccessSheet(
        orderId: widget.orderId,
        orderDate: widget.orderDate,
        orderTime: widget.orderTime,
        services: widget.services,
        subtotal: widget.subtotal,
        deliveryFee: widget.deliveryFee,
        gst: widget.gst,
        total: widget.total,
        pickupDate: widget.pickupDate,
        pickupTime: widget.pickupTime,
        deliveryDate: widget.deliveryDate,
        deliveryTime: widget.deliveryTime,
        address: widget.address,
        addressLabel: widget.addressLabel,
        paymentMethod: selectedPaymentMethod,
        paymentId: paymentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_pNavy, _pNavyMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))),
        title: const Text("Secure Payment",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: Stack(children: [
        // Gradient header background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 280,
          child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_pNavy, _pNavyMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight))),
        ),

        Column(children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 60),

          // HUGE AMOUNT DISPLAY CARD
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  _pGold.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: _pGold.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                    color: _pGold.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Column(children: [
              const Text("Amount to Pay",
                  style: TextStyle(
                      fontSize: 15,
                      color: _pMid,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              // MASSIVE AMOUNT
              Text("₹${widget.total.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: _pNavy,
                      height: 1.1,
                      letterSpacing: -2)),
              const SizedBox(height: 4),
              Text(
                  ".${(widget.total % 1 * 100).toStringAsFixed(0).padLeft(2, '0')}",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _pMid.withValues(alpha: 0.6))),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: _pNavy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.shield_rounded, color: _pGreen, size: 16),
                  const SizedBox(width: 8),
                  const Text("100% Secure Payment",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _pDark)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // Payment methods section
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _pSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                child: Column(children: [
                  // Section header
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _pBlue,
                              _pBlue.withValues(alpha: 0.7)
                            ]),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.payment_rounded,
                            color: Colors.white, size: 20)),
                    const SizedBox(width: 12),
                    const Text("Choose Payment Method",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _pDark)),
                  ]),

                  const SizedBox(height: 20),

                  // Payment method cards
                  ...paymentMethods.map((method) {
                    final isSelected = selectedPaymentMethod == method['id'];
                    final color = method['color'] as Color;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedPaymentMethod = method['id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected
                                  ? color
                                  : Colors.grey.withValues(alpha: 0.15),
                              width: isSelected ? 2.5 : 1),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8))
                                ]
                              : [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                        ),
                        child: Row(children: [
                          // Icon container
                          Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: isSelected
                                          ? [
                                              color,
                                              color.withValues(alpha: 0.7)
                                            ]
                                          : [
                                              Colors.grey.shade100,
                                              Colors.grey.shade50
                                            ]),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Icon(method['icon'],
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                  size: 28)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(method['name'],
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? color : _pDark)),
                                const SizedBox(height: 4),
                                Text(method['subtitle'],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected
                                            ? color.withValues(alpha: 0.8)
                                            : _pFade,
                                        fontWeight: FontWeight.w500)),
                              ])),
                          // Checkmark
                          AnimatedScale(
                            scale: isSelected ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 20)),
                          ),
                        ]),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Security badges
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                              _pGreen.withValues(alpha: 0.08),
                              _pGreen.withValues(alpha: 0.03)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: _pGreen.withValues(alpha: 0.2))),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _securityBadge(Icons.lock_rounded, "256-bit\nSSL"),
                            _securityBadge(Icons.verified_user_rounded,
                                "PCI DSS\nCompliant"),
                            _securityBadge(
                                Icons.security_rounded, "Bank-level\nSecurity"),
                          ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),

        // Bottom payment button - FIXED POSITION
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.95)
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, -10))
                ]),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _pNavy,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: _pNavy.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                child: isProcessing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: _pGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.lock_rounded,
                                    color: _pGold, size: 20)),
                            const SizedBox(width: 14),
                            Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "Pay ₹${widget.total.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          letterSpacing: 0.5)),
                                  const Text("Secure Payment",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70)),
                                ]),
                          ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _securityBadge(IconData icon, String text) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _pGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: _pGreen, size: 24)),
      const SizedBox(height: 8),
      Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _pDark)),
    ]);
  }
}

// Payment Success Sheet (same as before but with paymentId)
class _PaymentSuccessSheet extends StatefulWidget {
  final String orderId;
  final String orderDate;
  final String orderTime;
  final List<Map<String, dynamic>> services;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final double total;
  final String pickupDate;
  final String pickupTime;
  final String deliveryDate;
  final String deliveryTime;
  final String address;
  final String addressLabel;
  final String paymentMethod;
  final String paymentId;

  const _PaymentSuccessSheet({
    required this.orderId,
    required this.orderDate,
    required this.orderTime,
    required this.services,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.total,
    required this.pickupDate,
    required this.pickupTime,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.address,
    required this.addressLabel,
    required this.paymentMethod,
    required this.paymentId,
  });

  @override
  State<_PaymentSuccessSheet> createState() => _PaymentSuccessSheetState();
}

class _PaymentSuccessSheetState extends State<_PaymentSuccessSheet> {
  @override
  void initState() {
    super.initState();
    _saveOrderAndNotify();
  }

  Future<void> _saveOrderAndNotify() async {
    try {
      final firestoreService = FirestoreService();
      final cartService = CartService();

      final orderData = {
        'orderId': widget.orderId,
        'orderDate': widget.orderDate,
        'orderTime': widget.orderTime,
        'paymentMethod': widget.paymentMethod,
        'paymentId': widget.paymentId,
        'services': widget.services,
        'subtotal': widget.subtotal,
        'deliveryFee': widget.deliveryFee,
        'gst': widget.gst,
        'total': widget.total,
        'pickupDate': widget.pickupDate,
        'pickupTime': widget.pickupTime,
        'deliveryDate': widget.deliveryDate,
        'deliveryTime': widget.deliveryTime,
        'address': widget.address,
        'addressLabel': widget.addressLabel,
        'status': 'confirmed',
      };

      await firestoreService.saveOrder(orderData);
      await firestoreService.sendBookingSuccessNotification(
          widget.orderId, widget.total);

      // Convert abandoned cart to order
      await cartService.convertCartToOrder(widget.orderId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
          color: _pSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(children: [
        Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              // Success animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _pGreen.withValues(alpha: 0.15),
                      _pGreen.withValues(alpha: 0.05)
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _pGreen.withValues(alpha: 0.3), width: 3)),
                child:
                    const Icon(Icons.check_rounded, color: _pGreen, size: 50),
              ),

              const SizedBox(height: 20),

              const Text("Payment Successful!",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _pDark)),
              const SizedBox(height: 8),
              Text("Your order has been confirmed",
                  style: TextStyle(
                      fontSize: 14, color: _pMid.withValues(alpha: 0.8))),

              const SizedBox(height: 24),

              // Order ID & Payment ID
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_pNavy, _pNavyMid],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: _pNavy.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ]),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Order ID",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: _pGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text("PAID",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _pGold))),
                      ]),
                  const SizedBox(height: 8),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.orderId,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1)),
                      ]),
                  const SizedBox(height: 12),
                  Container(
                      height: 1, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text("Payment ID: ",
                        style: TextStyle(fontSize: 11, color: Colors.white54)),
                    Expanded(
                        child: Text(widget.paymentId,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600))),
                  ]),
                ]),
              ),

              const SizedBox(height: 20),

              // Bill summary (simplified)
              _infoCard(
                "Payment Summary",
                Icons.receipt_long_rounded,
                [
                  _billRow("Total Paid", "₹${widget.total.toStringAsFixed(2)}"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _pGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _pGreen, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text("Paid via $widget.paymentMethod",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _pGreen,
                                  fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // Done button
        Container(
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ]),
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _pNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18))),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("DONE · BACK TO HOME",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                const SizedBox(width: 10),
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: _pGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.home_rounded,
                        color: _pGold, size: 16)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: _pNavy.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: _pNavy, size: 16)),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: _pDark)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _billRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: _pDark)),
      Text(value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: _pNavy)),
    ]);
  }
}
