import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(error: 'gps_off');
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        return const LocationResult(error: 'permission_denied');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      return const LocationResult(error: 'permission_permanent');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    );
    final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    String address = 'Location detected';
    if (placemarks.isNotEmpty) {
      final p = placemarks[0];
      final parts = [
        if (p.street != null && p.street!.isNotEmpty) p.street!,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
        if (p.country != null && p.country!.isNotEmpty) p.country!,
      ];
      if (parts.isNotEmpty) address = parts.join(', ');
    }
    return LocationResult(address: address, lat: position.latitude, lng: position.longitude);
  } catch (e) {
    return LocationResult(error: e.toString());
  }
}

Future<void> openLocationSettings() => Geolocator.openLocationSettings();
Future<void> openAppSettings() => ph.openAppSettings();

Future<String> requestNotificationPermission() async {
  final status = await ph.Permission.notification.status;
  if (status.isDenied) {
    final result = await ph.Permission.notification.request();
    if (result.isGranted) return 'granted';
    if (result.isPermanentlyDenied) return 'permanent';
    return 'denied';
  }
  if (status.isGranted) return 'granted';
  return 'denied';
}
