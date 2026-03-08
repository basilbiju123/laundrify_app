import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// lottie import removed - replaced with icon fallback (no asset file)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/windows_layout.dart';
import '../theme/app_theme.dart';

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
import 'orders_page.dart';
import 'cancel_order_page.dart';
import 'loyalty_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'coupons_page.dart';
import 'auth_options_page.dart';
import 'abandoned_cart_page.dart';
import '../services/firestore_service.dart';
import '../services/panel_theme_service.dart';

enum OrderStatus { pickup, processing, delivery }

// ── Design Tokens ────────────────────────────────────────────────────────────
const _navy = Color(0xFF080F1E);
const _navyMid = Color(0xFF0D1F3C);
const _navyCard = Color(0xFF111827);
const _blue = Color(0xFF1B4FD8);
const _blueSoft = Color(0xFF3B82F6);
const _gold = Color(0xFFF5C518);
const _goldSoft = Color(0xFFFDE68A);
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
  int _unreadNotifCount = 0;
  StreamSubscription<QuerySnapshot>? _notifCountSub;

  // Real Firebase order tracking
  bool hasActiveOrder = false;
  OrderStatus currentStatus = OrderStatus.pickup;
  String? activeOrderId;
  Map<String, dynamic>? activeOrderData;
  // ─────────────────────────────────────────────────────────────────────────

  // Location state
  String? savedLocation;

  bool showRobotHelper = false;
  int _currentTab = 0; // 0=Home 1=Orders 2=Track 3=Loyalty 4=Profile

  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _pulse;

  // Banner data — no image assets needed, drawn in Flutter
  final List<Map<String, dynamic>> _bannerData = [
    {
      'title': 'Fresh Laundry\nAt Your Door',
      'subtitle': 'Save 20% on first order',
      'icon': Icons.local_laundry_service_rounded,
      'grad1': Color(0xFF1B4FD8),
      'grad2': Color(0xFF0A3BAD),
      'accent': Color(0xFFF5C518),
      'badge': '20% OFF',
    },
    {
      'title': 'Dry Clean\nExpress',
      'subtitle': '24-hour turnaround guaranteed',
      'icon': Icons.dry_cleaning_rounded,
      'grad1': Color(0xFF0E7490),
      'grad2': Color(0xFF0C4A6E),
      'accent': Color(0xFF34D399),
      'badge': 'EXPRESS',
    },
    {
      'title': 'Shoe & Bag\nCleaning',
      'subtitle': 'Premium care for your accessories',
      'icon': Icons.checkroom_rounded,
      'grad1': Color(0xFF7C3AED),
      'grad2': Color(0xFF4C1D95),
      'accent': Color(0xFFF59E0B),
      'badge': 'PREMIUM',
    },
    {
      'title': 'Free Pickup\n& Delivery',
      'subtitle': 'On orders above ₹299',
      'icon': Icons.delivery_dining_rounded,
      'grad1': Color(0xFF059669),
      'grad2': Color(0xFF065F46),
      'accent': Color(0xFFFDE68A),
      'badge': 'FREE',
    },
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

  String _fmtDate(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Timestamp) {
      final dt = val.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return val.toString();
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
        bannerIndex = (bannerIndex + 1) % _bannerData.length;
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
    _listenUnreadCount();
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

        // Active order is handled by StreamBuilder in _buildActiveOrderStream()
        // No one-time .get() needed here — avoids flash/conflict
      }
    } catch (_) {}
  }

  void _listenUnreadCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _notifCountSub?.cancel();
    _notifCountSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadNotifCount = snap.docs.length);
    });
    // Also listen to broadcasts (no userId filter)
    // We combine by also checking targetGroup notifications separately
  }

  @override
  void dispose() {
    _notifCountSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Navigate to laundry services to book a real order
  void _startDemoOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LaundryPage()),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PanelThemeScope(
      panelKey: 'user',
      child: Builder(builder: (ctx) => _buildScaffold(ctx)),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final t = AppColors.of(context);
    final mobileScaffold = PopScope(
      canPop: _currentTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentTab != 0) {
          setState(() => _currentTab = 0);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            backgroundColor: t.bg,
            extendBodyBehindAppBar: !kIsWeb,
            endDrawer: _drawer(),
            bottomNavigationBar: kIsWeb ? null : _bottomNav(),

            // ── AppBar ─────────────────────────────────────────────────────
            appBar: kIsWeb
                ? null
                : AppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle.light,
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
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
                      // Abandoned cart icon
                      StreamBuilder<QuerySnapshot>(
                        stream: user != null
                            ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('abandoned_carts')
                                .where('status', whereIn: ['abandoned', 'saved'])
                                .snapshots()
                            : null,
                        builder: (ctx, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    color: Colors.white, size: 24),
                                Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle),
                                    child: Text('$count',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AbandonedCartPage())),
                          );
                        },
                      ),
                      // Bell with unread dot (only shows when there are unread notifications)
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 25),
                            if (_unreadNotifCount > 0)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: _unreadNotifCount > 9 ? 16 : 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _gold,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: _navyMid, width: 1.5),
                                  ),
                                  child: _unreadNotifCount > 9
                                      ? const Center(
                                          child: Text('9+',
                                              style: TextStyle(
                                                  color: Color(0xFF080F1E),
                                                  fontSize: 5,
                                                  fontWeight: FontWeight.w900)))
                                      : null,
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
                          ).then((_) => _listenUnreadCount()); // refresh after returning
                        },
                      ),
                      Builder(builder: (ctx) {
                        PanelThemeService? pt;
                        try {
                          pt = PanelThemeScope.of(ctx);
                        } catch (_) {}
                        if (pt == null) return const SizedBox.shrink();
                        return IconButton(
                          tooltip:
                              pt.isDark ? 'Switch to light mode' : 'Switch to dark mode',
                          icon: Icon(
                            pt.isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => pt!.toggle(),
                        );
                      }),
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
                                    backgroundImage: null,
                                    child: ClipOval(
                                        child: Image.network(user!.photoURL!,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                                color: const Color(0xFFF5C518),
                                                child: Center(
                                                    child: Text(
                                                        (user?.displayName ??
                                                                user?.email ??
                                                                'U')[0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: Color(
                                                                0xFF080F1E))))))),
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

            body: _buildTabBody(),
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
                    color: t.card,
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
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF1B4FD8)
                                    .withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: const Icon(Icons.local_laundry_service_rounded,
                            size: 52, color: Color(0xFF1B4FD8)),
                      ),
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
      ),
    );
    return WindowsLayout(
      title: 'Dashboard',
      currentRoute: '/dashboard',
      child: mobileScaffold,
    );
  }

  // ── TAB BODY — avoids nested Scaffold black screens ─────────────────────
  Widget _buildTabBody() {
    switch (_currentTab) {
      case 0:
        return FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hero(context),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _banner(),
                        const SizedBox(height: 30),
                        _sectionTitle("Our Services"),
                        const SizedBox(height: 14),
                        _servicesGrid(),
                        const SizedBox(height: 30),
                        _sectionTitle("Your Orders"),
                        const SizedBox(height: 14),
                        _savedCartsCard(),
                        const SizedBox(height: 12),
                        _buildActiveOrderStream(),
                        const SizedBox(height: 14),
                        _historyCard(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 1:
        return const _NestedPage(child: OrdersPage());
      case 2:
        return _NestedPage(child: TrackOrderPage(orderId: activeOrderId ?? ''));
      case 3:
        return const _NestedPage(child: LoyaltyPage());
      case 4:
        return const _NestedPage(child: ProfilePage());
      default:
        return const SizedBox();
    }
  }

  // ── HERO ──────────────────────────────────────────────────────────────────
  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
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
              // On web/Windows: _TopBar is already in WindowsLayout above the hero.
              // On mobile: AppBar (kToolbarHeight) + status bar padding.
              top: kIsWeb
                  ? 16
                  : MediaQuery.of(context).padding.top + kToolbarHeight + 16,
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
                    Flexible(
                      child: Text(
                        "${_greeting()}, ",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        firstName,
                        style: const TextStyle(
                          color: _goldSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                        onTap: () {
                          if (savedLocation != null) {
                            // Location exists — show change/cancel dialog
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D1F3C),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24)),
                                ),
                                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                          width: 40, height: 4,
                                          decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(2))),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _gold.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.location_on_rounded,
                                            color: _gold, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Delivery Location',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.w600)),
                                          Text(savedLocation!,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      )),
                                    ]),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit_location_rounded, size: 18),
                                        label: const Text('Change Location',
                                            style: TextStyle(fontWeight: FontWeight.w800)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _gold,
                                          foregroundColor: const Color(0xFF080F1E),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(context,
                                              MaterialPageRoute(
                                                  builder: (_) => const LocationPage()));
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel',
                                            style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            // No location — go directly to add it
                            Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const LocationPage()));
                          }
                        },
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

  // ── CUSTOM BANNER SLIDE — no image assets needed ──────────────────────────
  Widget _buildBannerSlide(Map<String, dynamic> b) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [b['grad1'] as Color, b['grad2'] as Color],
        ),
      ),
      child: Stack(
        children: [
          // Background pattern circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -25,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (b['accent'] as Color).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: (b['accent'] as Color)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          b['badge'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: b['accent'] as Color,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b['title'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    b['icon'] as IconData,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerH = constraints.maxWidth > 500 ? 200.0 : 160.0;
        return Container(
          height: bannerH,
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
                  itemCount: _bannerData.length,
                  onPageChanged: (i) => setState(() => bannerIndex = i),
                  itemBuilder: (_, i) {
                    final b = _bannerData[i];
                    return _buildBannerSlide(b);
                  },
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_bannerData.length, (i) {
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
      },
    );
  }

  // ── SERVICES GRID ─────────────────────────────────────────────────────────
  Widget _servicesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 500 ? 4 : 3;
        return GridView.count(
          key: _servicesKey,
          crossAxisCount: cols,
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
      },
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.1,
                    height: 1.2,
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
            builder: (_) => TrackOrderPage(orderId: activeOrderId ?? '')),
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
                  // ── Date / Location ──────────────────────────────────
                  if (savedLocation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.location_on_rounded,
                            color: _gold, size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                          savedLocation!.replaceAll(RegExp(r'^[^:]+:\s*'), ''),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            // Cancel order button
            if (activeOrderId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CancelOrderPage(
                        orderId: activeOrderId!,
                        orderData: activeOrderData ?? {},
                      ),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 6),
                        Text("Cancel Order",
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ACTIVE ORDER STREAM — real-time, no flashing ──────────────────────────
  Widget _buildActiveOrderStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _emptyOrderCard();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: [
            'pending',
            'assigned',
            'accepted',
            'pickup',
            'picked',
            'reached',
            'processing',
            'ready',
            'out_for_delivery',
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        // While waiting for first data — show last known state, not spinner
        if (!snap.hasData) {
          return hasActiveOrder ? _activeOrderCard() : _emptyOrderCard();
        }

        if (snap.data!.docs.isEmpty) {
          // Update state if it changed
          if (hasActiveOrder) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  hasActiveOrder = false;
                  activeOrderId = null;
                  activeOrderData = null;
                });
              }
            });
          }
          return _emptyOrderCard();
        }

        final doc = snap.data!.docs.first;
        final d = doc.data() as Map<String, dynamic>;
        final fStatus = d['status'] ?? 'pending';

        OrderStatus mapped = OrderStatus.pickup;
        if (['processing', 'picked', 'reached'].contains(fStatus)) {
          mapped = OrderStatus.processing;
        } else if (['out_for_delivery', 'ready', 'delivered']
            .contains(fStatus)) {
          mapped = OrderStatus.delivery;
        }

        // Keep state in sync without triggering a rebuild loop
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (activeOrderId != doc.id || currentStatus != mapped)) {
            setState(() {
              hasActiveOrder = true;
              activeOrderId = doc.id;
              activeOrderData = d;
              currentStatus = mapped;
            });
          }
        });

        return _activeOrderCardWithCancel(doc.id, d);
      },
    );
  }

  // ── ACTIVE ORDER CARD + CANCEL BUTTON ────────────────────────────────────
  Widget _activeOrderCardWithCancel(String orderId, Map<String, dynamic> data) {
    final stepIdx = OrderStatus.values.indexOf(currentStatus);
    final steps = ["Pickup", "Processing", "Delivery"];
    final status = data['status'] ?? 'pending';

    // Can only cancel if not yet picked up
    final canCancel = ['pending', 'confirmed', 'assigned'].contains(status);

    return Column(
      children: [
        // ── Main card (same as before, tappable to track) ──
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TrackOrderPage(orderId: orderId))),
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
                    offset: const Offset(0, 10))
              ],
            ),
            child: Stack(children: [
              Positioned(
                  right: -24,
                  top: -24,
                  child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.1)))),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ScaleTransition(
                          scale: _pulse,
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3)),
                              boxShadow: [
                                BoxShadow(
                                    color: statusColor.withValues(alpha: 0.25),
                                    blurRadius: 12)
                              ],
                            ),
                            child:
                                Icon(statusIcon, color: statusColor, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text("Active Order",
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 3),
                              Text(statusLabel,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2)),
                            ])),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.35)),
                          ),
                          child: Text("Track →",
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(left: 50),
                        child: Text(statusSub,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 12)),
                      ),
                      const SizedBox(height: 24),
                      // Step progress
                      Row(
                          children: List.generate(steps.length, (i) {
                        final done = i <= stepIdx;
                        final active = i == stepIdx;
                        return Expanded(
                            child: Row(children: [
                          Expanded(
                              child: Column(children: [
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
                                        : Colors.white.withValues(alpha: 0.18),
                                    width: active ? 2.5 : 1.5),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                            color: statusColor.withValues(
                                                alpha: 0.5),
                                            blurRadius: 12)
                                      ]
                                    : null,
                              ),
                              child: done
                                  ? Icon(
                                      active
                                          ? Icons.circle
                                          : Icons.check_rounded,
                                      color: _navy,
                                      size: active ? 10 : 12)
                                  : null,
                            ),
                            const SizedBox(height: 7),
                            Text(steps[i],
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: done
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: done
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.3))),
                          ])),
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
                            )),
                        ]));
                      })),
                      // ── Date / Time / Location row ────────────────────
                      if (data['pickupDate'] != null ||
                          data['pickupTime'] != null ||
                          savedLocation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            if (data['pickupDate'] != null) ...[
                              const Icon(Icons.calendar_today_rounded,
                                  color: Color(0xFFF5C518), size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                  child: Text(
                                _fmtDate(data['pickupDate']),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8)),
                                overflow: TextOverflow.ellipsis,
                              )),
                              const SizedBox(width: 12),
                            ],
                            if (data['pickupTime'] != null) ...[
                              const Icon(Icons.access_time_rounded,
                                  color: Color(0xFFF5C518), size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                  child: Text(
                                data['pickupTime'].toString(),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8)),
                                overflow: TextOverflow.ellipsis,
                              )),
                              const SizedBox(width: 12),
                            ],
                            if (savedLocation != null) ...[
                              const Icon(Icons.location_on_rounded,
                                  color: Color(0xFFF5C518), size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                  child: Text(
                                savedLocation!
                                    .replaceAll(RegExp(r'^[^:]+:\s*'), ''),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                            ],
                          ]),
                        ),
                      ],
                    ]),
              ),
            ]),
          ),
        ),

        // ── Cancel button (only shown when order can still be cancelled) ──
        if (canCancel) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CancelOrderPage(orderId: orderId, orderData: data),
                )),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined,
                        color: Color(0xFFEF4444), size: 17),
                    SizedBox(width: 8),
                    Text('Cancel Order',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444))),
                  ]),
            ),
          ),
        ],
      ],
    );
  }

  // ── EMPTY ORDER CARD ──────────────────────────────────────────────────────
  Widget _emptyOrderCard() {
    final t = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.cardBdr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.06),
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
                  _blue.withValues(alpha: 0.12),
                  _blueSoft.withValues(alpha: 0.06),
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
          Text(
            "No active orders",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: t.textHi,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            "Fresh clothes, zero effort.\nBook your first pickup today!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.textMid, height: 1.55),
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
  // ── Saved Carts card on home tab ─────────────────────────────────────────
  Widget _savedCartsCard() {
    final uid = user?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abandoned_carts')
          .where('status', whereIn: ['abandoned', 'saved'])
          .snapshots(),
      builder: (context, snap) {
        final t = AppColors.of(context);
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();

        final savedCount = snap.data?.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['saveType'] == 'incomplete' || data['status'] == 'saved';
        }).length ?? 0;
        final failedCount = count - savedCount;

        return GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AbandonedCartPage())),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _gold.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_cart_rounded,
                    color: _gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Saved Carts',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: t.textHi)),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (savedCount > 0) ...[
                      _cartChip('$savedCount saved',
                          const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                    ],
                    if (failedCount > 0)
                      _cartChip('$failedCount failed',
                          const Color(0xFFF59E0B)),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textDim, size: 20),
            ]),
          ),
        );
      },
    );
  }

  Widget _cartChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      );

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
          color: AppColors.of(context).card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.of(context).cardBdr),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: AppColors.of(context).isDark ? 0.2 : 0.05),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order History",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.of(context).textHi,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "View all your past orders",
                    style: TextStyle(
                        fontSize: 12, color: AppColors.of(context).textDim),
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
    final t = AppColors.of(context);
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
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: t.textHi,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  // ── DRAWER ────────────────────────────────────────────────────────────────
  Widget _drawer() {
    final t = AppColors.of(context);
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
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
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
                      top:
                          kIsWeb ? 24 : MediaQuery.of(context).padding.top + 24,
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_gold, _goldSoft],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
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
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage()));
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
                        content:
                            const Text('Are you sure you want to sign out?'),
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
                      Navigator.pop(context); // close drawer
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const AuthOptionsPage()),
                          (route) => false,
                        );
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

  // ── BOTTOM NAV BAR ────────────────────────────────────────────────────────
  Widget _bottomNav() {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Orders'},
      {'icon': Icons.local_shipping_rounded, 'label': 'Track'},
      {'icon': Icons.card_giftcard_rounded, 'label': 'Loyalty'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: _navy,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = _currentTab == i;
              final icon = items[i]['icon'] as IconData;
              final label = items[i]['label'] as String;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                        color: active ? _gold : Colors.transparent,
                        width: 2.5,
                      )),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: active ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(icon,
                              color: active
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.45),
                              size: 24),
                        ),
                        const SizedBox(height: 3),
                        Text(label,
                            style: TextStyle(
                              color: active
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
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
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : AppColors.of(context).textHi,
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

/// Wraps a page widget that normally uses WindowsLayout (full Scaffold)
/// so it can live inside the dashboard body without nested Scaffold issues.
/// It uses a MediaQuery override to ensure proper sizing.
class _NestedPage extends StatefulWidget {
  final Widget child;
  const _NestedPage({required this.child});

  @override
  State<_NestedPage> createState() => _NestedPageState();
}

class _NestedPageState extends State<_NestedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
