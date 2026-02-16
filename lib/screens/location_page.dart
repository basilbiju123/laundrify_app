import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dashboard.dart';
import 'auth_options_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage>
    with SingleTickerProviderStateMixin {
  bool isLoadingLocation = false;
  bool isSkipping = false;
  String? currentAddress;
  Position? currentPosition;

  // Text controllers for address details
  final TextEditingController houseNumberController = TextEditingController();
  final TextEditingController detailedAddressController =
      TextEditingController();

  // Optional address fields
  final TextEditingController officeNameController = TextEditingController();
  final TextEditingController officeAddressController = TextEditingController();
  final TextEditingController otherAddressController = TextEditingController();

  // Address type selection
  String _selectedAddressType = 'Home'; // Home, Office, Other

  late AnimationController _animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    houseNumberController.dispose();
    detailedAddressController.dispose();
    officeNameController.dispose();
    officeAddressController.dispose();
    otherAddressController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // GET CURRENT LOCATION
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack(
          "Location services are disabled. Please enable them in settings.",
          isError: true,
        );
        setState(() => isLoadingLocation = false);
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack("Location permission denied", isError: true);
          setState(() => isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          "Location permissions are permanently denied. Please enable them in settings.",
          isError: true,
        );
        setState(() => isLoadingLocation = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address += '${place.street}, ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += '${place.locality}, ';
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address += '${place.administrativeArea}, ';
        }
        if (place.country != null && place.country!.isNotEmpty) {
          address += place.country!;
        }

        setState(() {
          currentPosition = position;
          currentAddress = address.isNotEmpty ? address : "Location detected";
        });

        _showSnack("Location detected successfully!", isError: false);
      }
    } catch (e) {
      _showSnack(
        "Failed to get location. Please check your network connection.",
        isError: true,
      );
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // SAVE USER DATA WITH LOCATION
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _saveUserDataWithLocation() async {
    if (currentPosition == null) {
      _showSnack("Please get your location first", isError: true);
      return;
    }

    setState(() => isLoadingLocation = true);

    try {
      // Wait a moment for Firebase Auth state to settle (phone auth can be slightly delayed)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 800));
        user = FirebaseAuth.instance.currentUser;
      }
      if (user == null) {
        if (mounted) {
          setState(() => isLoadingLocation = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
          );
        }
        return;
      }

      // Save/update user data with location in Firestore
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "phone": user.phoneNumber ?? "",
        "emailVerified": user.emailVerified,
        "phoneVerified": user.phoneNumber != null,
        "location": {
          "latitude": currentPosition!.latitude,
          "longitude": currentPosition!.longitude,
          "detectedAddress": currentAddress ?? "Location saved",
          "houseNumber": houseNumberController.text.trim(),
          "address": detailedAddressController.text.trim(),
          "timestamp": FieldValue.serverTimestamp(),
        },
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showSnack("Profile completed successfully!", isError: false);

      // Navigate to dashboard
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      _showSnack("Failed to save data: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => isLoadingLocation = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // SKIP LOCATION (Save user data without location)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _skipLocation() async {
    setState(() => isSkipping = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 800));
        user = FirebaseAuth.instance.currentUser;
      }
      if (user == null) {
        if (mounted) {
          setState(() => isSkipping = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
          );
        }
        return;
      }

      // Save/update user data WITHOUT location in Firestore
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "phone": user.phoneNumber ?? "",
        "emailVerified": user.emailVerified,
        "phoneVerified": user.phoneNumber != null,
        "location": null, // No location data
        "locationSkipped": true,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showSnack("You can add location later from settings", isError: false);

      // Navigate to dashboard
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      _showSnack("Failed to skip: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => isSkipping = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3F6FD8),
              Color(0xFF2F4F9F),
              Color(0xFF1E3A8A),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Location Icon ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 90,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Title ───────────────────────────────────────────
                      const Text(
                        "Enable Location",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Help us serve you better by\nsharing your location",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── White Card Container ────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Current Location Display
                            if (currentAddress != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Current Location",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            currentAddress!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // House Number Input
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: houseNumberController,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.home_outlined,
                                      color: Color(0xFF3F6FD8),
                                      size: 22,
                                    ),
                                    labelText: "House/Flat Number",
                                    hintText: "e.g., 123, Flat 4B",
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FE),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3F6FD8),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Detailed Address Input
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: detailedAddressController,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(bottom: 45),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: Color(0xFF3F6FD8),
                                        size: 22,
                                      ),
                                    ),
                                    labelText: "Complete Address",
                                    hintText: "Street, Landmark, Area",
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FE),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3F6FD8),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Address Type ─────────────────────────
                              Row(children: [
                                Text('Address Type',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade700)),
                                const SizedBox(width: 12),
                                ...[
                                  'Home',
                                  'Office',
                                  'Other'
                                ].map((type) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedAddressType = type),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedAddressType == type
                                                ? const Color(0xFF3F6FD8)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: const Color(0xFF3F6FD8),
                                                width: 1.5),
                                          ),
                                          child: Text(type,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _selectedAddressType ==
                                                        type
                                                    ? Colors.white
                                                    : const Color(0xFF3F6FD8),
                                              )),
                                        ),
                                      ),
                                    )),
                              ]),

                              const SizedBox(height: 16),

                              // ── Office Fields (optional) ──────────────
                              if (_selectedAddressType == 'Office') ...[
                                TextField(
                                  controller: officeNameController,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                        Icons.business_outlined,
                                        color: Color(0xFF3F6FD8),
                                        size: 22),
                                    labelText: 'Office/Company Name (Optional)',
                                    hintText: 'e.g., ABC Technologies',
                                    labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FE),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF3F6FD8),
                                            width: 2)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: officeAddressController,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 22),
                                        child: Icon(
                                            Icons.location_city_outlined,
                                            color: Color(0xFF3F6FD8),
                                            size: 22)),
                                    labelText: 'Office Address (Optional)',
                                    hintText: 'Building, Floor, Street',
                                    labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FE),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF3F6FD8),
                                            width: 2)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ── Other Address (optional) ──────────────
                              if (_selectedAddressType == 'Other') ...[
                                TextField(
                                  controller: otherAddressController,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 22),
                                        child: Icon(
                                            Icons.add_location_alt_outlined,
                                            color: Color(0xFF3F6FD8),
                                            size: 22)),
                                    labelText:
                                        'Other Address Details (Optional)',
                                    hintText: 'Describe your location',
                                    labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FE),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF3F6FD8),
                                            width: 2)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              const SizedBox(height: 8),
                            ],

                            // Get Location Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isLoadingLocation || isSkipping
                                    ? null
                                    : _getCurrentLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentAddress != null
                                      ? Colors.green.shade600
                                      : const Color(0xFF3F6FD8),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: isLoadingLocation
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            currentAddress != null
                                                ? Icons.refresh
                                                : Icons.my_location,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            currentAddress != null
                                                ? "UPDATE LOCATION"
                                                : "GET MY LOCATION",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // Confirm Location Button (only show if location is fetched)
                            if (currentAddress != null) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isLoadingLocation || isSkipping
                                      ? null
                                      : _saveUserDataWithLocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3F6FD8),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        "CONFIRM & CONTINUE",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Skip Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: isLoadingLocation || isSkipping
                                    ? null
                                    : _skipLocation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF3F6FD8),
                                  side: const BorderSide(
                                    color: Color(0xFF3F6FD8),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: isSkipping
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF3F6FD8),
                                        ),
                                      )
                                    : const Text(
                                        "SKIP FOR NOW",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Benefits
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Get accurate delivery estimates",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Find nearby service providers",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.discount_outlined,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Access location-based offers",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Privacy Note
                      Text(
                        "Your location data is secure and will\nonly be used to improve your experience",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
