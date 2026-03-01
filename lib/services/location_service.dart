// location_service.dart
// Unified location service: web uses browser Geolocation API,
// mobile/desktop uses geolocator + geocoding + permission_handler.

export 'location_service_mobile.dart'
    if (dart.library.html) 'location_service_web.dart'
    show LocationResult, getLocation, openLocationSettings,
         requestNotificationPermission, openAppSettings;
