import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; // For loadVipStatusFromSupabase()
import '../screens/home_screen.dart';
import 'package:flutter/services.dart'; // ⭐ Needed for MethodChannel

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool showRegister = false;
  bool isLoading = false;

  final TextEditingController displayName = TextEditingController(); // ⭐ NEW
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  // ⭐ Save & load guest email locally
  Future<void> _saveGuestEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_email', email);
  }

  Future<String?> _loadGuestEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('guest_email');
  }

  Future<void> _clearGuestEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_email');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: SafeArea(
        child: Stack(
          children: [
            _backgroundGlows(),
            _shimmerStreak(),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logoBlock(),
                    const SizedBox(height: 16),
                    _appTitle(),
                    const SizedBox(height: 10),
                    _appSubtitle(),
                    const SizedBox(height: 22),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showWhyJoinSheet,
                        child: Text(
                          "Why join?",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFFDAF7FF),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ⭐ WHEN REGISTERING → SHOW DISPLAY NAME FIELD FIRST
                    if (showRegister) ...[
                      _glassField(
                        controller: displayName,
                        hint: "Display name",
                        icon: Icons.person_outline, // chosen for you
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "This is the name people will see in MoodCast.\nEmails are never shown.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            height: 1.3,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // EMAIL
                    _glassField(
                      controller: email,
                      hint: "Email",
                      icon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD
                    _glassField(
                      controller: password,
                      hint: "Password",
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),

                    const SizedBox(height: 26),

                    _hyperGlassButton(
                      label: showRegister ? "Create Account" : "Login",
                      onTap: _handleLoginRegister,
                    ),

                    const SizedBox(height: 18),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          showRegister = !showRegister;
                        });
                      },
                      child: Text(
                        showRegister
                            ? "Already have an account? Login"
                            : "New here? Join the community",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          decoration: TextDecoration.none, // 🔥 removes cheap underline
                        ),
                      ),
                    ),


                    const SizedBox(height: 28),

                    Text(
                      "OR",
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _hyperGlassButton(
                      label: "Continue as Guest",
                      onTap: _handleGuestLogin,
                    ),

                    const SizedBox(height: 30),
// ⭐ Manage Consent (moved from Home to Login)
                    GestureDetector(
                      onTap: () async {
                        const platform = MethodChannel("consent_channel");
                        await platform.invokeMethod("showConsentForm");
                      },
                      child: Text(
                        "Manage Consent",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.80),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _appFooterText(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LOGIN / REGISTER LOGIC
  // --------------------------------------------------------------------------
  Future<void> _handleLoginRegister() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      final trimmedEmail = email.text.trim();
      final trimmedPassword = password.text.trim();
      final trimmedName = displayName.text.trim();

      if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
        throw "Please enter both email and password.";
      }

      if (showRegister) {
        // ⭐ NAME IS MANDATORY WHEN REGISTERING
        if (trimmedName.isEmpty || trimmedName.length < 3) {
          throw "Please choose a display name with at least 3 characters.";
        }

        final res = await supabase.auth.signUp(
          email: trimmedEmail,
          password: trimmedPassword,
        );


        if (res.user == null) throw "Unknown error creating account.";

        await supabase.from('profiles').insert({
          'id': res.user!.id,
          'type': 'user',
          'vip': false,
          'display_name': trimmedName,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await supabase.auth.signInWithPassword(
          email: trimmedEmail,
          password: trimmedPassword,
        );
      }

      await loadVipStatusFromSupabase();

      // ⭐ NAVIGATE TO HOME SCREEN
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavigationWrapper()),
            (route) => false,
      );

    } catch (e) {
      _showError(e.toString());
    }

    setState(() => isLoading = false);
  }


  Future<void> _handleGuestLogin() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      // 1️⃣ Check if we already have a saved guest email
      final savedEmail = await _loadGuestEmail();

      if (savedEmail != null) {
        // Try to sign in using saved guest account
        await supabase.auth.signInWithPassword(
          email: savedEmail,
          password: "guest12345", // fixed internal password
        );

        await loadVipStatusFromSupabase();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NavigationWrapper()),
              (route) => false,
        );

        return;
      }

      // 2️⃣ First-time guest → create guest account
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final guestEmail = "guest_$uniqueId@guest.ai-lottox.com";
      const guestPassword = "guest12345";

      // Create Supabase user for this device
      final res = await supabase.auth.signUp(
        email: guestEmail,
        password: guestPassword,
      );

      if (res.user == null) throw "Could not create guest account.";

      // Insert profile
      await supabase.from('profiles').insert({
        'id': res.user!.id,
        'type': 'guest',
        'display_name': null,
        'vip': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Save guest email locally → permanent per-device guest
      await _saveGuestEmail(guestEmail);

      await loadVipStatusFromSupabase();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }





  // --------------------------------------------------------------------------
  // ERROR POPUP
  // --------------------------------------------------------------------------
  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Something went wrong",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // TOP BLOCK
  // --------------------------------------------------------------------------
  Widget _logoBlock() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FEFC).withOpacity(0.45),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          "assets/images/logo1.png",
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _appTitle() {
    return Text(
      "Mood Lotto X",
      style: GoogleFonts.orbitron(
        color: const Color(0xFFDAF7FF),
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _appSubtitle() {
    return Text(
      "MoodLotto X offers a smooth, modern way to explore number sets\n"
          "designed around you.\n\n"
          "The Vibe Feed brings a lively, social stream of how the nation\n"
          "is feeling today.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 13,
        height: 1.4,
        color: Colors.white70,
      ),
    );
  }

  Widget _appFooterText() {
    return Text(
      "MoodLotto X offers a smooth, modern way to explore number sets\n"
          "designed around you.\n\n"
          "The Vibe Feed shows a lively mix of real posts, giving you a quick\n"
          "look at the nation’s mood today.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white60,
        fontSize: 11,
        height: 1.35,
      ),
    );
  }


  // --------------------------------------------------------------------------
  // WHY JOIN — GLASS SHEET
  // --------------------------------------------------------------------------
  void _showWhyJoinSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      // Top pull bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ⭐ Title
                      Text(
                        "Why join MoodLotto X?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDAF7FF),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ⭐ Section 1 — Personalised numbers
                      _glassSection(
                        title: "Fresh, personalised number sets",
                        description:
                        "Get number sets shaped around your moment.\n"
                            "Every tap feels new, clean and made just for you.",
                        icon: Icons.auto_graph_rounded,
                      ),

                      const SizedBox(height: 16),

                      // ⭐ Section 2 — Live Vibe Feed
                      _glassSection(
                        title: "See how the nation feels — live",
                        description:
                        "Scroll through real posts on the Vibe Feed.\n"
                            "A fast, lively mood stream showing the highs, lows\n"
                            "and everything people are sharing today.",
                        icon: Icons.insights_outlined,
                      ),

                      const SizedBox(height: 16),

                      // ⭐ Section 3 — Community
                      _glassSection(
                        title: "Join a modern, social space",
                        description:
                        "It’s more than numbers — it’s a growing community\n"
                            "checking in, sharing and exploring together.",
                        icon: Icons.group_outlined,
                      ),

                      const SizedBox(height: 16),

                      // ⭐ Section 4 — VIP optional
                      _glassSection(
                        title: "VIP whenever you're ready",
                        description:
                        "Extra perks, extra tools, no pressure.\n"
                            "The core experience stays open for everyone.",
                        icon: Icons.workspace_premium_outlined,
                      ),

                      const SizedBox(height: 26),

                      // Close button
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Close",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
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

  Widget _glassSection({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFFDAF7FF), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.96),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.4,
                        color: Colors.white.withOpacity(0.85),
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

  // --------------------------------------------------------------------------
  // BACKGROUND GLOWS + STREAK
  // --------------------------------------------------------------------------
  Widget _backgroundGlows() {
    return Stack(
      children: const [
        Positioned(
          top: -120,
          left: -90,
          child: GlowOrb(size: 300, opacity: 0.32),
        ),
        Positioned(
          bottom: -130,
          right: -70,
          child: GlowOrb(size: 330, opacity: 0.28),
        ),
        Positioned(
          top: 120,
          right: 40,
          child: GlowOrb(size: 120, opacity: 0.18),
        ),
      ],
    );
  }

  Widget _shimmerStreak() {
    return Align(
      alignment: Alignment.topRight,
      child: Transform.rotate(
        angle: -0.32,
        child: Container(
          width: 200,
          height: 500,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // GLASS INPUT FIELD
  // --------------------------------------------------------------------------
  Widget _glassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HYPERGLASS BUTTON
  // --------------------------------------------------------------------------
  Widget _hyperGlassButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? () {} : onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00FEFC).withOpacity(0.25),
                  const Color(0xFF72FFD6).withOpacity(0.18),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FEFC).withOpacity(0.35),
                  blurRadius: 35,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
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
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
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

// --------------------------------------------------------------------------
// GLOW ORB
// --------------------------------------------------------------------------
class GlowOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const GlowOrb({super.key, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF00FEFC).withOpacity(opacity),
            const Color(0xFF72FFD6).withOpacity(opacity * 0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
