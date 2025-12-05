// 🧬 AILottoX — Home Screen v8.0 (with MoodCast Mini tile)
import 'dart:async';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import './input_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart'; // ⭐ Needed for MethodChannel
import 'package:ai_lotto_generator/ad_ids.dart';
import './vip_paywall_screen.dart';
import 'package:ai_lotto_generator/moodcast/moodcast_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/about_feedback_screen.dart';
import 'package:ai_lotto_generator/moodcast/admin_panel_screen.dart';

void _logoutHandler(BuildContext context) {
  final state = context.findAncestorStateOfType<_HomeScreenState>();
  state?._logout();
}

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

  // ⭐ Mood score for gauges
  double _moodScore = 50; // default center
  bool _loadingMood = false;
  double _liveMoodScore = 50; // default
  Timer? _moodTimer;

  Future<void> _fetchLiveMood() async {
    final client = Supabase.instance.client;

    final today = DateTime.now();
    final todayDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final rows = await client
        .from('forecast_daily')
        .select('positives, negatives')
        .eq('day', todayDate)
        .limit(1);

    if (rows.isEmpty) {
      setState(() => _liveMoodScore = 50);
      return;
    }

    final int positives = rows.first['positives'] ?? 0;
    final int negatives = rows.first['negatives'] ?? 0;

    final int total = (positives + negatives).clamp(1, 999999);
    final double raw = (positives - negatives) / total;
    final double ratio = ((raw * 0.5) + 0.5).clamp(0.0, 1.0);

    final int percent = (ratio * 100).round();

    setState(() => _liveMoodScore = percent.toDouble());
  }





