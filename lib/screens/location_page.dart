import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'dart:math' as math;
import 'dashboard.dart';
// Web uses browser Geolocation API via location_service.dart
// Mobile/desktop use geolocator + geocoding + permission_handler
import '../services/location_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage>
    with TickerProviderStateMixin {
  bool isLoadingLocation = false;
  bool isSaving = false;
  String? currentAddress;
  double? currentLat;
  double? currentLng;
  bool hasRequestedNotifications = false;

  final TextEditingController houseNumberController = TextEditingController();
  final TextEditingController detailedAddressController =
      TextEditingController();

  // Desktop-only manual address controllers
  final TextEditingController manualStreetController = TextEditingController();
  final TextEditingController manualCityController = TextEditingController();
  final TextEditingController manualPincodeController = TextEditingController();

  String _selectedAddressType = 'Home';

  late AnimationController _animationController;
  late AnimationController _floatController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  /// True when running on desktop (Windows/macOS/Linux) OR web.
  /// Both show manual address entry instead of GPS (GPS works on web too,
  /// but we show both options — GPS button + manual fallback).
  bool get _isDesktop {
    if (kIsWeb) return false;  // web gets GPS button (browser geolocation)
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// True when GPS button should be shown (mobile + web)
  bool get _showGPSButton => kIsWeb || !_isDesktop;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    // Request notification permission on all platforms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  @override
  void dispose() {
    houseNumberController.dispose();
    detailedAddressController.dispose();
    manualStreetController.dispose();
    manualCityController.dispose();
    manualPincodeController.dispose();
    _animationController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────
  // NOTIFICATION PERMISSION (mobile only)
  // ────────────────────────────────────────────────────
  Future<void> _requestNotificationPermission() async {
    if (hasRequestedNotifications) return;
    hasRequestedNotifications = true;
    final ok = await _showPermissionDialog(
      title: "Enable Notifications",
      message:
          "Stay updated on your order status and exclusive offers. Allow notifications to never miss an update!",
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFF42A5F5),
    );
    if (ok != true) return;

    final result = await requestNotificationPermission();
    if (result == 'granted') {
      _snack("Notifications enabled", isError: false);
    } else if (result == 'permanent') {
      _showSettingsDialog(
        title: "Notification Permission",
        message: "Please enable notifications in app settings.",
        onSettings: openAppSettings,
      );
    }
  }

  Future<bool?> _showPermissionDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F2027))),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF475569), height: 1.6)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("Not Now",
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: const Text("Allow",
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // GPS LOCATION (mobile only)
  // ────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      final location = await getLocation();
      if (!mounted) return;

      if (location.success) {
        setState(() {
          currentLat = location.lat;
          currentLng = location.lng;
          currentAddress = location.address ?? "Location detected";
        });
        _snack("Location detected successfully", isError: false);
        return;
      }

      switch (location.error) {
        case 'gps_off':
        _showGPSOffDialog();
          break;
        case 'permission_denied':
          _snack("Location permission denied", isError: true);
          break;
        case 'permission_permanent':
          _showSettingsDialog(
            title: "Location Permission",
            message:
                "Location permission is permanently denied. Please enable it in settings.",
            onSettings: openAppSettings,
          );
          break;
        default:
          final ok = await _showPermissionDialog(
          title: "Enable Location",
          message:
              "We need your location to provide accurate pickup and delivery services.",
          icon: Icons.location_on_rounded,
          color: const Color(0xFF10B981),
        );
          if (ok == true) {
            await _getCurrentLocation();
          }
          break;
      }
    } catch (e) {
      _snack("Failed to get location. Check your network connection.",
          isError: true);
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  void _showGPSOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_off_rounded,
                color: Color(0xFF42A5F5), size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Text('Turn On GPS',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F2027)))),
        ]),
        content: const Text(
          'GPS is turned off. Please enable location services.',
          style: TextStyle(
              fontSize: 15, color: Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2027),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog({
    required String title,
    required String message,
    required VoidCallback onSettings,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_rounded,
                color: Color(0xFFEF4444), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F2027)))),
        ]),
        content: Text(message,
            style: const TextStyle(
                fontSize: 15, color: Color(0xFF475569), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2027),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // MANUAL ADDRESS (Windows desktop)
  // ────────────────────────────────────────────────────
  void _confirmManualAddress() {
    final street = manualStreetController.text.trim();
    final city = manualCityController.text.trim();
    final pincode = manualPincodeController.text.trim();

    if (street.isEmpty || city.isEmpty) {
      _snack("Please enter street address and city", isError: true);
      return;
    }

    final full = [street, city, if (pincode.isNotEmpty) pincode].join(', ');
    setState(() {
      currentAddress = full;
      currentLat = 0.0; // placeholder for manual entry
      currentLng = 0.0;
    });
    _snack("Address confirmed!", isError: false);
  }

  // ────────────────────────────────────────────────────
  // SAVE TO FIRESTORE
  // ────────────────────────────────────────────────────
  Future<void> _saveUserDataWithLocation() async {
    if (currentAddress == null || currentAddress!.isEmpty) {
      _snack(
          _isDesktop
              ? "Please confirm your address first"
              : "Please get your location first",
          isError: true);
      return;
    }
    if (houseNumberController.text.trim().isEmpty) {
      _snack("Please enter house/flat number", isError: true);
      return;
    }

    setState(() => isSaving = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        user = FirebaseAuth.instance.currentUser;
      }
      if (user == null) {
        final anon = await FirebaseAuth.instance.signInAnonymously();
        user = anon.user;
      }
      if (user == null) {
        if (mounted) {
          setState(() => isSaving = false);
          _snack("Authentication error. Please login again.", isError: true);
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "uid": user.uid,
        "location": {
          "latitude": currentLat ?? 0.0,
          "longitude": currentLng ?? 0.0,
          "address": currentAddress ?? "",
          "houseNumber": houseNumberController.text.trim(),
          "detailedAddress": detailedAddressController.text.trim(),
          "addressType": _selectedAddressType,
          "isManualEntry": _isDesktop,
          "updatedAt": FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      _snack("Location saved successfully", isError: false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const DashboardPage()));
    } catch (e) {
      if (mounted) {
        _snack("Failed to save location. Please try again.", isError: true);
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364)
            ],
          ),
        ),
        child: Stack(children: [
          // Floating circles
          ...List.generate(5, (i) => AnimatedBuilder(
                animation: _floatController,
                builder: (_, __) {
                  final off =
                      math.sin((_floatController.value * 2 * math.pi) + i * 0.7) *
                          35;
                  return Positioned(
                    left: (i % 3) * (size.width / 3) +
                        (i.isEven ? off : -off),
                    top: (i ~/ 2) * (size.height / 3) + off * 2,
                    child: Opacity(
                      opacity: 0.06,
                      child: Container(
                        width: 100 + (i * 25).toDouble(),
                        height: 100 + (i * 25).toDouble(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2),
                        ),
                      ),
                    ),
                  );
                },
              )),

          SafeArea(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: isWide
                    ? _buildWideLayout(size)
                    : _buildNarrowLayout(size),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Wide (desktop/tablet) layout ───────────────────
  Widget _buildWideLayout(Size size) {
    return Row(children: [
      // Left branding
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _locationIcon(80),
                const SizedBox(height: 36),
                const Text('Set Your Location',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                const SizedBox(height: 14),
                _subtitleChip('Help us deliver to your doorstep'),
                const SizedBox(height: 36),
                _benefitsCard(),
              ],
            ),
          ),
        ),
      ),

      // Right card
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Column(children: [
              _mainCard(),
              const SizedBox(height: 20),
              _privacyNote(),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ── Narrow (phone) layout ──────────────────────────
  Widget _buildNarrowLayout(Size size) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        constraints: BoxConstraints(
          minHeight: size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 40),
          _locationIcon(60),
          const SizedBox(height: 28),
          const Text('Set Your Location',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 10),
          _subtitleChip('Help us deliver to your doorstep'),
          const SizedBox(height: 28),
          _mainCard(),
          const SizedBox(height: 20),
          _benefitsCard(),
          const SizedBox(height: 14),
          _privacyNote(),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _locationIcon(double size) {
    return Container(
      padding: EdgeInsets.all(size * 0.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
            blurRadius: 50,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(size * 0.3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: Icon(Icons.location_on_rounded, size: size, color: Colors.white),
      ),
    );
  }

  Widget _subtitleChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600)),
      );

  // ── Main white card ────────────────────────────────
  Widget _mainCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 50,
            offset: const Offset(0, 25),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── DESKTOP: Manual address entry ─────────────────
              if (_isDesktop) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.laptop_windows_outlined,
                        size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'GPS is unavailable on this desktop. Enter your address manually below.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w600,
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _textField(
                  controller: manualStreetController,
                  label: 'Street Address*',
                  icon: Icons.streetview_outlined,
                  hint: 'e.g., 42 MG Road, Near Central Mall',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: _textField(
                      controller: manualCityController,
                      label: 'City*',
                      icon: Icons.location_city_outlined,
                      hint: 'e.g., Thrissur',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _textField(
                      controller: manualPincodeController,
                      label: 'Pincode',
                      icon: Icons.pin_outlined,
                      hint: '680001',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _confirmManualAddress,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 20),
                    label: const Text('CONFIRM ADDRESS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F2027),
                      side: const BorderSide(
                          color: Color(0xFF0F2027), width: 2.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── MOBILE: GPS button ────────────────────────────
              if (_showGPSButton) ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: isLoadingLocation || isSaving
                        ? null
                        : _getCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F2027),
                      side: const BorderSide(
                          color: Color(0xFF0F2027), width: 2.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: isLoadingLocation
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0F2027)))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  currentAddress != null
                                      ? Icons.refresh_rounded
                                      : Icons.my_location_rounded,
                                  size: 22),
                              const SizedBox(width: 10),
                              Text(
                                currentAddress != null
                                    ? 'UPDATE LOCATION'
                                    : 'GET MY LOCATION',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Confirmed address banner ───────────────────────
              if (currentAddress != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDesktop
                                ? 'Address Confirmed'
                                : 'Location Detected',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentAddress!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0F2027),
                                fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Address type
                const Text('Save As',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2027))),
                const SizedBox(height: 12),
                Row(children: [
                  _addressTypeBtn('Home', Icons.home_rounded),
                  const SizedBox(width: 12),
                  _addressTypeBtn('Office', Icons.business_rounded),
                  const SizedBox(width: 12),
                  _addressTypeBtn('Other', Icons.location_city_rounded),
                ]),
                const SizedBox(height: 20),

                _textField(
                  controller: houseNumberController,
                  label: 'House/Flat Number*',
                  icon: Icons.home_outlined,
                  hint: 'e.g., 123, B-45',
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: detailedAddressController,
                  label: 'Detailed Address (Optional)',
                  icon: Icons.location_on_outlined,
                  hint: 'Landmark, nearby area',
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed:
                        isSaving || isLoadingLocation
                            ? null
                            : _saveUserDataWithLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2027),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('SAVE & CONTINUE',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2)),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitsCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Why we need your location',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.95))),
        const SizedBox(height: 16),
        _benefit(Icons.local_shipping_outlined,
            'Accurate delivery to your doorstep'),
        const SizedBox(height: 12),
        _benefit(Icons.access_time_outlined,
            'Get precise pickup time estimates'),
        const SizedBox(height: 12),
        _benefit(Icons.discount_outlined, 'Access location-based offers'),
      ]),
    );
  }

  Widget _privacyNote() => Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.lock_outline_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your data is secure and only used to improve your experience',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                  height: 1.4),
            ),
          ),
        ]),
      );

  Widget _addressTypeBtn(String type, IconData icon) {
    final sel = _selectedAddressType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedAddressType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0F2027) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? const Color(0xFF0F2027) : Colors.grey.shade300,
              width: sel ? 2 : 1.5,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: sel ? Colors.white : const Color(0xFF0F2027), size: 22),
            const SizedBox(height: 6),
            Text(type,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : const Color(0xFF0F2027))),
          ]),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2027))),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
            color: Color(0xFF0F2027),
            fontSize: 15,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF0F2027), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF0F2027), width: 2)),
        ),
      ),
    ]);
  }

  Widget _benefit(IconData icon, String text) => Row(children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
}
