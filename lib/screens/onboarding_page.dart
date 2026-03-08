import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

// ═══════════════════════════════════════════════════════════════════
// ONBOARDING PAGE — Adaptive UI
//   Mobile: Full-screen immersive PageView
//   Web:    Premium split-screen with sidebar nav + feature cards
// ═══════════════════════════════════════════════════════════════════

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _scaleCtrl;

  final List<OnboardingData> _pages = [
    OnboardingData(
      image: 'assets/images/onboard1.png',
      title: 'Schedule Pickup',
      subtitle: 'On Your Time',
      description: 'Book pickups at your convenience—punctual, professional, and always on point!',
      accentColor: const Color(0xFF42A5F5),
      iconData: Icons.access_time_rounded,
      webFeatures: [
        WebFeature('Smart Scheduling', 'Pick any slot — morning, afternoon or evening', Icons.calendar_today_rounded),
        WebFeature('Real-time Tracking', 'Watch your laundry through every stage', Icons.location_on_rounded),
        WebFeature('Instant Confirmation', 'Booking confirmed instantly with full details', Icons.check_circle_rounded),
      ],
    ),
    OnboardingData(
      image: 'assets/images/onboard2.png',
      title: 'Premium Services',
      subtitle: 'Expert Care',
      description: 'From washing to expert dry cleaning—maintaining the quality your clothes deserve.',
      accentColor: const Color(0xFF26C6DA),
      iconData: Icons.local_laundry_service_rounded,
      webFeatures: [
        WebFeature('Dry Cleaning', 'Professional-grade techniques for delicate fabrics', Icons.dry_cleaning_rounded),
        WebFeature('Laundry & Fold', 'Washed, dried and folded to perfection', Icons.local_laundry_service_rounded),
        WebFeature('Stain Treatment', 'Specialist removal with eco-friendly products', Icons.science_rounded),
      ],
    ),
    OnboardingData(
      image: 'assets/images/onboard3.png',
      title: 'World Class',
      subtitle: 'Complete Solutions',
      description: 'Dry clean, laundry, shoes, bags, carpets, curtains—we handle it all with care.',
      accentColor: const Color(0xFF66BB6A),
      iconData: Icons.stars_rounded,
      webFeatures: [
        WebFeature('Shoes & Bags', 'Expert cleaning and conditioning for all materials', Icons.shopping_bag_rounded),
        WebFeature('Carpets & Rugs', 'Deep cleaning for all types of carpets', Icons.layers_rounded),
        WebFeature('Curtains & Drapes', 'Full-length cleaning with wrinkle-free finish', Icons.window_rounded),
      ],
    ),
    OnboardingData(
      image: 'assets/images/onboard4.png',
      title: 'Special Offers',
      subtitle: '20% Off First Order',
      description: 'Get 20% off your first order. Book now for fresh, like-new clothes!',
      accentColor: const Color(0xFFFF7043),
      iconData: Icons.local_offer_rounded,
      webFeatures: [
        WebFeature('20% First Order', 'New customers enjoy a generous first-order discount', Icons.local_offer_rounded),
        WebFeature('Loyalty Points', 'Earn points on every order, redeem for free services', Icons.stars_rounded),
        WebFeature('Referral Bonuses', 'Refer friends and earn credit for their first order', Icons.people_rounded),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeCtrl.forward();
    _scaleCtrl.forward();
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      widget.onFinished();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _fadeCtrl.reset(); _fadeCtrl.forward();
    _scaleCtrl.reset(); _scaleCtrl.forward();
  }

  void _goToPage(int index) =>
      _controller.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _controller.dispose(); _fadeCtrl.dispose(); _floatCtrl.dispose(); _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (kIsWeb && width > 900) return _webLayout(context);
    return _mobileLayout(context);
  }

  // ══════════════════════════════════════════════════════════
  // WEB LAYOUT
  // ══════════════════════════════════════════════════════════
  Widget _webLayout(BuildContext context) {
    final p = _pages[_currentIndex];
    final isLast = _currentIndex == _pages.length - 1;

    return Scaffold(
      body: Row(children: [
        // ── Left sidebar ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 290,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [const Color(0xFF080F1E),
                Color.lerp(const Color(0xFF0D1F3C), p.accentColor, 0.15)!],
            ),
          ),
          child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 28),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5C518).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFF5C518).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.local_laundry_service_rounded, color: Color(0xFFF5C518), size: 20),
                ),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Laundrify', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Premium Laundry', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ]),
              ]),
            ),
            const SizedBox(height: 40),
            // Step nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: List.generate(_pages.length, (i) {
                final pg = _pages[i];
                final active = _currentIndex == i;
                final done = i < _currentIndex;
                return GestureDetector(
                  onTap: () => _goToPage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? Colors.white.withValues(alpha: 0.2) : Colors.transparent),
                    ),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: done ? const Color(0xFF10B981) : active ? pg.accentColor : Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: done
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                            : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(pg.title, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(pg.subtitle, style: TextStyle(color: active ? Colors.white38 : Colors.white24, fontSize: 10)),
                      ])),
                      if (active) Icon(Icons.arrow_forward_ios_rounded, color: pg.accentColor, size: 11),
                    ]),
                  ),
                );
              })),
            ),
            const Spacer(),
            // Trust badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _trustBadge(Icons.verified_rounded, '10,000+ Happy Customers'),
                const SizedBox(height: 8),
                _trustBadge(Icons.star_rounded, '4.9★ Average Rating'),
                const SizedBox(height: 8),
                _trustBadge(Icons.eco_rounded, '100% Eco-friendly Products'),
              ]),
            ),
            const SizedBox(height: 24),
          ])),
        ),

        // ── Right content ──
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: const Color(0xFFF0F4FF),
            child: Stack(children: [
              // Deco circles
              Positioned(right: -50, top: -50, child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 250, height: 250,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.accentColor.withValues(alpha: 0.07)),
              )),
              Positioned(left: -40, bottom: -40, child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 180, height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.accentColor.withValues(alpha: 0.05)),
              )),
              SafeArea(child: Column(children: [
                // Topbar
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 16, 36, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${_currentIndex + 1} of ${_pages.length}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                    TextButton(onPressed: widget.onFinished,
                        child: const Text('Skip for now', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                  ]),
                ),
                // PageView
                Expanded(child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => _webPage(_pages[i]),
                )),
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 12, 36, 28),
                  child: Row(children: [
                    Row(children: List.generate(_pages.length, (i) {
                      final active = _currentIndex == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 26 : 8, height: 8,
                        decoration: BoxDecoration(
                          color: active ? p.accentColor : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    })),
                    const Spacer(),
                    if (_currentIndex > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: OutlinedButton.icon(
                          onPressed: () => _controller.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic),
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.accentColor, Color.lerp(p.accentColor, const Color(0xFF080F1E), 0.25)!]),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color: p.accentColor.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _nextPage,
                        icon: Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded, size: 17),
                        label: Text(isLast ? 'Get Started' : 'Continue',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _webPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 12, 36, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero row
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, math.sin(_floatCtrl.value * math.pi * 2) * 7),
              child: child,
            ),
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                color: data.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: data.accentColor.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(data.image, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(child: FadeTransition(
            opacity: _fadeCtrl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: data.accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(data.subtitle.toUpperCase(),
                    style: TextStyle(color: data.accentColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 10),
              Text(data.title,
                  style: const TextStyle(color: Color(0xFF0A1628), fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1)),
              const SizedBox(height: 8),
              Text(data.description,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.6)),
            ]),
          )),
        ]),
        const SizedBox(height: 24),

        // Section title
        const Text("What's included",
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 12),

        // Feature cards
        Row(children: List.generate(data.webFeatures.length, (i) {
          final f = data.webFeatures[i];
          return Expanded(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${data.title}_$i'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + i * 100),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(opacity: v,
                  child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child)),
              child: Container(
                margin: EdgeInsets.only(right: i < data.webFeatures.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: data.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(f.icon, color: data.accentColor, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(f.title, style: const TextStyle(color: Color(0xFF0A1628), fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(f.description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.5)),
                ]),
              ),
            ),
          );
        })),
        const SizedBox(height: 18),

        // Stats strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF080F1E),
              Color.lerp(const Color(0xFF080F1E), data.accentColor, 0.2)!,
            ]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _stat('10K+', 'Orders Done'),
            _statDiv(),
            _stat('4.9★', 'Avg Rating'),
            _statDiv(),
            _stat('48h', 'Turnaround'),
            _statDiv(),
            _stat('100%', 'Satisfaction'),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(l, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  Widget _statDiv() => Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15));

  Widget _trustBadge(IconData icon, String text) => Row(children: [
    Icon(icon, size: 12, color: const Color(0xFFF5C518)),
    const SizedBox(width: 7),
    Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  // ══════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ══════════════════════════════════════════════════════════
  Widget _mobileLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLast = _currentIndex == _pages.length - 1;
    final p = _pages[_currentIndex];

    return Scaffold(
      body: Stack(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [p.accentColor.withValues(alpha: 0.2), const Color(0xFF0D47A1), p.accentColor.withValues(alpha: 0.3)],
          )),
        ),
        ...List.generate(8, (i) => AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, child) {
            final off = math.sin((_floatCtrl.value * 2 * math.pi) + (i * 0.5)) * 30;
            return Positioned(
              left: (i % 4) * (size.width / 4) + (i.isEven ? off : -off),
              top: (i ~/ 4) * (size.height / 2) + off * 2,
              child: Opacity(opacity: 0.1, child: Container(
                width: 60 + (i * 10).toDouble(), height: 60 + (i * 10).toDouble(),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
              )),
            );
          },
        )),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('LAUNDRIFY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ]),
              ),
              GestureDetector(
                onTap: widget.onFinished,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ]),
          ),
          Expanded(child: PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _mobilePage(_pages[i]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) {
                final active = _currentIndex == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)] : null,
                  ),
                );
              })),
              const SizedBox(height: 20),
              Row(children: [
                AnimatedOpacity(
                  opacity: _currentIndex > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: _currentIndex == 0,
                    child: GestureDetector(
                      onTap: () { if (_currentIndex > 0) _controller.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic); },
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _nextPage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.15)]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(isLast ? 'Get Started' : 'Continue',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      const SizedBox(width: 8),
                      Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: isLast ? 18 : 16),
                    ])),
                  ),
                )),
              ]),
            ]),
          ),
        ])),
      ]),
    );
  }

  Widget _mobilePage(OnboardingData data) {
    return LayoutBuilder(builder: (context, constraints) {
      final availH = constraints.maxHeight;
      return FadeTransition(
        opacity: _fadeCtrl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(height: availH * 0.04),
            ScaleTransition(
              scale: CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutBack),
              child: AnimatedBuilder(
                animation: _floatCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, math.sin(_floatCtrl.value * math.pi * 2) * 10), child: child),
                child: Container(
                  height: availH * 0.38, width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [BoxShadow(color: data.accentColor.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 15))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, data.accentColor.withValues(alpha: 0.2)],
                      ))),
                      Image.asset(data.image, fit: BoxFit.contain),
                    ]),
                  ),
                ),
              ),
            ),
            SizedBox(height: availH * 0.03),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(data.subtitle.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 10),
            Text(data.title, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: (availH * 0.045).clamp(22.0, 32.0),
                    fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2)),
            const SizedBox(height: 8),
            Text(data.description, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9),
                    fontSize: (availH * 0.022).clamp(12.0, 16.0), fontWeight: FontWeight.w400, height: 1.5)),
          ]),
        ),
      );
    });
  }
}

class WebFeature {
  final String title, description;
  final IconData icon;
  const WebFeature(this.title, this.description, this.icon);
}

class OnboardingData {
  final String image, title, subtitle, description;
  final Color accentColor;
  final IconData iconData;
  final List<WebFeature> webFeatures;

  const OnboardingData({
    required this.image, required this.title, required this.subtitle,
    required this.description, required this.accentColor, required this.iconData,
    this.webFeatures = const [],
  });
}