// Fetch today's mood score from Supabase (forecast_daily)
  Future<void> _loadMoodScore() async {
    try {
      final client = Supabase.instance.client;

      final today = DateTime.now();
      final todayDate =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final row = await client
          .from('forecast_daily')
          .select('score')
          .eq('day', todayDate)
          .maybeSingle();

      if (row != null) {
        final int positives = row['positives'] ?? 0;
        final int negatives = row['negatives'] ?? 0;

        final int total = (positives + negatives).clamp(1, 999999);
        final double raw = (positives - negatives) / total;
        final double ratio = ((raw * 0.5) + 0.5).clamp(0.0, 1.0);

        final int percent = (ratio * 100).round();

        setState(() => _moodScore = percent.toDouble());

      }
    } catch (_) {}
  }


  // ⭐ FULL LOGOUT — ONLY for real accounts (NOT guests)
  Future<void> _logout() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    // If somehow called while on a guest account → do nothing
    final bool isGuest = user?.email
        ?.toLowerCase()
        .endsWith('@guest.ai-lottox.com') ??
        false;

    if (isGuest) {
      // Guest should not be logged out (prevents new guest profiles)
      return;
    }

    // End session for normal accounts
    await client.auth.signOut();

    // Reset VIP flag
    setState(() {
      isVip = false;
    });

    // Go back to LoginScreen and clear navigation stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }


  // ⭐ Checks if GUEST user has a display_name — if not, forces popup
  Future<void> _checkDisplayName() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Read profile (we only care about guests)
    final profile = await client
        .from('profiles')
        .select('display_name, type')
        .eq('id', user.id)
        .maybeSingle();

    final String? name = profile?['display_name'] as String?;
    final String? type = profile?['type'] as String?;

    // ⭐ Guest detection: either type == 'guest' OR guest email domain
    final bool isGuest = type == 'guest' ||
        (user.email?.toLowerCase().endsWith('@guest.ai-lottox.com') ?? false);

    // 👉 Not a guest? (normal email signup) → NEVER show popup
    if (!isGuest) return;

    // 👉 Guest but already has a valid name (3+ chars) → no popup
    if (name != null && name.trim().length >= 3) return;

    // 👉 Guest + missing/short name → force popup
    _showNamePopup();
  }

  Future<void> _checkVip() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final rows = await client
        .from('vip_status')
        .select('vip_active, expires_at')
        .eq('user_id', user.id)
        .eq('app', 'mood_lotto')
        .maybeSingle();

    if (rows == null) {
      setState(() => isVip = false);
      return;
    }

    final bool active = rows['vip_active'] ?? false;
    final DateTime? expiry = rows['expires_at'] != null
        ? DateTime.tryParse(rows['expires_at'])
        : null;

    final bool valid = active && (expiry == null || expiry.isAfter(DateTime.now()));

    setState(() => isVip = valid);
  }



  void _showNamePopup() {
    final nameController = TextEditingController();
    final client = Supabase.instance.client;

    showDialog(
      context: context,
      barrierDismissible: false, // cannot tap outside popup
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            final user = client.auth.currentUser;

            final bool isGuest = user?.email
                ?.toLowerCase()
                .endsWith('@guest.ai-lottox.com') ??
                false;

            if (isGuest) {
              // Guest pressing device back → send them back to Login
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
              return false; // we handled navigation ourselves
            }

            // If ever used for a non-guest, let back work normally
            return true;
          },


          child: Dialog(
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Choose Your Display Name",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "This is the name shown in MoodCast.\nMinimum 3 characters.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ⭐ TextField
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Enter name",
                            hintStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ⭐ SAVE BUTTON
                        GestureDetector(
                          onTap: () async {
                            final name = nameController.text.trim();

                            if (name.length < 3) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Name must be at least 3 characters."),
                                ),
                              );
                              return;
                            }

                            final user = client.auth.currentUser;

                            await client
                                .from('profiles')
                                .update({'display_name': name})
                                .eq('id', user!.id);

                            FocusScope.of(context).unfocus();
                            Navigator.pop(context); // close popup
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                              color: Colors.white.withOpacity(0.12),
                            ),
                            child: Text(
                              "Save",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  void initState() {
    super.initState();

    // ⭐ NEW — Check VIP status from Supabase
    _checkVip();

    // ⭐ Load national mood score
    _loadMoodScore();


// Refresh every 20 seconds
    Timer.periodic(const Duration(seconds: 20), (_) {
      _loadMoodScore();
    });

    _fetchLiveMood(); // get first value immediately
    _moodTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchLiveMood());

    // ⭐ NEW — check if user needs a display name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDisplayName();
    });

    _logoGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

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
      )..load();
    }
  }


  @override
  void dispose() {
    _logoGlowController.dispose();
    _bannerAd?.dispose();
    _moodTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: LiquidBackground(
            child: Column(

              children: [
                // ⭐ Banner Ad at the TOP (VIP-safe)
                if (!isVip && _isBannerReady)
                  SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),

                // ⭐ ADMIN BUTTON — ONLY for Chris's master account
                Builder(
                  builder: (context) {
                    final user = Supabase.instance.client.auth.currentUser;

                    // Only show button if logged-in user is Chris
                    const chrisId = "11f44b7d-1972-42a2-bb7c-a9970222b278";

                    if (user == null || user.id != chrisId) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                            color: Colors.white.withOpacity(0.10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings,
                                  color: Colors.white.withOpacity(0.95), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "Open Admin Panel",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                        child:
                        _GlassPanel(
                          glowController: _logoGlowController,
                          liveScore: _liveMoodScore,
                        ),
                      ),
                    ),
                  ),
                ],
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
// ⭐ MAGIC GLASS PANEL (AI Lotto X + MoodCast Mini)
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final AnimationController glowController;
  final double liveScore;

  const _GlassPanel({required this.glowController, required this.liveScore});

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
                scale: Tween(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(
                    parent: glowController,
                    curve: Curves.easeInOut,
                  ),
                ),
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
                    child: Image.asset(
                      "assets/images/logo1.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ⭐ App Name
              Text(
                'MoodLotto X',
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: const Color(0xFFDAF7FF),
                ),
              ),

              // ⭐ VIP badge
              if (isVip)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

              // ⭐ Description (shorter, cleaner, still your exact tone)
              Text(
                'MoodLotto X gives you fresh, personalised number sets in a clean, modern way. '
                    'Every visit feels new and made for the moment.\n\n'
                    'The Vibes brings a lively, live snapshot of the nation — a social, fun space where people share '
                    'how they feel. Explore the mood or jump straight into generating your next Lotto X number set.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
              const SizedBox(height: 12),

              // ⭐ LIVE Feed counter
              const LiveFeedCounter(),

              const SizedBox(height: 20),


              // ⭐ Start AI Lotto X button
              const _HyperGlassButton(),

              const SizedBox(height: 18),

              // ⭐ MoodCast Mini Tile
              MoodCastTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MoodCastHomeScreen(),

                    ),
                  );
                },
              ),

              const SizedBox(height: 18),
              PulseGauge(score: liveScore),

              const SizedBox(height: 18),
              // ⭐ VIP Upgrade / Manage
              VipUpgradeButton(isVip: isVip),

              const SizedBox(height: 16),

