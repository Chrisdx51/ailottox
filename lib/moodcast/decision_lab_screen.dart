// lib/moodcast/decision_lab_screen.dart
// VisionGlass Decision Lab — PERSONALISED + ElevenLabs voice

import 'dart:async';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import './voice_player.dart';
import '../widgets/moodcast_banner.dart';

import '../main.dart'; // LiquidBackground

const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _deepNavy = Color(0xFF050815);


class DecisionLabScreen extends StatefulWidget {
  const DecisionLabScreen({super.key});

  @override
  State<DecisionLabScreen> createState() => _DecisionLabScreenState();
}

class _DecisionLabScreenState extends State<DecisionLabScreen>
    with SingleTickerProviderStateMixin {
  // -------------------------------------------------------------
  // PERSONAL INPUTS (must match backend fields)
  // -------------------------------------------------------------
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String _decisionSpeed = "medium"; // slow / medium / fast
  String _clarityLevel = "neutral"; // clear / neutral / foggy
  double _stressValue = 5; // 0–10
  String _timeOfDay = "afternoon"; // morning / afternoon / evening
  String _confidence = "medium"; // low / medium / high

  // -------------------------------------------------------------
  // AI + STATE
  // -------------------------------------------------------------
  bool _isLoading = false;
  bool _hasFetchedOnce = false;
  Map<String, dynamic>? _data;
  String? _error;

  int _hintIndex = 0;
  Timer? _hintTimer;

  final List<String> _loadingHints = const [
    "Short pauses between tasks improve decision clarity.",
    "Writing down options briefly reduces internal noise.",
    "Switching environments can reset mental fatigue.",
    "Tiny breaks stop decisions from stacking emotionally.",
    "Slowing your breathing calms impulse spikes.",
  ];

  // Info panel animation (same style as Weather Lab)
  late AnimationController _infoController;
  late Animation<double> _infoAnimation;

  // -------------------------------------------------------------
  // ElevenLabs AUDIO STATE
  // -------------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGeneratingAudio = false;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();

    _infoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _infoAnimation = CurvedAnimation(
      parent: _infoController,
      curve: Curves.easeOut,
    );

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = false;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _infoController.dispose();
    _nameController.dispose();
    _reasonController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

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
  // API CALL — POST /api/moodcast/decision_plus
  // -------------------------------------------------------------
  Future<void> _fetchDecisionInsight() async {
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

    final uri =
    Uri.parse('https://auranaguidance.co.uk/api/moodcast/decision_plus');

    final body = jsonEncode({
      "name": name,
      "decision_speed": _decisionSpeed,
      "clarity_level": _clarityLevel,
      "stress_level": _stressValue.round(),
      "time_of_day": _timeOfDay,
      "confidence": _confidence,
      "reason_for_checking": _reasonController.text.trim(),
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

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;

      setState(() {
        _data = jsonMap;
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


  String _cleanText(String? raw) {
    if (raw == null) return "";
    return raw
        .replaceAll("\n", " ")
        .replaceAll("\r", " ")
        .replaceAll("•", "")      // remove bullet chars
        .replaceAll("▪", "")
        .replaceAll("●", "")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }



  Future<void> _speakInsight() async {
    if (_data == null) {
      setState(() => _error = "Run an analysis first.");
      return;
    }

    String script = [
      _cleanText(_data!["title"]),
      _cleanText(_data!["decision_clarity"]),
      _cleanText(_data!["behaviour"]),
      _cleanText(_data!["timing_pattern"]),
      _cleanText(_data!["confidence_effect"]),
      _cleanText(_data!["science"]),
      _cleanText(_data!["tip"]),
    ].where((x) => x.isNotEmpty).join(". ");



    // Safety fallback
    if (script.trim().isEmpty) {
      script = "Here is your personalised decision insight for today.";
    }

    // Piper safety limit
    if (script.length > 900) {
      script = script.substring(0, 900);
    }

    try {
      await PiperPlayer.speak(script, voice: "cori");
      if (!mounted) return;

      setState(() {
        _isPlayingAudio = true;
        _error = null;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Voice connection issue — retry.";
        _isPlayingAudio = false;
      });
    }
  }






  Future<void> _stopVoice() async {
    await PiperPlayer.stop();
    if (!mounted) return;
    setState(() {
      _isPlayingAudio = false;
    });
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
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⭐ FREE USERS SEE AD — VIP SEES NOTHING
                    if (!isVip) ...[
                      const MoodCastBanner(),
                      const SizedBox(height: 10),
                    ],

                    _topBar(),
                    const SizedBox(height: 6),

// ⭐ AI IS ANALYSING BAR (same style across all Labs)
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

// Logos row (kept from your original design)
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
                    const SizedBox(height: 18),

                    _personalisationCard(),
                    const SizedBox(height: 18),

                    _isLoading
                        ? _loadingCard()
                        : _error != null
                        ? _errorCard()
                        : _data != null
                        ? _resultCard(_data!)
                        : _placeholderCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Slide-up info panel (same style as Weather Lab)
          _infoPanel(),
        ],
      ),
    );
  }

  // TOP BAR -----------------------------------------------------
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
            "Decision Navigator",
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFDAF7FF),
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

  // LOGO --------------------------------------------------------
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
        child: Image.asset(
          asset,
          height: size,
        ),
      ),
    );
  }

  // INTRO -------------------------------------------------------
  Widget _introText() {
    return Text(
      "This Lab looks at how your timing, stress, clarity and confidence "
          "shape the way decisions feel across the day. Your answers personalise "
          "the explanation, so it speaks directly about you instead of general averages.",
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white70,
        height: 1.38,
      ),
    );
  }

  // PERSONALISATION CARD ---------------------------------------
  Widget _personalisationCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personalise today’s decision window",
            style: GoogleFonts.orbitron(
              fontSize: 12,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 14),

          // NAME
          Text(
            "Name (optional)",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: TextField(
              controller: _nameController,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: "How should the Lab refer to you?",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // DECISION SPEED
          Text(
            "Decision speed today",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chipOption(
                label: "Slow",
                value: "slow",
                groupValue: _decisionSpeed,
                onTap: () => setState(() => _decisionSpeed = "slow"),
              ),
              _chipOption(
                label: "Medium",
                value: "medium",
                groupValue: _decisionSpeed,
                onTap: () => setState(() => _decisionSpeed = "medium"),
              ),
              _chipOption(
                label: "Fast",
                value: "fast",
                groupValue: _decisionSpeed,
                onTap: () => setState(() => _decisionSpeed = "fast"),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // CLARITY LEVEL
          Text(
            "Clarity level",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chipOption(
                label: "Clear",
                value: "clear",
                groupValue: _clarityLevel,
                onTap: () => setState(() => _clarityLevel = "clear"),
              ),
              _chipOption(
                label: "Neutral",
                value: "neutral",
                groupValue: _clarityLevel,
                onTap: () => setState(() => _clarityLevel = "neutral"),
              ),
              _chipOption(
                label: "Foggy",
                value: "foggy",
                groupValue: _clarityLevel,
                onTap: () => setState(() => _clarityLevel = "foggy"),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // STRESS SLIDER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Stress level (0–10)",
                style:
                GoogleFonts.poppins(fontSize: 11, color: Colors.white),
              ),
              Text(
                _stressValue.round().toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _mintGlow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 9),
              thumbColor: _mintGlow,
              activeTrackColor: _cyanGlow,
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: _stressValue,
              onChanged: (v) {
                setState(() => _stressValue = v);
              },
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "0 = calm",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
              Text(
                "10 = highly stressed",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // TIME OF DAY
          Text(
            "Time of day you’re thinking about",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chipOption(
                label: "Morning",
                value: "morning",
                groupValue: _timeOfDay,
                onTap: () => setState(() => _timeOfDay = "morning"),
              ),
              _chipOption(
                label: "Afternoon",
                value: "afternoon",
                groupValue: _timeOfDay,
                onTap: () => setState(() => _timeOfDay = "afternoon"),
              ),
              _chipOption(
                label: "Evening",
                value: "evening",
                groupValue: _timeOfDay,
                onTap: () => setState(() => _timeOfDay = "evening"),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CONFIDENCE
          Text(
            "Decision confidence",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chipOption(
                label: "Low",
                value: "low",
                groupValue: _confidence,
                onTap: () => setState(() => _confidence = "low"),
              ),
              _chipOption(
                label: "Medium",
                value: "medium",
                groupValue: _confidence,
                onTap: () => setState(() => _confidence = "medium"),
              ),
              _chipOption(
                label: "High",
                value: "high",
                groupValue: _confidence,
                onTap: () => setState(() => _confidence = "high"),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // REASON
          Text(
            "Reason for checking",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: TextField(
              controller: _reasonController,
              maxLines: 2,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: "e.g. big choice today, second-guessing everything…",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "This stays on your device and only shapes the explanation.",
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 18),

          // ANALYSE BUTTON
          Align(
            alignment: Alignment.centerRight,
            child: _sharpButton(
              _isLoading ? "Analysing…" : "Analyse",
              _isLoading ? null : _fetchDecisionInsight,
              dim: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  // CHIP OPTION -------------------------------------------------
  Widget _chipOption({
    required String label,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
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

  // SHARP BUTTON ------------------------------------------------
  Widget _sharpButton(String text, VoidCallback? onTap, {bool dim = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [_cyanGlow, _mintGlow],
            ),
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
            style: GoogleFonts.orbitron(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // LOADING CARD -----------------------------------------------
  Widget _loadingCard() {
    final hint = _loadingHints[_hintIndex];

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(140, 16),
          const SizedBox(height: 10),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          _shimmer(220, 12),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              hint,
              key: ValueKey(hint),
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // ERROR CARD --------------------------------------------------
  Widget _errorCard() {
    return _glass(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 30),
          const SizedBox(height: 10),
          Text(
            _error ?? "Error",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _sharpButton("Retry", _fetchDecisionInsight),
        ],
      ),
    );
  }

  // RESULT CARD (matches backend keys) + VOICE BUTTON ----------
  Widget _resultCard(Map<String, dynamic> jsonMap) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("Today’s theme", jsonMap["title"]),
          _section("Decision clarity", jsonMap["decision_clarity"]),
          _section("Behavioural tendencies", jsonMap["behaviour"]),
          _section("Timing window", jsonMap["timing_pattern"]),
          _section("Confidence effect", jsonMap["confidence_effect"]),
          _section("Scientific view", jsonMap["science"]),
          _section("Practical tip", jsonMap["tip"]),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Scientific sources consulted",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white30,
                ),
              ),
              const SizedBox(width: 10),
              _voiceButton(),
            ],
          ),

        ],
      ),
    );
  }

  Widget _placeholderCard() {
    return _glass(
      child: Text(
        "Set how your day feels, then analyse how your timing, stress and confidence "
            "shape the way choices land today.",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  Widget _section(String title, dynamic text) {
    if (text == null || text.toString().trim().isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.toString().trim(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withOpacity(0.95),
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }

  // VOICE BUTTON -----------------------------------------------
  Widget _voiceButton() {
    final bool disabled = _data == null || _isGeneratingAudio;
    String label;
    IconData icon;

    if (_isGeneratingAudio) {
      label = "Preparing voice…";
      icon = Icons.graphic_eq;
    } else if (_isPlayingAudio) {
      label = "Stop voice";
      icon = Icons.stop_rounded;
    } else {
      label = "Play insight";
      icon = Icons.volume_up_rounded;
    }

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
        if (_isPlayingAudio) {
          _stopVoice();
        } else {
          _speakInsight();
        }
      },
      child: Opacity(
        opacity: disabled ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // INFO PANEL (slide-up) --------------------------------------
  Widget _infoPanel() {
    return SizeTransition(
      sizeFactor: _infoAnimation,
      axisAlignment: -1,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "About this page",
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      color: _mintGlow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "This Lab combines behavioural science and daily rhythm research. "
                        "It looks at how stress, mental energy, confidence and timing work together "
                        "to shape how decisions feel from the inside.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Your inputs are used only to personalise the explanation. "
                        "There are no predictions or guarantees — just patterns you can notice "
                        "and use when planning conversations or choices.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _sharpButton(
                      "Close",
                          () => _infoController.reverse(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // GLASS WRAPPER ----------------------------------------------
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
}
