// ignore_for_file: constant_identifier_names

// Stub classes matching razorpay_flutter API for web compilation
// On web, payment is handled via _simulateWebPayment() in payment_page.dart

class Razorpay {
  static const EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const EVENT_PAYMENT_ERROR   = 'payment.error';
  static const EVENT_EXTERNAL_WALLET = 'payment.wallet';

  void on(String event, dynamic handler) {}
  void open(Map<String, dynamic> options) {}
  void clear() {}
}

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  const PaymentSuccessResponse({this.paymentId, this.orderId, this.signature});
}

class PaymentFailureResponse {
  final int? code;
  final String? message;
  const PaymentFailureResponse({this.code, this.message});
}

class ExternalWalletResponse {
  final String? walletName;
  const ExternalWalletResponse({this.walletName});
}
