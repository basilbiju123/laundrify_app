import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _hNavy = Color(0xFF080F1E);
const _hNavyMid = Color(0xFF0D1F3C);
const _hBlue = Color(0xFF1B4FD8);
const _hGold = Color(0xFFF5C518);
const _hGreen = Color(0xFF10B981);
const _hSurface = Color(0xFFF0F4FF);
const _hDark = Color(0xFF0A1628);
const _hMid = Color(0xFF475569);
const _hFade = Color(0xFF94A3B8);

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  // Contact info — loaded from Firestore settings/app, fallback to defaults
  String _phone = '+919876543210';
  String _email = 'support@laundrify.com';
  String _facebook = 'https://facebook.com';
  String _instagram = 'https://instagram.com';
  String _youtube = 'https://youtube.com';
  String _workingHours = '8 AM – 10 PM daily';

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _phone        = d['supportPhone']   ?? _phone;
          _email        = d['supportEmail']   ?? _email;
          _facebook     = d['facebookUrl']    ?? _facebook;
          _instagram    = d['instagramUrl']   ?? _instagram;
          _youtube      = d['youtubeUrl']     ?? _youtube;
          _workingHours = d['workingHours']   ?? _workingHours;
        });
      }
    } catch (_) {
      // Silently fall back to defaults
    }
  }

  final List<Map<String, dynamic>> _faqs = [
    {
      'q': 'How do I place an order?',
      'a': 'Select a service from the dashboard (Laundry, Dry Clean, etc.), add items to your cart, then proceed to checkout. Schedule a pickup time and choose your payment method.',
      'isOpen': false,
    },
    {
      'q': 'What is the pickup and delivery timeline?',
      'a': 'Standard orders are picked up within 24 hours of booking and delivered within 2-3 business days. Express service is available for same-day or next-day delivery.',
      'isOpen': false,
    },
    {
      'q': 'How is pricing calculated?',
      'a': 'Pricing is per-item based on the service type. A delivery fee of ₹40 and 18% GST are added to the subtotal. You can view the full bill breakdown in the order summary.',
      'isOpen': false,
    },
    {
      'q': 'Can I track my order?',
      'a': 'Yes! Once your order is placed, you can track it in real-time from your dashboard. You\'ll see status updates: Pickup → Processing → Delivery.',
      'isOpen': false,
    },
    {
      'q': 'What payment methods are accepted?',
      'a': 'We accept UPI (Google Pay, PhonePe, Paytm), Credit/Debit Cards, Net Banking, Digital Wallets, and Cash on Delivery.',
      'isOpen': false,
    },
    {
      'q': 'How do I cancel or modify an order?',
      'a': 'Orders can be cancelled or modified up to 2 hours before the scheduled pickup time. Contact our support team via WhatsApp or phone for assistance.',
      'isOpen': false,
    },
    {
      'q': 'What if my items are damaged?',
      'a': 'We take the utmost care of your garments. In the rare case of damage, please contact us within 24 hours of delivery with photos. We cover damage up to ₹5,000 per order.',
      'isOpen': false,
    },
    {
      'q': 'How do I change my delivery address?',
      'a': 'Go to your Profile → Saved Addresses, or update your location from the dashboard. You can add Home, Office, and Other address types.',
      'isOpen': false,
    },
  ];

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open this link'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('$label copied to clipboard'),
      ]),
      backgroundColor: _hGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_hNavy, _hNavyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        title: const Text('Help & Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_hNavy, _hNavyMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                left: 22,
                right: 22,
                bottom: 30,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: _hGold, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('How can we help you?',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('We\'re here 24/7 for all your laundry needs',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── Contact Options ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Contact Us'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _contactCard(
                        icon: Icons.phone_rounded,
                        label: 'Call Us',
                        value: _phone.replaceFirst('+91', '+91 '),
                        color: const Color(0xFF059669),
                        onTap: () => _launchUrl('tel:$_phone'),
                        onLongPress: () => _copyToClipboard(_phone, 'Phone number'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _contactCard(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        value: 'Chat with us',
                        color: const Color(0xFF25D366),
                        onTap: () => _launchUrl('https://wa.me/${_phone.replaceAll('+', '').replaceAll(' ', '')}?text=Hello%20Laundrify%20Support'),
                        onLongPress: null,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _contactCard(
                        icon: Icons.email_rounded,
                        label: 'Email Us',
                        value: _email,
                        color: _hBlue,
                        onTap: () => _launchUrl('mailto:$_email'),
                        onLongPress: () => _copyToClipboard(_email, 'Email'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _contactCard(
                        icon: Icons.access_time_rounded,
                        label: 'Working Hours',
                        value: _workingHours,
                        color: _hGold,
                        onTap: null,
                        onLongPress: null,
                      )),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _sectionHeader('Quick Actions'),
                  const SizedBox(height: 12),

                  _actionTile(
                    icon: Icons.track_changes_rounded,
                    label: 'Track My Order',
                    subtitle: 'View real-time order status',
                    color: _hBlue,
                    onTap: () => Navigator.pop(context),
                  ),
                  _actionTile(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel an Order',
                    subtitle: 'Cancel before pickup time',
                    color: const Color(0xFFEF4444),
                    onTap: () => _launchUrl('https://wa.me/${_phone.replaceAll('+', '').replaceAll(' ', '')}?text=I%20want%20to%20cancel%20my%20order'),
                  ),
                  _actionTile(
                    icon: Icons.star_rate_rounded,
                    label: 'Rate Our Service',
                    subtitle: 'Help us improve',
                    color: _hGold,
                    onTap: () => _showRatingDialog(),
                  ),
                  _actionTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report an Issue',
                    subtitle: 'Technical problem? Let us know',
                    color: const Color(0xFFD97706),
                    onTap: () => _launchUrl('mailto:$_email?subject=Issue%20Report'),
                  ),

                  const SizedBox(height: 24),
                  _sectionHeader('Frequently Asked Questions'),
                  const SizedBox(height: 12),

                  ..._faqs.asMap().entries.map((e) => _faqItem(e.key, e.value)),

                  const SizedBox(height: 24),

                  // Social links
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Follow Us', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _hDark)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _socialBtn(icon: Icons.facebook, label: 'Facebook', color: const Color(0xFF1877F2),
                                onTap: () => _launchUrl(_facebook)),
                            const SizedBox(width: 10),
                            _socialBtn(icon: Icons.camera_alt_rounded, label: 'Instagram', color: const Color(0xFFE1306C),
                                onTap: () => _launchUrl(_instagram)),
                            const SizedBox(width: 10),
                            _socialBtn(icon: Icons.play_circle_fill_rounded, label: 'YouTube', color: const Color(0xFFFF0000),
                                onTap: () => _launchUrl(_youtube)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_hBlue, Color(0xFF3B82F6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(10),
      )),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _hDark)),
    ]);
  }

  Widget _contactCard({required IconData icon, required String label, required String value,
      required Color color, VoidCallback? onTap, VoidCallback? onLongPress}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _hDark)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 11.5, color: _hMid), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required String subtitle,
      required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _hDark)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _hFade)),
          ])),
          Icon(Icons.chevron_right_rounded, color: _hFade, size: 20),
        ]),
      ),
    );
  }

  Widget _faqItem(int index, Map<String, dynamic> faq) {
    final isOpen = faq['isOpen'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? _hBlue.withValues(alpha: 0.3) : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        onTap: () => setState(() => _faqs[index]['isOpen'] = !isOpen),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _hBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.help_outline_rounded, color: _hBlue, size: 16)),
              const SizedBox(width: 12),
              Expanded(child: Text(faq['q'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _hDark))),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: _hFade, size: 22),
              ),
            ]),
            if (isOpen) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _hSurface, borderRadius: BorderRadius.circular(10)),
                child: Text(faq['a'] as String,
                    style: const TextStyle(fontSize: 13, color: _hMid, height: 1.5))),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _socialBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  void _showRatingDialog() {
    int rating = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setRatingState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Laundrify', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('How would you rate your experience?', style: TextStyle(color: _hMid)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
              icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: i < rating ? _hGold : Colors.grey.shade400, size: 32),
              onPressed: () => setRatingState(() => rating = i + 1),
            ))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: rating > 0 ? () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Thanks for your rating! ⭐'),
                  backgroundColor: _hGold,
                ));
              } : null,
              style: ElevatedButton.styleFrom(backgroundColor: _hNavy, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
