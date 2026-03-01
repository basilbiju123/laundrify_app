import 'package:flutter/material.dart';
import 'dart:math' as math;

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

  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _scaleController;

  final List<OnboardingData> _pages = [
    OnboardingData(
      image: 'assets/images/onboard1.png',
      title: 'Schedule Pickup',
      subtitle: 'On Your Time',
      description:
          'Book pickups at your convenience—punctual, professional, and always on point!',
      accentColor: const Color(0xFF42A5F5),
      iconData: Icons.access_time_rounded,
    ),
    OnboardingData(
      image: 'assets/images/onboard2.png',
      title: 'Premium Services',
      subtitle: 'Expert Care',
      description:
          'From washing to expert dry cleaning—maintaining the fabulous quality your clothes deserve.',
      accentColor: const Color(0xFF26C6DA),
      iconData: Icons.local_laundry_service_rounded,
    ),
    OnboardingData(
      image: 'assets/images/onboard3.png',
      title: 'World Class',
      subtitle: 'Complete Solutions',
      description:
          'Dry clean, laundry, shoes, bags, carpets, curtains—we handle it all with care.',
      accentColor: const Color(0xFF66BB6A),
      iconData: Icons.stars_rounded,
    ),
    OnboardingData(
      image: 'assets/images/onboard4.png',
      title: 'Special Offers',
      subtitle: '20% Off First Order',
      description:
          'Get 20% off your first order. Book now for fresh, like-new clothes!',
      accentColor: const Color(0xFFFF7043),
      iconData: Icons.local_offer_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _floatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _scaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeController.forward();
    _scaleController.forward();
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    } else {
      widget.onFinished();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _fadeController.reset();
    _fadeController.forward();
    _scaleController.reset();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLast = _currentIndex == _pages.length - 1;
    final currentPage = _pages[_currentIndex];

    return Scaffold(
      body: Stack(
        children: [
          // ANIMATED GRADIENT BACKGROUND
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  currentPage.accentColor.withValues(alpha: 0.2),
                  const Color(0xFF0D47A1),
                  currentPage.accentColor.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),

          // FLOATING BUBBLES
          ...List.generate(8, (index) {
            return AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final offset = math.sin(
                        (_floatController.value * 2 * math.pi) +
                            (index * 0.5)) *
                    30;
                return Positioned(
                  left: (index % 4) * (size.width / 4) +
                      (index.isEven ? offset : -offset),
                  top: (index ~/ 4) * (size.height / 2) + offset * 2,
                  child: Opacity(
                    opacity: 0.1,
                    child: Container(
                      width: 60 + (index * 10).toDouble(),
                      height: 60 + (index * 10).toDouble(),
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
            );
          }),

          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.local_laundry_service_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          const Text('LAUNDRIFY',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: widget.onFinished,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: const Text('Skip',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),

                // PAGE CONTENT
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) =>
                        _buildPage(_pages[index]),
                  ),
                ),

                // BOTTOM CONTROLS
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // PAGE INDICATORS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (index) {
                          final isActive = _currentIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.white
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // NAVIGATION BUTTONS
                      Row(
                        children: [
                          AnimatedOpacity(
                            opacity: _currentIndex > 0 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: _currentIndex == 0,
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentIndex > 0) {
                                    _controller.previousPage(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                        width: 2),
                                  ),
                                  child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 18),
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          GestureDetector(
                            onTap: _nextPage,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                              width: isLast ? 160 : 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentPage.accentColor
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isLast
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("GET STARTED",
                                              style: TextStyle(
                                                  color:
                                                      currentPage.accentColor,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 0.8)),
                                          const SizedBox(width: 6),
                                          Icon(Icons.arrow_forward_rounded,
                                              color: currentPage.accentColor,
                                              size: 16),
                                        ],
                                      )
                                    : Icon(Icons.arrow_forward_rounded,
                                        color: currentPage.accentColor,
                                        size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return FadeTransition(
      opacity: _fadeController,
      child: LayoutBuilder(builder: (context, constraints) {
        final availH = constraints.maxHeight;
        // Responsive image height: 35–45% of available height
        final imgH = (availH * 0.40).clamp(180.0, 320.0);
        final iconSize = (availH * 0.06).clamp(28.0, 40.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ICON BADGE
              ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                    CurvedAnimation(
                        parent: _scaleController,
                        curve: Curves.elasticOut)),
                child: Container(
                  padding: EdgeInsets.all(iconSize * 0.45),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: data.accentColor.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5)
                    ],
                  ),
                  child: Icon(data.iconData,
                      color: Colors.white, size: iconSize),
                ),
              ),

              SizedBox(height: availH * 0.03),

              // IMAGE
              Container(
                height: imgH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: data.accentColor.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                        spreadRadius: 5)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              data.accentColor.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                      Image.asset(data.image, fit: BoxFit.contain),
                    ],
                  ),
                ),
              ),

              SizedBox(height: availH * 0.03),

              // SUBTITLE
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  data.subtitle.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
              ),

              const SizedBox(height: 10),

              // TITLE
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (availH * 0.045).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // DESCRIPTION
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: (availH * 0.022).clamp(12.0, 16.0),
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String subtitle;
  final String description;
  final Color accentColor;
  final IconData iconData;

  OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentColor,
    required this.iconData,
  });
}
