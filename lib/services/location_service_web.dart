// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

class LocationResult {
  final String? address;
  final double? lat;
  final double? lng;
  final String? error;
  const LocationResult({this.address, this.lat, this.lng, this.error});
  bool get success => address != null && error == null;
}

Future<LocationResult> getLocation() async {
  try {
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 15),
    );
    final lat = pos.coords!.latitude!.toDouble();
    final lng = pos.coords!.longitude!.toDouble();
    final address = await _reverseGeocode(lat, lng);
    return LocationResult(address: address, lat: lat, lng: lng);
  } catch (e) {
    if (e is html.PositionError) {
      String msg;
      switch (e.code) {
        case 1: msg = 'permission_denied'; break;
        case 2: msg = 'Location unavailable. Try again.'; break;
        case 3: msg = 'Location request timed out.'; break;
        default: msg = 'Unknown location error.';
      }
      return LocationResult(error: msg);
    }
    return const LocationResult(error: 'Location request timed out.');
  }
}

// Simple reverse geocoding via nominatim (no API key needed)
Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16&addressdetails=1');
    final xhr = html.HttpRequest();
    xhr.open('GET', uri.toString());
    xhr.setRequestHeader('Accept', 'application/json');
    final completer = Completer<String>();
    xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        final data = xhr.responseText ?? '';
        // Parse display_name from JSON response
        final match = RegExp(r'"display_name"\s*:\s*"([^"]+)"').firstMatch(data);
        completer.complete(match?.group(1) ?? 'Location detected ($lat, $lng)');
      } else {
        completer.complete('Location detected');
      }
    });
    xhr.onError.listen((_) => completer.complete('Location detected'));
    xhr.send();
    return completer.future.timeout(const Duration(seconds: 5),
        onTimeout: () => 'Location detected ($lat, $lng)');
  } catch (_) {
    return 'Location detected ($lat, $lng)';
  }
}

Future<void> openLocationSettings() async {
  // No-op on web — browser handles location permissions
}

Future<void> openAppSettings() async {
  // No-op on web
}

Future<String> requestNotificationPermission() async {
  // Web notification permission via browser
  try {
    final result = await html.Notification.requestPermission();
    return result;
  } catch (_) {
    return 'denied';
  }
}
