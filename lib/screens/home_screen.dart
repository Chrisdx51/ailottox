// 🧬 AILottoX — Home Screen v7.1 (HyperGlass Button Edition)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import './input_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';  // ⭐ Needed for MethodChannel
import 'package:ai_lotto_generator/ad_ids.dart';
import './vip_paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoGlowController;
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();

    _logoGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )
      ..repeat(reverse: true);
    // ⭐ Load Banner Ad (VIP-safe)
    if (!isVip) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdIds.bannerTop,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            setState(() {
              _isBannerReady = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
        request: const AdRequest(),
      )
        ..load();
    }
  }


  @override
  void dispose() {
    _logoGlowController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Column(
          children: [

            // ⭐ Banner Ad at the TOP (VIP-safe)
            if (!isVip && _isBannerReady)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),

            // ⭐ Main Home Screen content
            Expanded(
              child: Stack(
                children: [
                  const _FloatingParticles(),
                  const _DriftingOrb(
                      top: 60, left: 30, size: 140, opacity: 0.20),
                  const _DriftingOrb(
                      bottom: 80, right: 40, size: 180, opacity: 0.18),
                  const _GlassShimmer(),

                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        child: _GlassPanel(glowController: _logoGlowController),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⭐ MAGIC GLASS PANEL
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final AnimationController glowController;

  const _GlassPanel({required this.glowController});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🟦 Breathing Logo
              ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.06)
                    .animate(CurvedAnimation(parent: glowController, curve: Curves.easeInOut)),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FEFC).withOpacity(0.45),
                        blurRadius: 35,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset("assets/images/logo1.png", fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ⭐ Updated App Name
              Text(
                'AI Lotto X',
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: const Color(0xFFDAF7FF),
                ),
              ),
              if (isVip)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00FEFC).withOpacity(0.45),
                        const Color(0xFF72FFD6).withOpacity(0.35),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "VIP Member",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              Text(
                'Your name. Your date of birth. Your energy.\nAI Lotto X blends them to forge your personalised\nlucky number sequence.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.42,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),


              const SizedBox(height: 30),

              const _HyperGlassButton(),
              SizedBox(height: 14),

              VipUpgradeButton(isVip: isVip),
              SizedBox(height: 16),


              GestureDetector(
                onTap: () async {
                  const platform = MethodChannel("consent_channel");
                  await platform.invokeMethod("showConsentForm");
                },
                child: Text(
                  "Manage Consent",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.75),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Numbers are for entertainment only.\nNo guarantees or predictions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 6,
                  height: 1.3,
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// ⭐ VIP UPGRADE BUTTON (Large, Premium & Attractive)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// ⭐ VIP UPGRADE / MANAGE SUBSCRIPTION BUTTON
// ---------------------------------------------------------------------------

class VipUpgradeButton extends StatelessWidget {
  final bool isVip;
  const VipUpgradeButton({required this.isVip});

  // ⭐ Opens subscription management on Android
  Future<void> _openAndroidSubscription() async {
    const url = "https://play.google.com/store/account/subscriptions";
    await SystemChannels.platform.invokeMethod<void>(
      'SystemNavigator.openExternalUrl',
      url,
    );
  }

  // ⭐ Opens subscription management on iOS
  Future<void> _openIosSubscription() async {
    const url = "itms-apps://apps.apple.com/account/subscriptions";
    await SystemChannels.platform.invokeMethod<void>(
      'SystemNavigator.openExternalUrl',
      url,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!isVip) {
          // ⭐ Non-VIP → Go to Paywall
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
          );
        } else {
          // ⭐ VIP → Manage Subscription
          if (Theme.of(context).platform == TargetPlatform.iOS) {
            await _openIosSubscription();
          } else {
            await _openAndroidSubscription();
          }
        }
      },
      child: Stack(
        children: [
          // ⭐ Outer Glow
          Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00FEFC).withOpacity(0.55),
                  const Color(0xFF72FFD6).withOpacity(0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FEFC).withOpacity(0.45),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          // ⭐ Inner Glass Layer
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    isVip ? "Manage VIP Subscription" : "✨ Upgrade to VIP",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// ⭐ HYPERGLASS BUTTON
// ---------------------------------------------------------------------------

class _HyperGlassButton extends StatefulWidget {
  const _HyperGlassButton();

  @override
  State<_HyperGlassButton> createState() => _HyperGlassButtonState();
}

class _HyperGlassButtonState extends State<_HyperGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController =
    AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (_, __) {
        return Stack(
          children: [
            // ⭐ Outer glow
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: isVip
                    ? LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                boxShadow: [
                  BoxShadow(
                    color: isVip
                        ? const Color(0xFF00FEFC).withOpacity(0.70)
                        : const Color(0xFF00FEFC).withOpacity(0.45),
                    blurRadius: isVip ? 50 : 35,
                    spreadRadius: isVip ? 12 : 8,
                  ),
                ],
              ),
            ),

            // ⭐ Inner Glass
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      width: 1.2,
                      color: Colors.white.withOpacity(0.25),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),

                  child: Stack(
                    children: [
                      // ⭐ Moving shine
                      Positioned(
                        left: _shineController.value * 280 - 100,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.22),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Center(
                        child: Text(
                          "Start Your AILottoX",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ⭐ Tap detector
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AILottoXInputScreen(),
                    ),
                  );
                },
              ),
            ),

          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ⭐ PARTICLE + ORB + SHIMMER SYSTEM
// ---------------------------------------------------------------------------

class _FloatingParticles extends StatefulWidget {
  const _FloatingParticles();

  @override
  State<_FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<_FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _ParticlePainter(_controller.value),
          child: Container(),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isVip
          ? const Color(0xFF00FEFC).withOpacity(0.18)
          : Colors.white.withOpacity(0.10);

    for (int i = 0; i < 38; i++) {
      final dx = (size.width / 38) * i + (progress * 12);
      final dy = (size.height / 40) * (i * 0.6) + (progress * 8);
      canvas.drawCircle(Offset(dx % size.width, dy % size.height), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class _DriftingOrb extends StatelessWidget {
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double size;
  final double opacity;

  const _DriftingOrb({
    super.key,
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(seconds: 18),
      curve: Curves.easeInOut,
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF00FEFC).withOpacity(opacity),
              const Color(0xFF72FFD6).withOpacity(opacity * 0.7),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassShimmer extends StatefulWidget {
  const _GlassShimmer();

  @override
  State<_GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<_GlassShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(_controller.value * 250 - 125, 0),
          child: Container(
            width: 80,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