// ⭐ detect if guest
              Builder(
                builder: (context) {
                  final user = Supabase.instance.client.auth.currentUser;
                  final bool isGuest = user?.email
                      ?.toLowerCase()
                      .endsWith('@guest.ai-lottox.com') ??
                      false;

                  return Column(
                    children: [
                      // ⭐ SIGN UP BUTTON — only visible for guests
                      if (isGuest)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: Text(
                              "Create Full Account",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),

                      // ⭐ LOGOUT BUTTON — only for registered users
                      if (!isGuest)
                        GestureDetector(
                          onTap: () => _logoutHandler(context),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "Logout",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.75),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
              const SizedBox(height: 18),

// ⭐ ABOUT + FEEDBACK BUTTON
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AboutFeedbackScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "About & Feedback",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

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
// ⭐ VIP UPGRADE / MANAGE SUBSCRIPTION BUTTON
// ---------------------------------------------------------------------------

class VipUpgradeButton extends StatelessWidget {
  final bool isVip;
  const VipUpgradeButton({super.key, required this.isVip});

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
// ⭐ HYPERGLASS BUTTON — START AI LOTTO X
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
// ⭐ MOODCAST TILE — ICON ABOVE TEXT (UPDATED + Tap Hint)
// ---------------------------------------------------------------------------

class MoodCastTile extends StatefulWidget {
  final VoidCallback onTap;
  const MoodCastTile({super.key, required this.onTap});

  @override
  State<MoodCastTile> createState() => _MoodCastTileState();
}

class _MoodCastTileState extends State<MoodCastTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      lowerBound: 0.90,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),

            // ⭐ NEW LAYOUT: ICON ABOVE TEXT + TAP HINT
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ICON ABOVE TEXT
                SizedBox(
                  height: 80,
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/images/moodlog1.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // TITLE
                Text(
                  "MoodCast  Help Shape the Nation’s Mood",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),

                const SizedBox(height: 4),

                // DESCRIPTION
                Text(
                  "Share how you feel today and see the nation’s emotional climate.\n"
                      "Guests can view • Members unlock deeper insight.",
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.80),
                  ),
                ),

                const SizedBox(height: 10),

                // ⭐ TAP TO OPEN HINT (Option A)
                Text(
                  "(Tap to explore today’s mood)",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
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
      ..color =
      isVip ? const Color(0xFF00FEFC).withOpacity(0.18) : Colors.white.withOpacity(0.10);

    for (int i = 0; i < 38; i++) {
      final dx = (size.width / 38) * i + (progress * 12);
      final dy = (size.height / 40) * (i * 0.6) + (progress * 8);
      canvas.drawCircle(
        Offset(dx % size.width, dy % size.height),
        1.6,
        paint,
      );
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
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

// ---------------------------------------------------------------------------
// ⭐ SIMPLE MOODCAST SCREEN (stub, safe & pretty)
// ---------------------------------------------------------------------------

class MoodCastScreen extends StatelessWidget {
  const MoodCastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      "MoodCast Mini",
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: const Color(0xFFDAF7FF),
                      ),
                    ),
                    const SizedBox(width: 40), // balance
                  ],
                ),

                const SizedBox(height: 24),

                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today’s Emotional Climate",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.96),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This is a simple snapshot-style view designed to stay within store rules. "
                                "It focuses on how people are feeling overall, not on predictions.",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              height: 1.4,
                              color: Colors.white.withOpacity(0.82),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Center(
                            child: Text(
                              "Live Mood View coming next.\nGuests will see a read-only version,\n"
                                  "members and VIPs will unlock more detail.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.white.withOpacity(0.88),
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
          ),
        ),
      ),
    );
  }

}
// ---------------------------------------------------------------------------
// ⭐ NEW PULSE GAUGE — clean, bright, layered, no overlap, no crashes
// ---------------------------------------------------------------------------

