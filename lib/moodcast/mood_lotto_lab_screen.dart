// lib/moodcast/mood_lotto_lab_screen.dart
// ULTRA PREMIUM VERSION + INTERACTIVE FEATURES + HAPTICS + PARALLAX + GESTURES

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../widgets/moodcast_banner.dart';

// Lab room screens
import './stress_lab_screen.dart';
import './weather_lab_screen.dart';
import './decision_lab_screen.dart';
import './lucky_cycle_screen.dart';
import './number_pattern_lab_screen.dart';

// Colours
const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _purpleGlow = Color(0xFF9D4EDD);
const _goldGlow = Color(0xFFFFD700);

class MoodLottoLabScreen extends StatefulWidget {
  const MoodLottoLabScreen({super.key});

  @override
  State<MoodLottoLabScreen> createState() => _MoodLottoLabScreenState();
}

class _MoodLottoLabScreenState extends State<MoodLottoLabScreen>
    with TickerProviderStateMixin {
  late PageController _deckController;
  late AnimationController _pulseController;
  late AnimationController _logoController;
  int _currentPage = 0;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _deckController = PageController(viewportFraction: 0.72);
    _deckController.addListener(() {
      setState(() {
        _currentPage = _deckController.page?.round() ?? 0;
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _deckController.dispose();
    _pulseController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // ===========================================================
  // INTERACTIVE INFO PANEL WITH ANIMATIONS
  // ===========================================================
  void _openInfo() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _purpleGlow.withOpacity(0.15),
                        Colors.white.withOpacity(0.08),
                        _cyanGlow.withOpacity(0.12),
                      ],
                    ),
                    border: Border(
                      top: BorderSide(color: _cyanGlow.withOpacity(0.3), width: 2),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [_cyanGlow, _mintGlow],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Animated Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _cyanGlow.withOpacity(0.3),
                                _purpleGlow.withOpacity(0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cyanGlow.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.psychology_outlined,
                            size: 40,
                            color: _mintGlow,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "Why Moods Influence Numbers",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _mintGlow,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _InfoSection(
                        icon: Icons.favorite_border,
                        title: "Emotional Intelligence",
                        content: "Your emotional state shapes clarity, intuition, risk-taking and how your mind spots patterns.",
                      ),

                      _InfoSection(
                        icon: Icons.pending_actions,
                        title: "Mental Rhythm",
                        content: "As your mood shifts, so does your timing, your mental rhythm and the cycles your brain naturally follows.",
                      ),

                      _InfoSection(
                        icon: Icons.insights,
                        title: "Pattern Recognition",
                        content: "The Mood Lotto Lab explores how emotional climate, behavioural loops and your own Number Flow patterns can guide choices in a grounded, meaningful way.",
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================
  // MAIN UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> pages = [
      {
        "label": "A",
        "title": "Emotional Load",
        "subtitle": "How your mind carries pressure, tension and quiet stress beneath the surface.",
        "tag": "Inner weight",
        "icon": Icons.bolt_rounded,
        "screen": const StressLabScreen(),
        "color": _cyanGlow,
      },
      {
        "label": "B",
        "title": "Mood & Atmosphere",
        "subtitle": "How light, weather and shifting environments shape your emotional climate.",
        "tag": "Environment influence",
        "icon": Icons.cloud_rounded,
        "screen": const WeatherLabScreen(),
        "color": _mintGlow,
      },
      {
        "label": "C",
        "title": "Clarity Moments",
        "subtitle": "Your natural peaks of focus, intuition and timing — when decisions land best.",
        "tag": "Mental rhythm",
        "icon": Icons.timelapse_rounded,
        "screen": const DecisionLabScreen(),
        "color": _purpleGlow,
      },
      {
        "label": "D",
        "title": "Rhythm Loops",
        "subtitle": "Repeating emotional and motivational cycles that guide energy, action and flow.",
        "tag": "Behaviour patterning",
        "icon": Icons.sync_rounded,
        "screen": const LuckyCycleScreen(),
        "color": _goldGlow,
      },
      {
        "label": "E",
        "title": "Number Flow",
        "subtitle": "How your personal cycles shape number preference, repetition and timing.",
        "tag": "Pattern instinct",
        "icon": Icons.grid_view_rounded,
        "screen": const NumberPatternLabScreen(),
        "color": _cyanGlow,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidBackground(
        child: SafeArea(
          child: Stack(
            children: [
              _AuroraWaves(scrollOffset: _scrollOffset),
              FloatingParticles(count: 35, scrollOffset: _scrollOffset),

              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  setState(() {
                    _scrollOffset = notification.metrics.pixels;
                  });
                  return true;
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // AD BANNER
                      if (!isVip) ...[
                        const MoodCastBanner(),
                        const SizedBox(height: 10),
                      ],

                      // ANIMATED LOGO WITH PULSE
                      Center(
                        child: AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: math.sin(_logoController.value * math.pi * 2) * 0.05,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyanGlow.withOpacity(0.3 + _pulseController.value * 0.2),
                                      blurRadius: 35 + _pulseController.value * 15,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: Image.asset("assets/images/logo1.png"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // TITLE + INFO WITH SHIMMER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // Text now wrapped safely
                            Flexible(
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [_cyanGlow, _mintGlow, _cyanGlow],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "Mood Lotto Lab",
                                    style: GoogleFonts.orbitron(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Info button untouched
                            GestureDetector(
                              onTap: _openInfo,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _cyanGlow.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: _cyanGlow.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: _mintGlow,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),


                      const SizedBox(height: 18),

                      // ANIMATED LAB BADGE
                      const _LabBadge(),
                      const SizedBox(height: 24),

                      // INTRO TEXT WITH GRADIENT
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [_mintGlow, Colors.white],
                              ).createShader(bounds),
                              child: Text(
                                "Understand Your Patterns",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.orbitron(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "This Lab reveals the hidden daily cycles that affect clarity, stress, timing, mood and behaviour.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                height: 1.4,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // PAGE INDICATOR
                      _PageIndicator(
                        count: pages.length,
                        currentIndex: _currentPage,
                        colors: pages.map((p) => p["color"] as Color).toList(),
                      ),

                      const SizedBox(height: 20),

                      // ENHANCED CAROUSEL
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.58,
                        child: PageView.builder(
                          controller: _deckController,
                          itemCount: pages.length,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            HapticFeedback.selectionClick();
                          },
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _deckController,
                              builder: (context, child) {
                                double value = 0.0;

                                if (_deckController.position.haveDimensions) {
                                  value = (_deckController.page! - index);
                                }

                                final double scale = (1 - (value.abs() * 0.22)).clamp(0.82, 1.0);
                                final double tilt = (value * 0.28).clamp(-0.28, 0.28);
                                final double opacity = (1 - value.abs()).clamp(0.5, 1.0);

                                return Center(
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..scale(scale)
                                      ..setEntry(3, 2, 0.0015)
                                      ..rotateY(tilt),
                                    child: Opacity(
                                      opacity: opacity,
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation, secondaryAnimation) =>
                                              pages[index]["screen"] as Widget,
                                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: ScaleTransition(
                                                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                                                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                                                    ),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        child: _PremiumGlassCard(
                                          accentColor: pages[index]["color"] as Color,
                                          child: _CardContent(
                                            label: pages[index]["label"] as String,
                                            title: pages[index]["title"] as String,
                                            subtitle: pages[index]["subtitle"] as String,
                                            tag: pages[index]["tag"] as String,
                                            icon: pages[index]["icon"] as IconData,
                                            accentColor: pages[index]["color"] as Color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // SWIPE HINT (only show on first visit)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 0.3 + _pulseController.value * 0.4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.swipe, color: _mintGlow, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Swipe to explore",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // DISCLAIMER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _cyanGlow.withOpacity(0.2),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.05),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: _goldGlow, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "This Lab reveals real emotional and behavioural patterns you can understand, track and improve.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    height: 1.4,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE INDICATOR
// ============================================================================
class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final List<Color> colors;

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? LinearGradient(colors: [colors[index], colors[index].withOpacity(0.5)])
                : null,
            color: isActive ? null : Colors.white.withOpacity(0.3),
            boxShadow: isActive
                ? [BoxShadow(color: colors[index].withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
        );
      }),
    );
  }
}

// ============================================================================
// INFO SECTION
// ============================================================================
class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_cyanGlow.withOpacity(0.3), _purpleGlow.withOpacity(0.2)],
              ),
              border: Border.all(color: _cyanGlow.withOpacity(0.4)),
            ),
            child: Icon(icon, color: _mintGlow, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _cyanGlow,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARD CONTENT — FIXED (NO OVERFLOWS)
// ============================================================================
class _CardContent extends StatelessWidget {
  final String label, title, subtitle, tag;
  final IconData icon;
  final Color accentColor;

  const _CardContent({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.78,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.8), width: 2),
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.6), accentColor.withOpacity(0.3)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [accentColor.withOpacity(0.3), Colors.transparent],
                  ),
                ),
                child: Icon(icon, size: 32, color: accentColor),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // TITLE — NO MORE OVERFLOW
          Flexible(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, accentColor.withOpacity(0.8)],
              ).createShader(bounds),
              child: Text(
                title,
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // SUBTITLE — SAFE, NO VERTICAL PUSH
          Flexible(
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.white.withOpacity(0.88),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),

          const SizedBox(height: 12),

          // TAG PILL — NO SIDE OVERFLOW
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.60,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentColor.withOpacity(0.6)),
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.15),
                    accentColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: accentColor.withOpacity(0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}


// ============================================================================
// PREMIUM GLASS CARD
// ============================================================================
class _PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;

  const _PremiumGlassCard({required this.child, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: accentColor.withOpacity(0.35),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.22),
                Colors.white.withOpacity(0.08),
                accentColor.withOpacity(0.08),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// AURORA WAVES WITH PARALLAX
// ============================================================================
class _AuroraWaves extends StatelessWidget {
  final double scrollOffset;
  const _AuroraWaves({required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 30),
        builder: (context, value, child) {
          final parallax = scrollOffset * 0.3;
          return Transform.translate(
            offset: Offset(0, -parallax),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.6 + value * 0.3),
                  radius: 2.6,
                  colors: [
                    _purpleGlow.withOpacity(0.08),
                    _mintGlow.withOpacity(0.06),
                    Colors.transparent,
                    _cyanGlow.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: child,
              ),
            ),
          );
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ============================================================================
// FLOATING PARTICLES WITH PARALLAX
// ============================================================================
class FloatingParticles extends StatefulWidget {
  final int count;
  final double scrollOffset;
  const FloatingParticles({required this.count, required this.scrollOffset, super.key});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.count, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(seconds: 10 + (i % 9)),
      )..repeat();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rnd = math.Random(42);
    final parallax = widget.scrollOffset * 0.2;

    return IgnorePointer(
      child: Stack(
        children: List.generate(widget.count, (i) {
          final c = _controllers[i];
          final colors = [_cyanGlow, _mintGlow, _purpleGlow, _goldGlow];
          final particleColor = colors[i % colors.length];

          return AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final t = c.value;
              final x = math.sin(t * math.pi * 2 + i) * size.width * 0.35 +
                  size.width * (rnd.nextDouble() * 0.25 - 0.125);
              final y = t * size.height * 1.8 - size.height * 0.3 - parallax * 0.5;

              final scale = 0.5 + math.sin(t * math.pi * 5) * 0.35;

              return Transform.translate(
                offset: Offset(x, y),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          particleColor.withOpacity(0.95),
                          particleColor.withOpacity(0.3),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: particleColor.withOpacity(0.8),
                          blurRadius: 16,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ============================================================================
// LAB BADGE
// ============================================================================
class _LabBadge extends StatefulWidget {
  const _LabBadge();

  @override
  State<_LabBadge> createState() => _LabBadgeState();
}

class _LabBadgeState extends State<_LabBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a;

  @override
  void initState() {
    super.initState();
    _a = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final glow = 12 + _a.value * 12;

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _cyanGlow.withOpacity(0.7),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      _cyanGlow.withOpacity(0.15),
                      _purpleGlow.withOpacity(0.08),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyanGlow.withOpacity(0.5),
                      blurRadius: glow,
                      spreadRadius: glow * 0.35,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, size: 17, color: _mintGlow),
                    const SizedBox(width: 7),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [_cyanGlow, _mintGlow],
                      ).createShader(bounds),
                      child: Text(
                        "Lab",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
        );
      },
    );
  }
}