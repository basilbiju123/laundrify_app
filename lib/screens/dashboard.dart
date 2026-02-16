import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'laundry_items_page.dart';
import 'dryclean_items_page.dart';
import 'shoe_items_page.dart';
import 'bag_items_page.dart';
import 'carpet_items_page.dart';
import 'curtain_items_page.dart';
import 'track_order_page.dart';
import 'order_history_page.dart';
import 'location_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'coupons_page.dart';
import '../services/firestore_service.dart';

enum OrderStatus { pickup, processing, delivery }

// ── Design Tokens ────────────────────────────────────────────────────────────
const _navy = Color(0xFF080F1E);
const _navyMid = Color(0xFF0D1F3C);
const _navyCard = Color(0xFF111827);
const _blue = Color(0xFF1B4FD8);
const _blueSoft = Color(0xFF3B82F6);
const _gold = Color(0xFFF5C518);
const _goldSoft = Color(0xFFFDE68A);
const _surface = Color(0xFFF0F4FF);
const _textDark = Color(0xFF0A1628);
const _textMid = Color(0xFF475569);
const _textFade = Color(0xFF94A3B8);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestore = FirestoreService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int bannerIndex = 0;
  late PageController _bannerController;
  final ScrollController _scrollController = ScrollController();
  Timer? _bannerTimer;

  // 🔥 DEMO ORDER STATE (logic unchanged)
  bool hasActiveOrder = false;
  OrderStatus currentStatus = OrderStatus.pickup;
  Timer? _demoOrderTimer;

  // Location state
  String? savedLocation;

  bool showRobotHelper = false;

  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _pulse;

  final List<String> banners = [
    "assets/images/banner1.png",
    "assets/images/banner2.png",
    "assets/images/banner3.png",
    "assets/images/banner4.png",
  ];

  final GlobalKey _servicesKey = GlobalKey();

  List<Map<String, dynamic>> completedOrders = [];

  // ── Helpers ─────────────────────────────────────────────────────────────
  String get profileLetter {
    final name = user?.displayName ?? user?.email ?? "U";
    return name.isNotEmpty ? name[0].toUpperCase() : "U";
  }

  String get displayName =>
      user?.displayName ?? user?.email?.split('@').first ?? "User";

  String get firstName => displayName.split(' ').first;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  String get statusLabel {
    switch (currentStatus) {
      case OrderStatus.pickup:
        return "Pickup Scheduled";
      case OrderStatus.processing:
        return "Gently Processing";
      case OrderStatus.delivery:
        return "Out for Delivery";
    }
  }

  String get statusSub {
    switch (currentStatus) {
      case OrderStatus.pickup:
        return "Driver is on the way";
      case OrderStatus.processing:
        return "Your clothes are being cleaned";
      case OrderStatus.delivery:
        return "Arriving soon — get ready!";
    }
  }

  IconData get statusIcon {
    switch (currentStatus) {
      case OrderStatus.pickup:
        return Icons.directions_bike_rounded;
      case OrderStatus.processing:
        return Icons.local_laundry_service_rounded;
      case OrderStatus.delivery:
        return Icons.delivery_dining_rounded;
    }
  }

  Color get statusColor {
    switch (currentStatus) {
      case OrderStatus.pickup:
        return _blueSoft;
      case OrderStatus.processing:
        return const Color(0xFFF59E0B);
      case OrderStatus.delivery:
        return const Color(0xFF10B981);
    }
  }

  // ── Services ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _services => [
        {
          'title': 'Laundry',
          'page': const LaundryPage(),
          'img': 'assets/images/laundry.png',
          'color': const Color(0xFF1B4FD8)
        },
        {
          'title': 'Dry Clean',
          'page': const DryCleanPage(),
          'img': 'assets/images/dryclean.png',
          'color': const Color(0xFF7C3AED)
        },
        {
          'title': 'Shoe Clean',
          'page': const ShoeDryCleanPage(),
          'img': 'assets/images/shoe.png',
          'color': const Color(0xFF0891B2)
        },
        {
          'title': 'Bag Clean',
          'page': const BagCleaningPage(),
          'img': 'assets/images/bag.png',
          'color': const Color(0xFFD97706)
        },
        {
          'title': 'Carpet',
          'page': const CarpetCleaningPage(),
          'img': 'assets/images/carpet.jpg',
          'color': const Color(0xFF059669)
        },
        {
          'title': 'Curtain',
          'page': const CurtainCleaningPage(),
          'img': 'assets/images/curtain.png',
          'color': const Color(0xFFE11D48)
        },
      ];

  @override
  void initState() {
    super.initState();

    _bannerController = PageController();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients) {
        bannerIndex = (bannerIndex + 1) % banners.length;
        _bannerController.animateToPage(
          bannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _entryFade =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _entryController.forward();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _firestore.getUserProfile();
      if (!mounted) return;
      if (profile != null) {
        final location = profile['location'];
        if (location != null && location is Map) {
          final label = location['addressLabel'] as String? ?? 'Home';
          final house = location['houseNumber'] as String? ?? '';
          final addr = location['address'] as String? ?? '';
          final detected = location['detectedAddress'] as String? ?? '';
          final displayAddr = house.isNotEmpty
              ? '$house, $addr'
              : (addr.isNotEmpty ? addr : detected);
          if (displayAddr.isNotEmpty) {
            setState(() => savedLocation = '$label: $displayAddr');
          }
        }

        // Load real orders from Firestore
        final orders = await _firestore.getOrders();
        if (mounted && orders.isNotEmpty) {
          setState(() => completedOrders = orders);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _demoOrderTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // 🔥 DEMO ORDER LOGIC (unchanged)
  void _startDemoOrder() {
    setState(() {
      hasActiveOrder = true;
      currentStatus = OrderStatus.pickup;
    });
    _demoOrderTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      setState(() {
        if (currentStatus == OrderStatus.pickup) {
          currentStatus = OrderStatus.processing;
        } else if (currentStatus == OrderStatus.processing) {
          currentStatus = OrderStatus.delivery;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: _surface,
          extendBodyBehindAppBar: true,
          endDrawer: _drawer(),

          // ── AppBar ─────────────────────────────────────────────────────
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_navy, _navyMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset("assets/images/logo.png",
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Laundrify",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            actions: [
              // Bell with gold dot
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 25),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: _navyMid, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              // Gold avatar
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  margin: const EdgeInsets.only(right: 16, left: 4),
                  child: user?.photoURL != null
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _gold, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(user!.photoURL!),
                          ),
                        )
                      : Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_gold, _goldSoft],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              profileLetter,
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          body: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── HERO ───────────────────────────────────────────
                    _hero(context),

                    const SizedBox(height: 22),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── BANNER ────────────────────────────────
                          _banner(),

                          const SizedBox(height: 30),

                          // ── SERVICES ──────────────────────────────
                          _sectionTitle("Our Services"),
                          const SizedBox(height: 14),
                          _servicesGrid(),

                          const SizedBox(height: 30),

                          // ── ORDERS ────────────────────────────────
                          _sectionTitle("Your Orders"),
                          const SizedBox(height: 14),

                          hasActiveOrder
                              ? _activeOrderCard()
                              : _emptyOrderCard(),

                          const SizedBox(height: 14),

                          // ── HISTORY ───────────────────────────────
                          _historyCard(),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── ROBOT HELPER (logic unchanged) ────────────────────────────
        if (showRobotHelper)
          Container(
            color: Colors.black.withValues(alpha: 0.65),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset("assets/lottie/robot_helper.json",
                        height: 130),
                    const SizedBox(height: 16),
                    const Text(
                      "Choose a service to\nbook your first order.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => showRobotHelper = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Got it!",
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── HERO ──────────────────────────────────────────────────────────────────
  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyMid, Color(0xFF0D2D6B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          // Decorative orbs
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _blueSoft.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 50,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _blue.withValues(alpha: 0.06),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 22,
              right: 22,
              bottom: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting row
                Row(
                  children: [
                    Text(
                      "${_greeting()}, ",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      firstName,
                      style: const TextStyle(
                        color: _goldSoft,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(" ✨", style: TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "What needs\ncleaning today?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: 22),

                // Location + stat row
                Row(
                  children: [
                    // Location chip
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LocationPage())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: _gold, size: 15),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Deliver to",
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      savedLocation ?? "Add location",
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Gold stat badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_gold, _goldSoft],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Text("6",
                              style: TextStyle(
                                color: _navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              )),
                          Text("Services",
                              style: TextStyle(
                                color: _navyCard,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BANNER ────────────────────────────────────────────────────────────────
  Widget _banner() {
    return Container(
      height: 175,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => bannerIndex = i),
              itemBuilder: (_, i) => Image.asset(banners[i], fit: BoxFit.cover),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  final active = bannerIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SERVICES GRID ─────────────────────────────────────────────────────────
  Widget _servicesGrid() {
    return GridView.count(
      key: _servicesKey,
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: _services.map((s) {
        return _serviceCard(s['title'], s['page'], s['img'], s['color']);
      }).toList(),
    );
  }

  Widget _serviceCard(String title, Widget page, String img, Color color) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(img, fit: BoxFit.cover),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      color.withValues(alpha: 0.4),
                      _navy.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Top color accent bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),

              // Title
              Positioned(
                bottom: 9,
                left: 6,
                right: 6,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.1,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACTIVE ORDER CARD ─────────────────────────────────────────────────────
  Widget _activeOrderCard() {
    final stepIdx = OrderStatus.values.indexOf(currentStatus);
    final steps = ["Pickup", "Processing", "Delivery"];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TrackOrderPage(status: currentStatus)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navy, _navyCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.4),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Orb decoration
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.1),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      // Pulsing icon
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Active Order",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Track pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          "Track →",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Text(
                      statusSub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Step progress
                  Row(
                    children: List.generate(steps.length, (i) {
                      final done = i <= stepIdx;
                      final active = i == stepIdx;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 450),
                                    width: active ? 30 : 22,
                                    height: active ? 30 : 22,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? statusColor
                                          : Colors.white.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: done
                                            ? statusColor
                                            : Colors.white
                                                .withValues(alpha: 0.18),
                                        width: active ? 2.5 : 1.5,
                                      ),
                                      boxShadow: active
                                          ? [
                                              BoxShadow(
                                                color: statusColor.withValues(
                                                    alpha: 0.5),
                                                blurRadius: 12,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: done
                                        ? Icon(
                                            active
                                                ? Icons.circle
                                                : Icons.check_rounded,
                                            color: _navy,
                                            size: active ? 10 : 12,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    steps[i],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: done
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                      color: done
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < steps.length - 1)
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 450),
                                  height: 2,
                                  margin: const EdgeInsets.only(bottom: 28),
                                  decoration: BoxDecoration(
                                    color: i < stepIdx
                                        ? statusColor
                                        : Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMPTY ORDER CARD ──────────────────────────────────────────────────────
  Widget _emptyOrderCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _blue.withValues(alpha: 0.1),
                  _blueSoft.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_laundry_service_rounded,
              color: _blue,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No active orders",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Fresh clothes, zero effort.\nBook your first pickup today!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textMid, height: 1.55),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _startDemoOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child:
                        const Icon(Icons.add_rounded, color: _gold, size: 15),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Book Now",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HISTORY CARD ──────────────────────────────────────────────────────────
  // ✅ FIX #3: Pass completedOrders parameter
  Widget _historyCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderHistoryPage(initialOrders: completedOrders),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _blue.withValues(alpha: 0.1),
                    _blueSoft.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.history_rounded, color: _blue, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order History",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "View all your past orders",
                    style: TextStyle(fontSize: 12, color: _textFade),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ── SECTION TITLE ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_blue, _blueSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: _textDark,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  // ── DRAWER ────────────────────────────────────────────────────────────────
  Widget _drawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          bottomLeft: Radius.circular(32),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_navy, _navyCard],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _blueSoft.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: 10,
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 24,
                      left: 24,
                      right: 24,
                      bottom: 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with gold ring
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_gold, _goldSoft],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: _navyCard,
                              shape: BoxShape.circle,
                            ),
                            child: user?.photoURL != null
                                ? CircleAvatar(
                                    radius: 36,
                                    backgroundImage:
                                        NetworkImage(user!.photoURL!),
                                  )
                                : CircleAvatar(
                                    radius: 36,
                                    backgroundColor:
                                        _blue.withValues(alpha: 0.25),
                                    child: Text(
                                      profileLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? user?.phoneNumber ?? "",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Verified badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: user?.emailVerified == true
                                ? _gold.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: user?.emailVerified == true
                                  ? _gold.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user?.emailVerified == true
                                    ? Icons.verified_rounded
                                    : Icons.pending_outlined,
                                color: user?.emailVerified == true
                                    ? _gold
                                    : Colors.white38,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user?.emailVerified == true
                                    ? "Verified Account"
                                    : "Pending Verification",
                                style: TextStyle(
                                  color: user?.emailVerified == true
                                      ? _gold
                                      : Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu ───────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                children: [
                  _tile(Icons.person_outline_rounded, "My Profile",
                      const Color(0xFF1B4FD8), () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()));
                  }),
                  _tile(Icons.location_on_outlined, "Saved Addresses",
                      const Color(0xFF059669), () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LocationPage()));
                  }),
                  // ✅ FIX #2: Pass completedOrders parameter
                  _tile(Icons.history_rounded, "Order History",
                      const Color(0xFF7C3AED), () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrderHistoryPage(
                                initialOrders: completedOrders)));
                  }),
                  _tile(Icons.local_offer_outlined, "Offers & Coupons",
                      const Color(0xFFD97706), () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CouponsPage()));
                  }, badge: "NEW"),
                  _tile(Icons.help_outline_rounded, "Help & Support",
                      const Color(0xFF0891B2), () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HelpPage()));
                  }),
                  _tile(Icons.settings_outlined, "Settings", _textMid, () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()));
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    child: Container(height: 1, color: const Color(0xFFF1F5F9)),
                  ),
                  _tile(
                      Icons.logout_rounded, "Sign Out", const Color(0xFFEF4444),
                      () async {
                    final shouldSignOut = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Sign Out',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Sign Out',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (shouldSignOut == true && mounted) {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    }
                  }),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(
                "Laundrify · v1.0.0",
                style: TextStyle(fontSize: 11, color: _textFade),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    String? badge,
  }) {
    final isDestructive = label == "Sign Out" || label == "Delete Account";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color:
                          isDestructive ? const Color(0xFFEF4444) : _textDark,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: _textFade, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