class PulseGauge extends StatefulWidget {
  final double score; // 0–100
  const PulseGauge({super.key, required this.score});

  @override
  State<PulseGauge> createState() => _PulseGaugeState();
}

class _PulseGaugeState extends State<PulseGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;

    // ⭐ Define glow/colour tiers properly
    Color glow;
    String moodLabel;
    if (score >= 70) {
      glow = const Color(0xFF00FEFC);             // Cyan = positive
      moodLabel = "Positive Mood";
    } else if (score >= 40) {
      glow = Colors.white.withOpacity(0.75);      // Neutral
      moodLabel = "Neutral Mood";
    } else {
      glow = const Color(0xFFFF4B7D);             // Pink/Red = low mood
      moodLabel = "Low Mood";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⭐ Label ABOVE the gauge
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            "National Mood",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ),

        // ⭐ Animated pulse circle
        SizedBox(
          width: 130,
          height: 130,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final pulse = (1 + (_controller.value * 0.10));

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ⭐ Smooth clean glow
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.55),
                      blurRadius: 35,
                      spreadRadius: 12,
                    ),
                  ],
                  // ⭐ Inner gradient tint
                  gradient: RadialGradient(
                    colors: [
                      glow.withOpacity(0.28),
                      Colors.black.withOpacity(0.20),
                    ],
                  ),
                ),
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 6,
                        color: glow.withOpacity(0.85),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "${score.toInt()}%",
                        style: GoogleFonts.orbitron(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: glow.withOpacity(0.95),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // ⭐ Mood interpretation (below)
        Text(
          moodLabel,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}
// ---------------------------------------------------------------------------
// ⭐ MoodCast Activity Meter (Low / Medium / High)
// ---------------------------------------------------------------------------

class MoodActivityMeter extends StatefulWidget {
  const MoodActivityMeter({super.key});

  @override
  State<MoodActivityMeter> createState() => _MoodActivityMeterState();
}

class _MoodActivityMeterState extends State<MoodActivityMeter> {
  int _count = 0;

  Future<void> _load() async {
    final client = Supabase.instance.client;

    final since = DateTime.now().subtract(const Duration(hours: 3));

    final rows = await client
        .from('moods')
        .select('id')
        .gte('timestamp', since.toIso8601String());


    setState(() {
      _count = rows.length;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh every 45 sec
    Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    String label = "How People Are Feeling Right Now";
    Color color;

    if (_count >= 15) {
      color = const Color(0xFF00FEFC); // bright cyan = plenty of moods
    } else if (_count >= 5) {
      color = Colors.white70; // neutral
    } else {
      color = const Color(0xFFFF4B7D); // quiet mood sharing
    }


    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "How People Are Feeling Right Now",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "From moods shared in the last 3 hours",
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white70,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// ⭐ Live Feed Counter — Weekly Hybrid Version
// ---------------------------------------------------------------------------

class LiveFeedCounter extends StatefulWidget {
  const LiveFeedCounter({super.key});

  @override
  State<LiveFeedCounter> createState() => _LiveFeedCounterState();
}

class _LiveFeedCounterState extends State<LiveFeedCounter> {
  int _weeklyCount = 0;

  Future<void> _load() async {
    final client = Supabase.instance.client;

    final since = DateTime.now().subtract(const Duration(days: 7));

    final rows = await client
        .from('moods')
        .select('id')
        .gte('timestamp', since.toIso8601String());


    setState(() {
      _weeklyCount = rows.length;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ Hybrid rules:
    // 1+ → show real number
    // 0  → show "New moods shared this week"
    final String text = (_weeklyCount > 0)
        ? "🔥 $_weeklyCount Vibes shared this week"
        : "🔥 New moods were shared this week";

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }
}
