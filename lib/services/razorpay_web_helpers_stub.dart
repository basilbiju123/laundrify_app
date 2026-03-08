// Mobile stub — these functions are never called on mobile (kIsWeb guard)
// but must exist for the compiler to resolve symbols in payment_page.dart

import 'dart:async';

Future<void> loadRazorpayScript() async {}

Future<void> launchRazorpayWeb({
  required String key,
  required int amount,
  required String name,
  required String description,
  required String email,
  required void Function(String paymentId) onSuccess,
  required void Function(String error) onFailure,
}) async {
  onFailure('Web checkout not available on mobile');
}
