// lib/moodcast/moodcast_home_screen.dart

import 'dart:ui'; // Required for ImageFilter (Glass Blur)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // LiquidBackground + isVip
import '../widgets/moodcast_banner.dart';
import '../screens/input_screen.dart';        // Lotto input page
import 'mood_lotto_lab_screen.dart';          // MoodCast Lab screen

// Screens
import 'moodcast_submit_screen.dart';
import 'moodcast_feed_screen.dart';

class MoodCastHomeScreen extends StatefulWidget {
  const MoodCastHomeScreen({super.key});

  @override
  State<MoodCastHomeScreen> createState() => _MoodCastHomeScreenState();
}

class _MoodCastHomeScreenState extends State<MoodCastHomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _entranceController;

  // Supabase mood summary
  double _positivity = 0.5;
  int _totalMoods = 0;
  bool _loading = true;
  bool _loadError = false;

  bool _isGuest = false;

  @override
  void initState() {
    super.initState();

    // 1. Pulse Animation (Breathing Effect)
    // Starts after entrance to give the "Zoom then Pulse" effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      lowerBound: 0.95,
      upperBound: 1.05,
    );

    // 2. Entrance Animation (Slide + Fade + Zoom In)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Sequence: Start Entrance -> Then Start Pulse
    _entranceController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });

    _loadForecastFromSupabase();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadForecastFromSupabase() async {
    try {
      setState(() {
        _loading = true;
        _loadError = false;
      });

      final client = Supabase.instance.client;

      final today = DateTime.now();
      final todayDate =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final rows = await client
          .from('forecast_daily')
          .select()
          .eq('day', todayDate)
          .limit(1);

      if (rows.isEmpty) {
        if(mounted) {
          setState(() {
            _positivity = 0.5;
            _totalMoods = 0;
            _loading = false;
          });
        }
        return;
      }

      // ⭐ NEW SMOOTHER MOOD CALCULATION
      final int positives = rows.first['positives'] ?? 0;
      final int negatives = rows.first['negatives'] ?? 0;

// total number of moods
      final int total = (positives + negatives).clamp(1, 999999);

// raw balance between positive & negative
      final double raw = (positives - negatives) / total;

// convert raw value (-1 → +1) into smooth 0–1 range
      final double ratio = ((raw * 0.5) + 0.5).clamp(0.0, 1.0);

      if (mounted) {
        setState(() {
          _positivity = ratio;
          _totalMoods = total;
          _loading = false;
        });
      }

    } catch (e) {
      if(mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildTopBar(context),

// ⭐ ADD BANNER DIRECTLY UNDER TOP BAR
              // ⭐ GLASS FRAME AROUND AD BANNER
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.03),
                        ],
                      ),
                    ),
                    child: const MoodCastBanner(),  // ⭐ your real banner
                  ),
                ),
              ),

              const SizedBox(height: 12),


              // Animated Title
              _AnimatedEntrance(
                controller: _entranceController,
                delay: 0.1,
                child: _buildTitleRow(),
              ),
              const SizedBox(height: 16),
