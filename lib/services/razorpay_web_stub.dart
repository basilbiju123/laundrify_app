// ignore_for_file: constant_identifier_names
//
// razorpay_web_stub.dart
//
// TWO roles in one file:
//   1. Stub classes (Razorpay, PaymentSuccessResponse, etc.) so the app
//      compiles on web without the razorpay_flutter native SDK.
//   2. _launchRazorpayWeb() — opens the REAL Razorpay Standard Checkout
//      modal on web using the official JS SDK.
//
// Uses dart:js_interop + package:web (replaces deprecated dart:js / dart:html).

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

// ── Stub classes matching razorpay_flutter API ─────────────────────────────

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
  const PaymentFailureResponse({this.code, this.message});}

class ExternalWalletResponse {
  final String? walletName;
  const ExternalWalletResponse({this.walletName});
}

// ── Real Razorpay Standard Checkout for Web ────────────────────────────────

bool _scriptLoaded = false;

/// Injects the Razorpay checkout.js script once.
Future<void> loadRazorpayScript() async {
  if (_scriptLoaded) return;
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://checkout.razorpay.com/v1/checkout.js'
    ..type = 'text/javascript';
  script.onload = (web.Event _) {
    _scriptLoaded = true;
    if (!completer.isCompleted) completer.complete();
  }.toJS;
  script.onerror = (web.Event _) {
    if (!completer.isCompleted) completer.completeError('Script load failed');
  }.toJS;
  web.document.head!.append(script);
  return completer.future;
}

/// JS interop helpers — inline extension type for a plain JS object
@JS('Razorpay')
@staticInterop
class _RzpConstructor {
  external factory _RzpConstructor._(JSAny options);
}

extension _RzpExt on _RzpConstructor {
  external void open();
}

/// Opens Razorpay Standard Checkout on web.
/// [onSuccess] receives the razorpay_payment_id string.
/// [onFailure] receives an error description string.
Future<void> launchRazorpayWeb({
  required String key,
  required int amount,      // in paise (₹ × 100)
  required String name,
  required String description,
  required String email,
  required void Function(String paymentId) onSuccess,
  required void Function(String error) onFailure,
}) async {
  try {
    await loadRazorpayScript();
  } catch (e) {
    onFailure('Could not load payment gateway: $e');
    return;
  }

  final completer = Completer<void>();

  void handleSuccess(JSObject response) {
    // Use dartify to extract the payment ID from the JS response object
    final responseMap = response.dartify();
    final paymentId = (responseMap is Map ? responseMap['razorpay_payment_id'] as String? : null) ?? '';
    onSuccess(paymentId.isNotEmpty
        ? paymentId
        : 'web_rzp_${DateTime.now().millisecondsSinceEpoch}');
    if (!completer.isCompleted) completer.complete();
  }

  void handleDismiss() {
    onFailure('Payment cancelled');
    if (!completer.isCompleted) completer.complete();
  }

  // Build options using a Dart Map serialised to a JS object literal
  final optionsJs = <String, dynamic>{
    'key': key,
    'amount': amount,
    'currency': 'INR',
    'name': name,
    'description': description,
    'prefill': {'email': email, 'contact': ''},
    'theme': {'color': '#080F1E'},
    'modal': {'backdropclose': false, 'ondismiss': handleDismiss.toJS},
    'handler': handleSuccess.toJS,
  }.jsify()!;

  // Instantiate Razorpay and open
  // We call `new Razorpay(options)` via eval to avoid @JS constructor issues
  // when the script is loaded dynamically.
  try {
    final rzp = _createRazorpay(optionsJs);
    rzp.open();
  } catch (e) {
    onFailure('Failed to open payment gateway: $e');
    return;
  }

  return completer.future;
}

// Creates a Razorpay instance via its @staticInterop factory constructor.
_RzpConstructor _createRazorpay(JSAny options) => _RzpConstructor._(options);
