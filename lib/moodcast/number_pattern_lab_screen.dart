// lib/moodcast/number_pattern_lab_screen.dart
// VisionGlass — Number Pattern Lab (FULL VERSION)

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import './voice_player.dart';
import '../widgets/moodcast_banner.dart';

import '../main.dart';

const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _deepNavy = Color(0xFF050814);


class NumberPatternLabScreen extends StatefulWidget {
  const NumberPatternLabScreen({super.key});

  @override
  State<NumberPatternLabScreen> createState() => _NumberPatternLabScreenState();
}

class _NumberPatternLabScreenState extends State<NumberPatternLabScreen>
    with SingleTickerProviderStateMixin {
  // -------------------------------------------------------------
  // QUESTIONS FOR THIS LAB
  // -------------------------------------------------------------
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _patternInterest = "general"; // general / repeating / cycles
  String _focusArea = "daily"; // daily / weekly / personal

  // -------------------------------------------------------------
  // STATE
  // -------------------------------------------------------------
  bool _isLoading = false;
  bool _hasFetchedOnce = false;
  Map<String, dynamic>? _data;
  String? _error;

  // -------------------------------------------------------------
  // LOADING HINTS (ROTATING)
  // -------------------------------------------------------------
  int _hintIndex = 0;
  Timer? _hintTimer;

  final List<String> _loadingHints = const [
    "Patterns form when the brain links timing and repetition.",
    "Repeating numbers often match attention peaks, not luck.",
    "Your focus shape the patterns you notice daily.",
    "Some number cycles align with sleep and energy rhythms.",
    "The brain reacts faster to familiar digit combinations.",
    "People notice 111 or 222 more when stressed or excited.",
    "Repeating numbers activate your pattern-detection loop.",
  ];

  // -------------------------------------------------------------
  // AUDIO
  // -------------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGeneratingAudio = false;
  bool _isPlayingAudio = false;

  // -------------------------------------------------------------
  // INFO PANEL
  // -------------------------------------------------------------
  late AnimationController _infoController;
  late Animation<double> _infoAnimation;

  @override
  void initState() {
    super.initState();

    _infoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _infoAnimation = CurvedAnimation(parent: _infoController, curve: Curves.easeOut);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _infoController.dispose();
    _audioPlayer.dispose();
    _birthdateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // START ROTATING HINTS
  // -------------------------------------------------------------
  void _startHints() {
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isLoading) {
        _hintTimer?.cancel();
        return;
      }

      setState(() {
        _hintIndex = (_hintIndex + 1) % _loadingHints.length;
      });
    });
  }

  // -------------------------------------------------------------
  // API CALL — /api/moodcast/number_patterns
  // -------------------------------------------------------------
  Future<void> _fetchNumberPatternInsight() async {
    final name = _nameController.text.trim().isEmpty
        ? "Friend"
        : _nameController.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
      _hasFetchedOnce = true;
    });

    _startHints();

    final uri = Uri.parse('https://auranaguidance.co.uk/api/moodcast/number_patterns');

    final body = jsonEncode({
      "name": name,
      "birthdate": _birthdateController.text.trim(),
      "pattern_interest": _patternInterest,
      "focus_area": _focusArea,
    });


    try {
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _error = "Server error (${res.statusCode})";
          _isLoading = false;
        });
        _hintTimer?.cancel();
        return;
      }

      setState(() {
        _data = jsonDecode(res.body);
        _isLoading = false;
      });
      _hintTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "No connection — try again.";
        _isLoading = false;
      });
      _hintTimer?.cancel();
    }
  }

  // -------------------------------------------------------------
  // AUDIO (TTS)
  // -------------------------------------------------------------
  String _cleanText(String? raw) {
    if (raw == null) return "";
    return raw
        .replaceAll("\n", " ")
        .replaceAll("\r", " ")
        .replaceAll("•", " ")
        .replaceAll("▪", " ")
        .replaceAll("●", " ")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }




  Future<void> _speakInsight() async {
    if (_isGeneratingAudio) return;

    if (_data == null) {
      setState(() => _error = "Run an analysis first.");
      return;
    }

    final String mainText = (_data!["insight"] ?? "").toString().trim();
    final String extra = (_data!["science"] ?? "").toString().trim();

    String script = [mainText, extra].where((e) => e.isNotEmpty).join(". ");

    if (script.isEmpty) {
      setState(() => _error = "The explanation is incomplete — try again.");
      return;
    }

    if (script.length > 900) {
      script = script.substring(0, 900);
    }

    setState(() {
      _isGeneratingAudio = true;
      _isPlayingAudio = false;
    });

    try {
      await PiperPlayer.speak(script, voice: "cori"); // ⭐ Female UK voice

      if (!mounted) return;
      setState(() {
        _isGeneratingAudio = false;
        _isPlayingAudio = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Voice connection issue — retry.";
        _isGeneratingAudio = false;
        _isPlayingAudio = false;
      });
    }
  }


  Future<void> _stopVoice() async {
    await PiperPlayer.stop();
    if (!mounted) return;
    setState(() => _isPlayingAudio = false);
  }


  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepNavy,
      body: Stack(
        children: [
          SafeArea(
            child: LiquidBackground(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ⭐⭐⭐ AD BANNER AT TOP (VIP auto-hide)
                    const SizedBox(height: 4),
                    const MoodCastBanner(),
                    const SizedBox(height: 6),

// ⭐ AI IS ANALYSING BAR (same as Stress Lab)
                    if (_isLoading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_cyanGlow),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "AI is analysing your pattern…",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "This can take up to 5 minutes — please wait.",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          ],
                        ),
                      ),

                    const SizedBox(height: 6),
                    _topBar(),
                    const SizedBox(height: 10),


                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _glowLogo("assets/images/logo1.png", 64),
                        const SizedBox(width: 24),
                        _glowLogo("assets/images/moodlog1.png", 64),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _introText(),
                    const SizedBox(height: 20),

                    _inputCard(),
                    const SizedBox(height: 18),

                    _isLoading
                        ? _loadingCard()
                        : _error != null
                        ? _errorCard()
                        : _data != null
                        ? _resultCard()
                        : _placeholderCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          _infoPanel(),
        ],
      ),
    );
  }


  // -------------------------------------------------------------
  // TOP BAR
  // -------------------------------------------------------------
  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            "Number Pattern Lab",
            style: GoogleFonts.orbitron(
              fontSize: 18,
              color: _mintGlow,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          onPressed: () => _infoController.forward(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // INTRO
  // -------------------------------------------------------------
  Widget _introText() {
    return Text(
      "Explore how patterns form, why repeating numbers stand out, "
          "and how your timing, attention and daily rhythm shape what you notice.",
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white70,
        height: 1.38,
      ),
    );
  }

  // -------------------------------------------------------------
  // INPUTS
  // -------------------------------------------------------------
  Widget _inputCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personalise your pattern check",
            style: GoogleFonts.orbitron(
              fontSize: 12,
              color: _cyanGlow,
            ),
          ),

          const SizedBox(height: 14),

          Text("Name (optional)",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
          const SizedBox(height: 6),
          _inputBox(
            controller: _nameController,
            hint: "How should the Lab refer to you?",
          ),

          const SizedBox(height: 16),

          Text("Birthdate (for your personal cycle)",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
          const SizedBox(height: 6),
          _inputBox(
            controller: _birthdateController,
            hint: "dd/mm/yyyy",
          ),

          const SizedBox(height: 16),

          Text("What are you curious about?",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chip("General patterns", "general", _patternInterest),
              _chip("Repeating numbers", "repeating", _patternInterest),
              _chip("Cycles", "cycles", _patternInterest),
            ],
          ),

          const SizedBox(height: 16),

          Text("Focus area",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chip("Daily", "daily", _focusArea),
              _chip("Weekly", "weekly", _focusArea),
              _chip("Personal", "personal", _focusArea),
            ],
          ),

          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: _button(_isLoading ? "Analysing…" : "Analyse",
                _isLoading ? null : _fetchNumberPatternInsight,
                dim: _isLoading),
          ),
        ],
      ),
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  // CHIP
  Widget _chip(String label, String value, String group) {
    final selected = value == group;
    return GestureDetector(
      onTap: () => setState(() {
        if (group == _patternInterest) {
          _patternInterest = value;
        } else {
          _focusArea = value;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: selected
              ? const LinearGradient(colors: [_cyanGlow, _mintGlow])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  // BUTTON
  Widget _button(String text, VoidCallback? onTap, {bool dim = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.7 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(colors: [_cyanGlow, _mintGlow]),
            boxShadow: [
              BoxShadow(
                color: _cyanGlow.withOpacity(0.4),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            style: GoogleFonts.orbitron(fontSize: 12, color: Colors.black),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // LOADING CARD
  // -------------------------------------------------------------
  Widget _loadingCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(120, 16),
          const SizedBox(height: 10),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          _shimmer(200, 12),
          const SizedBox(height: 20),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              _loadingHints[_hintIndex],
              key: ValueKey(_loadingHints[_hintIndex]),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // -------------------------------------------------------------
  // RESULT CARD
  // -------------------------------------------------------------
  Widget _resultCard() {
    final j = _data!;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("Today's pattern theme", j["title"]),
          _section("Repeating numbers insight", j["repeating"]),
          _section("Your cycle", j["cycle"]),
          _section("What stands out today", j["focus"]),
          _section("Scientific view", j["science"]),
          _section("Practical reflection", j["tip"]),
          const SizedBox(height: 14),

          // ⭐ NEW — Play / Stop appears ABOVE sources
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _voiceButton(),   // play or stop
            ],
          ),

          const SizedBox(height: 16),

          // ⭐ Pattern behaviour sources BELOW the button
          Text(
            "Pattern behaviour sources",
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white30,
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }


  Widget _section(String title, dynamic text) {
    if (text == null || text.toString().trim().isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.orbitron(fontSize: 12, color: _cyanGlow)),
          const SizedBox(height: 4),
          Text(
            text.toString(),
            style: GoogleFonts.poppins(
                fontSize: 11, height: 1.38, color: Colors.white.withOpacity(0.95)),
          ),
        ],
      ),
    );
  }

  // PLACEHOLDER
  Widget _placeholderCard() {
    return _glass(
      child: Text(
        "Enter your details to explore how patterns form, how repeating "
            "numbers catch your attention, and what your current cycle looks like.",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  // ERROR
  Widget _errorCard() {
    return _glass(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 30),
          const SizedBox(height: 10),
          Text(_error ?? "Error",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 10),
          _button("Retry", _fetchNumberPatternInsight),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // VOICE BUTTON
  // -------------------------------------------------------------
  Widget _voiceButton() {
    final disabled = _data == null || _isGeneratingAudio;

    // Choose icon + label
    IconData icon;
    String label;

    if (_isGeneratingAudio) {
      icon = Icons.graphic_eq;
      label = "Preparing…";
    } else if (_isPlayingAudio) {
      icon = Icons.stop_rounded;
      label = "Stop";
    } else {
      icon = Icons.play_arrow_rounded;
      label = "Play";
    }

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
        if (_isPlayingAudio) {
          _stopVoice();
        } else {
          final scriptParts = [
            _cleanText(_data!["title"]),
            _cleanText(_data!["repeating"]),
            _cleanText(_data!["cycle"]),
            _cleanText(_data!["focus"]),
            _cleanText(_data!["science"]),
            _cleanText(_data!["tip"]),
          ];

          String script = scriptParts.where((t) => t.isNotEmpty).join(". ");

          if (script.length < 40) {
            script =
            "Here is your personalised number pattern insight for today. "
                "Your attention pattern and timing rhythm highlight the numbers that stand out the most.";
          }

          PiperPlayer.speak(script, voice: "cori");
          setState(() => _isPlayingAudio = true);

        }
      },
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [_cyanGlow, _mintGlow],
            ),
            boxShadow: [
              BoxShadow(
                color: _cyanGlow.withOpacity(0.3),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // -------------------------------------------------------------
  // INFO PANEL (slide-up)
  // -------------------------------------------------------------
  Widget _infoPanel() {
    return SizeTransition(
      axisAlignment: -1,
      sizeFactor: _infoAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text("About this Lab",
                      style: GoogleFonts.orbitron(
                          fontSize: 14, color: _mintGlow)),
                  const SizedBox(height: 12),

                  Text(
                    "This Lab looks at how the brain notices patterns, why "
                        "repeating numbers stand out, and how daily rhythms shape "
                        "what captures your attention.",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white70, height: 1.45),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    "Inputs are only used to personalise the insight — no predictions, "
                        "no fortune-telling. Just real behavioural research you can explore.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _button("Close", () => _infoController.reverse()),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // GLASS WRAPPER
  // -------------------------------------------------------------
  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // LOGO GLOW
  // -------------------------------------------------------------
  Widget _glowLogo(String asset, double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _cyanGlow.withOpacity(0.5),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Image.asset(asset, height: size),
      ),
    );
  }
}