// ⭐ Floating Info Button (top-right)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _InfoButton(),   // <-- NEW
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadForecastFromSupabase,
                  color: const Color(0xFF00FEFC),
                  backgroundColor: const Color(0xFF050815),
                  edgeOffset: 20,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ⭐ BUTTONS (Smaller text)
                        _AnimatedEntrance(
                          controller: _entranceController,
                          delay: 0.2,
                          child: _GlassTopButtons(isGuest: _isGuest, isVip: isVip),
                        ),
                        const SizedBox(height: 24),

                        // ⭐ MAIN CARD (Zoom into Pulse)
                        _AnimatedEntrance(
                          controller: _entranceController,
                          delay: 0.35,
                          enableScale: true, // Enables the Zoom effect
                          child: _buildMainMoodCard(),
                        ),
                        const SizedBox(height: 32),

                        _AnimatedEntrance(
                          controller: _entranceController,
                          delay: 0.5,
                          child: _buildInfoText(),
                        ),
                        const SizedBox(height: 32),

                        _AnimatedEntrance(
                          controller: _entranceController,
                          delay: 0.6,
                          child: _buildFooter(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // TOP BAR (Badge Removed)
  // -----------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Bouncing Back Button
          _BouncingWidget(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          // Spacer ensures the button stays left even without the right badge
          const Spacer(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // TITLE ROW (Enhanced Glow)
  // -----------------------------------------------------------
  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Glowing Orb - Double Shadow for Intense Glow
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Core intense glow
              BoxShadow(
                color: const Color(0xFF00FEFC).withOpacity(0.9),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              // Outer ambient glow
              BoxShadow(
                color: const Color(0xFF00FEFC).withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00FEFC), Color(0xFFDAF7FF)],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Gradient Shader Text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFDAF7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'MoodCast',
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------
// MAIN CARD — 5 MOOD LEVELS + 10 ROTATING MESSAGES EACH
// -----------------------------------------------------------
  Widget _buildMainMoodCard() {
    final int p = (_positivity * 100).round();
    final int n = 100 - p;

    final int weekNumber = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays ~/ 7;

    // VERY POSITIVE (75–100)
    final List<String> vposMsg = [
      "A strong uplifting energy is spreading through the nation.",
      "Hopefulness is peaking — the day feels genuinely bright.",
      "People feel aligned, connected, and emotionally strong.",
      "A powerful wave of optimism is shaping the national mood.",
      "The country feels energised — confidence is rising.",
      "A vibrant emotional atmosphere — positivity is everywhere.",
      "Many feel inspired — motivation and clarity are high.",
      "A refreshing emotional breakthrough is happening today.",
      "Support, kindness and progress feel more real than ever.",
      "The nation’s emotional pulse is glowing with optimism.",
    ];

    // POSITIVE (56–74)
    final List<String> posMsg = [
      "Optimism is rising — people are finding strength in small wins.",
      "Hope is in the air — gratitude and progress stand out this week.",
      "A bright emotional week — calm, clarity and connection feel stronger.",
      "People are leaning into positivity — support and kindness are more visible.",
      "Energy is lifting — many are feeling more grounded and confident.",
      "A wave of motivation is flowing across the nation.",
      "Good momentum is building — people are moving forward with purpose.",
      "The collective mood is glowing — optimism is naturally spreading.",
      "A refreshing emotional clarity is emerging for many.",
      "Many are finding reasons to smile — even in small moments.",
    ];

    // BALANCED (45–55)
    final List<String> balMsg = [
      "A steady emotional week — highs and lows are balancing out.",
      "The mood is mixed — neither heavy nor overly bright.",
      "A neutral week emotionally — grounded and reflective.",
      "The nation feels centred — emotions are steady and manageable.",
      "A calm middle ground — no major highs or lows.",
      "People are processing — it’s a thoughtful, even-toned day.",
      "Equilibrium is holding — emotions feel stable and measured.",
      "A balanced emotional climate — steady and composed.",
      "Mixed feelings today — but not overwhelming.",
      "A gentle quietness defines the national mood.",
    ];

    // NEGATIVE (30–44)
    final List<String> negMsg = [
      "Pressure is rising — many are feeling worn and taxed.",
      "People are feeling stretched — emotions are running thin.",
      "A tough emotional climate — many are navigating personal strain.",
      "Heavier feelings are surfacing — rest and care are needed.",
      "Emotional reserves feel low — pressure is noticeable.",
      "A challenging week — tension and overwhelm are widespread.",
      "Stress is cutting through the day — many feel unsettled.",
      "The national mood is strained — people need space and support.",
      "Tension is more noticeable today across the nation.",
      "Many are feeling emotionally overloaded — support matters.",
    ];

    // VERY NEGATIVE (0–29)
    final List<String> vnegMsg = [
      "It’s a heavy emotional day — many are carrying more than usual.",
      "The nation feels weighed down — support and patience matter.",
      "A low emotional climate — pressure and fatigue are widespread.",
      "Many feel emotionally drained — today needs gentleness.",
      "The emotional tone feels tough — rest is essential.",
      "A difficult emotional period — people are processing a lot.",
      "The collective mood is at a low point — compassion is key.",
      "Stress and heaviness dominate today’s emotional landscape.",
      "A deeply challenging emotional day for many.",
      "The emotional weight of the nation is noticeably heavy.",
    ];

    String label;
    String text;
    int level = 3; // default balanced

    if (_loading) {
      label = "Loading...";
      text = "Checking today’s MoodCast across the nation.";
    } else if (_loadError) {
      label = "Unable to load";
      text = "Check your connection and pull down to refresh.";
    } else if (_totalMoods == 0) {
      label = "No moods yet";
      text = "Be the first to share how today feels.";
    }
    // NEW MULTI-LEVEL HEADLINES
    else if (p >= 90) {
      label = "Exceptionally Positive";
      text = vposMsg[weekNumber % vposMsg.length];
      level = 5;
    } else if (p >= 80) {
      label = "Strongly Positive";
      text = vposMsg[weekNumber % vposMsg.length];
      level = 5;
    } else if (p >= 70) {
      label = "Mostly Positive";
      text = posMsg[weekNumber % posMsg.length];
      level = 4;
    } else if (p >= 60) {
      label = "Gently Positive";
      text = posMsg[weekNumber % posMsg.length];
      level = 4;
    } else if (p >= 50) {
      label = "Balanced Mood";
      text = balMsg[weekNumber % balMsg.length];
      level = 3;
    } else if (p >= 40) {
      label = "Slightly Negative";
      text = balMsg[weekNumber % balMsg.length];
      level = 3;
    } else if (p >= 30) {
      label = "Noticeably Negative";
      text = negMsg[weekNumber % negMsg.length];
      level = 2;
    } else if (p >= 20) {
      label = "Strong Emotional Pressure";
      text = negMsg[weekNumber % negMsg.length];
      level = 2;
    } else if (p >= 10) {
      label = "Very Low Mood";
      text = vnegMsg[weekNumber % vnegMsg.length];
      level = 1;
    } else {
      label = "Extremely Low Mood";
      text = vnegMsg[weekNumber % vnegMsg.length];
      level = 1;
    }


    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF050815).withOpacity(0.40),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  return Transform.scale(
                    scale: _pulseController.value,
                    child: _buildPulseCircle(p, level),
                  );
                },
              ),
              const SizedBox(height: 24),

              Text(
                "TODAY’S MOOD • VOICES OF THE NATION",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: const Color(0xFF72FFD6),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: const Color(0xFF00FEFC).withOpacity(0.4), blurRadius: 15)
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

              const SizedBox(height: 28),
              _buildVerticalBar(p, n),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPulseCircle(int value, int level) {
    final String text = _loading ? "···" : "$value%";

    // CHAKRA-STYLE FULL 10-LEVEL COLOUR SYSTEM (0–100%)
    List<Color> ringOuter;
    List<Color> ringInner;
    Color textGlow;

    // Map 0–100% into 10 bands: 0–9, 10–19, ..., 90–100
    final int colourLevel = (value ~/ 10).clamp(0, 9);

    switch (colourLevel) {
      case 9: // 90–100% — Crown (violet / white)
        ringOuter = [Color(0xFFE4B7FF), Color(0xFFC77DFF), Color(0xFFFFFFFF)];
        ringInner = [Color(0xFFE4B7FF), Color(0xFFC77DFF)];
        textGlow = Color(0xFFE4B7FF);
        break;

      case 8: // 80–89% — Third Eye (indigo)
        ringOuter = [Color(0xFF6E44FF), Color(0xFF8F73FF), Color(0xFFB8A4FF)];
        ringInner = [Color(0xFF6E44FF), Color(0xFF8F73FF)];
        textGlow = Color(0xFF8F73FF);
        break;

      case 7: // 70–79% — Throat (blue)
        ringOuter = [Color(0xFF4DA3FF), Color(0xFF7BC9FF), Color(0xFFBEE8FF)];
        ringInner = [Color(0xFF4DA3FF), Color(0xFF7BC9FF)];
        textGlow = Color(0xFF7BC9FF);
        break;

      case 6: // 60–69% — Heart (green)
        ringOuter = [Color(0xFF6EFFA5), Color(0xFF5DFFCE), Color(0xFFD1FFF1)];
        ringInner = [Color(0xFF6EFFA5), Color(0xFF5DFFCE)];
        textGlow = Color(0xFF5DFFCE);
        break;

      case 5: // 50–59% — Solar Plexus (yellow)
        ringOuter = [Color(0xFFFFF36E), Color(0xFFFFE84D), Color(0xFFFFFFA1)];
        ringInner = [Color(0xFFFFF36E), Color(0xFFFFE84D)];
        textGlow = Color(0xFFFFE84D);
        break;

      case 4: // 40–49% — Sacral (orange)
        ringOuter = [Color(0xFFFFB85C), Color(0xFFFF9A3C), Color(0xFFFFD6AD)];
        ringInner = [Color(0xFFFFB85C), Color(0xFFFF9A3C)];
        textGlow = Color(0xFFFF9A3C);
        break;

      case 3: // 30–39% — Root shift (red–orange)
        ringOuter = [Color(0xFFFF7A5C), Color(0xFFFF5A3C), Color(0xFFFFB7A1)];
        ringInner = [Color(0xFFFF7A5C), Color(0xFFFF5A3C)];
        textGlow = Color(0xFFFF7A5C);
        break;

      case 2: // 20–29% — Deep root (red)
        ringOuter = [Color(0xFFFF4B55), Color(0xFFFF2A3C), Color(0xFFFF9499)];
        ringInner = [Color(0xFFFF4B55), Color(0xFFFF2A3C)];
        textGlow = Color(0xFFFF4B55);
        break;

      case 1: // 10–19% — Heavy (dark red)
        ringOuter = [Color(0xFFC20034), Color(0xFFE00039), Color(0xFFFF728D)];
        ringInner = [Color(0xFFC20034), Color(0xFFE00039)];
        textGlow = Color(0xFFE00039);
        break;

      default: // 0–9% — Survival (deep crimson)
        ringOuter = [Color(0xFF5A001E), Color(0xFF7A0030), Color(0xFF9A003B)];
        ringInner = [Color(0xFF5A001E), Color(0xFF7A0030)];
        textGlow = Color(0xFF7A0030);
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow based on first ring colour
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ringOuter.first.withOpacity(0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Gradient Ring
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ringOuter.first.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            gradient: SweepGradient(
              colors: ringOuter,
            ),
          ),
        ),

        // Inner core
        Container(
          width: 108,
          height: 108,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF050815),
          ),
          child: Center(
            child: FittedBox(
              child: Text(
                text,
                style: GoogleFonts.orbitron(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  shadows: [
                    Shadow(
                      color: textGlow.withOpacity(0.8),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildVerticalBar(int pos, int neg) {
    final double fraction = pos.clamp(0, 100) / 100.0;

    return Column(
      children: [
        Container(
          width: 16,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 0.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              FractionallySizedBox(
                heightFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00FEFC).withOpacity(0.5), blurRadius: 10)
                    ],
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF00FEFC), Color(0xFF72FFD6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot("Positive", const Color(0xFF00FEFC)),
            const SizedBox(width: 20),
            _legendDot("Negative", const Color(0xFFFF4B7D)),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String name, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 8)]
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------
  // FOOTER TEXT + INFO
  // -----------------------------------------------------------
  Widget _buildInfoText() {
    return Column(
      children: [
        Text(
          "A daily emotional forecast of the nation.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Every shared mood • positive or negative • shifts today’s Mood Pulse.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            height: 1.5,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Divider(color: Colors.white.withOpacity(0.1), thickness: 0.5),
        ),
        const SizedBox(height: 20),

        // FIXED: Using Flexible to prevent overflow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AILottoXInputScreen()),
                    );
                  },
                  child: Text(
                    "AI Lotto X",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),

              Text(
                "  •  ",
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
              ),

              Flexible(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MoodLottoLabScreen()),
                    );
                  },
                  child: Text(
                    "MoodCast",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// -----------------------------------------------------------
// ANIMATED ENTRANCE WRAPPER
// Added Scale capability for the "Zoom" effect
// -----------------------------------------------------------
class _AnimatedEntrance extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;
  final bool enableScale; // Trigger for the zoom effect

  const _AnimatedEntrance({
    required this.controller,
    required this.delay,
    required this.child,
    this.enableScale = false,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );

    Widget widget = FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15), // Slide up from bottom
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );

    // ⭐ Only scale WHILE the animation is running
    if (enableScale && controller.value < 1.0) {
      widget = ScaleTransition(
        scale: Tween<double>(begin: 0.90, end: 1.0).animate(curve),
        child: widget,
      );
    }


    return widget;
  }
}

// -----------------------------------------------------------
// TOP GLASS BUTTONS
// -----------------------------------------------------------
class _GlassTopButtons extends StatelessWidget {
  final bool isGuest;
  final bool isVip;

  const _GlassTopButtons({required this.isGuest, required this.isVip});

  void _showGuestPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF050815).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Sign in to share",
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Guests can view the national mood, but only members can submit.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _BouncingWidget(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "OK",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF72FFD6),
                          ),
                        ),
                      ),
                    )
                  ]
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BouncingWidget(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MoodCastFeedScreen(),
              ),
            );
          },
          child: _GlassTopBox(
            child: _GlassButtonContent(
              title: "View Today’s Mood Feed",
              subtitle: "Swipe through the nation’s mood",
              icon: Icons.auto_awesome_motion_rounded,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _BouncingWidget(
          onTap: () {
            if (isGuest) {
              _showGuestPopup(context);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MoodCastSubmitScreen(),
              ),
            );
          },
          child: _GlassTopBox(
            child: _GlassButtonContent(
              title: "Share Your Mood",
              subtitle: isGuest ? "Sign in required" : isVip ? "VIP: unlimited posts" : "Guests: one post per day",
              icon: Icons.mood_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// GLASS WRAPPER BOX
// -----------------------------------------------------------
class _GlassTopBox extends StatelessWidget {
  final Widget child;

  const _GlassTopBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.03),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}


// -----------------------------------------------------------
// GLASS BUTTON CONTENT (Smaller Fonts)
// -----------------------------------------------------------
class _GlassButtonContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _GlassButtonContent({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      color: Colors.black.withOpacity(0.05), // Hit box
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FEFC).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: -2,
                )
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFF00FEFC), Color(0xFF72FFD6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF050815)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FIXED: Smaller font size and multiline
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11, // Reduced from 12
                    color: Colors.white.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 14,
          ),
        ],
      ),
    );
  }
}
class _InfoButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const _InfoPanel(),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
              color: Colors.white.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFF050815).withOpacity(0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                Text(
                  "What Is MoodCast?",
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDAF7FF),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  "MoodCast isn’t a normal social network.\n\n"
                      "There are no followers. No private feeds. No pressure.\n\n"
                      "Here, every single mood shapes the emotional climate of the nation. "
                      "When you share how you feel, you instantly shift today’s National Mood Score.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  "How It Works",
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF72FFD6),
                  ),
                ),
                const SizedBox(height: 12),

                _infoBullet("Share your mood — positive or negative."),
                _infoBullet("Your post immediately affects today’s Mood Pulse."),
                _infoBullet("Swipe the feed to see what the nation feels right now."),
                _infoBullet("Like, Warm, Lift or Impact posts to show support."),
                _infoBullet("Post images or videos — express yourself freely."),
                _infoBullet("Guests can view only — members can post — VIPs unlock deeper insights."),

                const SizedBox(height: 26),

                Text(
                  "Why It’s Different",
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF72FFD6),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  "MoodCast is built around feeling, not following.\n"
                      "Every voice contributes equally. Together we shape the emotional story of the day.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),

                const SizedBox(height: 30),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FEFC),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Got It",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
Widget _infoBullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 6, color: const Color(0xFF00FEFC)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withOpacity(0.82),
            ),
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------
// REACTIVE BOUNCING WIDGET
// -----------------------------------------------------------
class _BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingWidget({required this.child, required this.onTap});

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: widget.child,
        ),
      ),
    );
  }
}