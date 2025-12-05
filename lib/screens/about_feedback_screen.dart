// lib/screens/about_feedback_screen.dart
// ⭐ Premium VisionGlass — About + Feedback Page for MoodLotto X

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AboutFeedbackScreen extends StatefulWidget {
  const AboutFeedbackScreen({super.key});

  @override
  State<AboutFeedbackScreen> createState() => _AboutFeedbackScreenState();
}

class _AboutFeedbackScreenState extends State<AboutFeedbackScreen> {
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();

  bool _sending = false;
  bool _sent = false;

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _sent = false;
    });

    final client = Supabase.instance.client;

    try {
      await client.from('feedback').insert({
        'message': _feedbackController.text.trim(),
        'email': _emailController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      setState(() {
        _sent = true;
        _sending = false;
      });

      _feedbackController.clear();
      _emailController.clear();
    } catch (_) {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ⭐ Animated VisionGlass background (matches your app)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050815), Color(0xFF0A0F1F)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 20),
                  _buildAboutPanel(),
                  const SizedBox(height: 24),
                  _buildFeedbackPanel(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP BAR
  // ------------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const Spacer(),
        Text(
          "About & Feedback",
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: const Color(0xFFDAF7FF),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }

  // ------------------------------------------------------------
  // ABOUT PANEL — VisionGlass premium style
  // ------------------------------------------------------------
  Widget _buildAboutPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome to MoodLotto X",
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "This app blends two powerful experiences:\n\n"
                    "🔮 **AI Lotto X** — Your personalised AI-enhanced number generator.\n"
                    "It adapts to the moment, giving you fresh number sets designed uniquely for you.\n\n"
                    "🌍 **MoodCast** — A living emotional map of the nation.\n"
                    "Here, people share how they feel in real time. Every mood becomes part of today’s "
                    "emotional climate, shaping the national forecast.\n\n"
                    "🧠 **Mood Help Lab** — Deep, meaningful AI support crafted around how you feel.\n"
                    "It helps you understand your emotional state and offers pathways to clarity, comfort, "
                    "and personal growth.\n\n"
                    "✨ **Vibe Page** — See the pulse of the nation.\n"
                    "Not a typical social network with followers or clout — MoodCast is about capturing "
                    "how the world feels, not how people appear.\n\n"
                    "📡 **Daily Emotional Forecast** — A new way to start your day.\n"
                    "See the world’s collective emotional energy and how it shifts.\n\n"
                    "MoodLotto X is designed to feel modern, calming, and personal — a premium space "
                    "built around the power of mood, emotion, and intuition.",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.55,
                  color: Colors.white.withOpacity(0.90),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FEEDBACK PANEL — VisionGlass form
  // ------------------------------------------------------------
  Widget _buildFeedbackPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "We’d Love Your Feedback",
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tell us your thoughts, ideas, or anything you'd like us to improve. "
                    "Your message goes directly to the MoodLotto X team.",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 20),

              // Email (optional)
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Email (optional)",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
                  enabledBorder: _border(),
                  focusedBorder: _border(active: true),
                ),
              ),

              const SizedBox(height: 18),

              // Feedback field
              TextField(
                controller: _feedbackController,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Your Message",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
                  enabledBorder: _border(),
                  focusedBorder: _border(active: true),
                ),
              ),

              const SizedBox(height: 22),

              GestureDetector(
                onTap: _sending ? null : _submitFeedback,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00FEFC).withOpacity(0.65),
                        const Color(0xFF72FFD6).withOpacity(0.45),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      _sent ? "Sent ✓" : "Send Feedback",
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  OutlineInputBorder _border({bool active = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: active
            ? Colors.white.withOpacity(0.8)
            : Colors.white.withOpacity(0.25),
        width: 1.2,
      ),
    );
  }
}
