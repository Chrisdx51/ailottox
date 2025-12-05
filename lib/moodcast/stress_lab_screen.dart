// lib/moodcast/stress_lab_screen.dart
// VisionGlass Stress Lab — Stress slider + Personalisation card + AI + TTS

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';
import '../widgets/moodcast_banner.dart';
import 'voice_player.dart';


const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _deepNavy = Color(0xFF050815);

class StressLabScreen extends StatefulWidget {
  const StressLabScreen({super.key});

  @override
  State<StressLabScreen> createState() => _StressLabScreenState();
}

class _StressLabScreenState extends State<StressLabScreen> {
  // Core stress value (0–10)
  double _stressValue = 5;

  // NEW: personalisation fields
  double _tensionValue = 5; // physical tension (0–10)
  double _overwhelmValue = 5; // mental overload (0–10)
  String _sleepQuality = "average"; // good | average | poor
  String _selectedMood = "neutral"; // calm | neutral | low | tense | stressed
  final TextEditingController _triggerController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _data;
  String? _error;
  bool _hasFetchedOnce = false;

  // rotating helpful facts WHILE loading
  int _factIndex = 0;
  final List<String> _waitingFacts = const [
    "Short bursts of stress can sharpen focus, but long stretches often blur decision clarity.",
    "Naming how you feel can slightly reduce the intensity of that feeling.",
    "When you’re overwhelmed, the brain leans heavily on shortcuts, making small things feel huge.",
    "Slow breathing for just 30 seconds can lower stress signals in the body.",
    "Your stress level affects how you filter conversations—high tension narrows focus.",
    "Tired brains misread tone more easily—rest changes how you interpret emotion.",
    "Light movement increases mental clarity by up to 20% during stressful moments.",
  ];

  @override
  void initState() {
    super.initState();
    // AI starts on button only
  }

  @override
  void dispose() {
    _triggerController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // CALL BACKEND + AUTO CHAT PLAY
  // -------------------------------------------------------------
  Future<void> _fetchStressInsight() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _factIndex = (_factIndex + 1) % _waitingFacts.length;
    });




    // ✅ Back to your original style: explicit URL with full path
    final url = Uri.parse(
      'https://auranaguidance.co.uk/api/moodcast/stress'
          '?level=${_stressValue.round()}'
          '&tension=${_tensionValue.round()}'
          '&overwhelm=${_overwhelmValue.round()}'
          '&sleep=$_sleepQuality'
          '&trigger=${Uri.encodeComponent(_triggerController.text.trim())}'
          '&mood=$_selectedMood',
    );

    try {
      // run the request in background so it survives navigation
      final future = http.get(url);

      future.then((res) {
        if (!mounted) return;

        if (res.statusCode != 200) {
          setState(() {
            _error = "Server error (${res.statusCode})";
            _isLoading = false;
          });
          return;
        }

        final jsonBody = json.decode(res.body);

        setState(() {
          _data = jsonBody;
          _isLoading = false;
          _hasFetchedOnce = true;
        });

        final String fullText =
            "${jsonBody['title']}. ${jsonBody['science']}. ${jsonBody['behaviour']}. ${jsonBody['pattern']}. ${jsonBody['tip']}.";

        PiperPlayer.speak(fullText, voice: "cori");
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _error = "No connection — please try again.";
          _isLoading = false;
        });
      });



    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "No connection — please try again.";
        _isLoading = false;
      });

    }
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepNavy,
      body: SafeArea(
        child: LiquidBackground(
          child: Column(
            children: [
              const SizedBox(height: 6),
              const MoodCastBanner(),
              const SizedBox(height: 6),

// ⭐ FLOATING AI LOADING BAR
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

                      /// ⭐ Prevent overflow on all screens
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

              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        "Stress Lab",
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDAF7FF),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: _showInfoSheet,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _glowLogo(
                          "assets/images/moodlog1.png",
                          105,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        "Set your stress level and personal details. The Lab shows how your pattern is likely to feel in real life.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // CARD 1: STRESS SLIDER
                      _sliderCard(),

                      const SizedBox(height: 16),

                      // CARD 2: FUTURISTIC PERSONALISATION
                      _personalisationCard(),

                      const SizedBox(height: 18),

                      // CARD 3: RESULT / STATE
                      if (_isLoading) _loadingCard(),
                      if (!_isLoading && _error != null) _errorCard(),
                      if (!_isLoading && _error == null && _data != null)
                        _resultCard(_data!),
                      if (!_isLoading && _error == null && !_hasFetchedOnce)
                        _placeholderCard(),
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

  // -------------------------------------------------------------
  // INFO SHEET — FULLY SCROLLABLE
  // -------------------------------------------------------------
  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.74,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      "How Stress Patterns Work",
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        color: _cyanGlow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Stress changes how the brain filters information, reacts, and manages patience or clarity.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.95),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "This Lab gives a behavioural explanation of what your current pattern often looks like in day-to-day life.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "You can refresh any time your stress level or circumstances change to see how the pattern shifts.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // CARD 1: STRESS SLIDER
  // -------------------------------------------------------------
  Widget _sliderCard() {
    return _glassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "STRESS LEVEL (0–10)",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _stressValue.round().toString(),
              style: GoogleFonts.orbitron(
                fontSize: 33,
                fontWeight: FontWeight.w600,
                color: _mintGlow,
              ),
            ),
          ),
          const SizedBox(height: 8),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              thumbColor: _mintGlow,
              activeTrackColor: _cyanGlow.withOpacity(0.85),
              inactiveTrackColor: Colors.white12,
              overlayColor: _cyanGlow.withOpacity(0.2),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              11,
                  (i) => Text(
                "$i",
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color:
                  _stressValue.round() == i ? _mintGlow : Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CARD 2: FUTURISTIC PERSONALISED INPUTS
  // -------------------------------------------------------------
  Widget _personalisationCard() {
    return _glassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PERSONAL STRESS MAP",
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "These details help the Lab describe how your stress feels in your body, thinking and day-to-day behaviour.",
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.4,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 14),

          // Mood
          Text(
            "CURRENT MOOD",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _moodChip("calm", "Calm", Icons.self_improvement),
              _moodChip("neutral", "Neutral", Icons.horizontal_rule_rounded),
              _moodChip("low", "Low", Icons.cloud_rounded),
              _moodChip("tense", "Tense", Icons.bolt_rounded),
              _moodChip("stressed", "Stressed", Icons.warning_amber_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // Physical tension slider
          Text(
            "PHYSICAL TENSION",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "0 = loose • 10 = tight",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
              Text(
                _tensionValue.round().toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _mintGlow,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              thumbColor: _mintGlow,
              activeTrackColor: _cyanGlow,
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: _tensionValue,
              onChanged: (v) => setState(() => _tensionValue = v),
            ),
          ),

          const SizedBox(height: 12),

          // Mental overload slider
          Text(
            "MENTAL OVERLOAD",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "0 = clear • 10 = crowded",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
              Text(
                _overwhelmValue.round().toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _mintGlow,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              thumbColor: _mintGlow,
              activeTrackColor: _cyanGlow,
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: _overwhelmValue,
              onChanged: (v) => setState(() => _overwhelmValue = v),
            ),
          ),

          const SizedBox(height: 12),

          // Sleep quality
          Text(
            "SLEEP QUALITY",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _sleepChip("good", "Good"),
              _sleepChip("average", "Average"),
              _sleepChip("poor", "Poor"),
            ],
          ),

          const SizedBox(height: 14),

          // Trigger text
          Text(
            "TODAY'S MAIN TRIGGER",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: TextField(
              controller: _triggerController,
              maxLines: 2,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: "e.g. deadlines, money, family tension, arguments…",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // MAGIC BUTTON (uses all inputs)
          _magicButton(),
        ],
      ),
    );
  }

  // Mood chip
  Widget _moodChip(String value, String label, IconData icon) {
    final selected = _selectedMood == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedMood = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected
              ? const LinearGradient(colors: [_cyanGlow, _mintGlow])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: selected ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sleep chip
  Widget _sleepChip(String value, String label) {
    final selected = _sleepQuality == value;

    return GestureDetector(
      onTap: () => setState(() => _sleepQuality = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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

  // -------------------------------------------------------------
  // MAGIC BUTTON
  // -------------------------------------------------------------
  Widget _magicButton() {
    final text = _isLoading
        ? "Analysing…"
        : _hasFetchedOnce
        ? "Refresh Insight"
        : "Analyse Stress";

    return GestureDetector(
      onTap: _isLoading ? null : _fetchStressInsight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 46,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [_cyanGlow, _mintGlow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _cyanGlow.withOpacity(0.45),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.black87),
              ),
            )
                : const Icon(
              Icons.scatter_plot_rounded,
              size: 20,
              color: Colors.black87,
            ),

            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // RESULT CARD
  // -------------------------------------------------------------
  Widget _resultCard(Map<String, dynamic> json) {
    final String fullText =
        "${json['title']}. ${json['science']}. ${json['behaviour']}. ${json['pattern']}. ${json['tip']}.";

    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("Title", json["title"]),
          _section("Scientific view", json["science"]),
          _section("Behaviour", json["behaviour"]),
          _section("Patterns", json["pattern"]),
          _section("Tip", json["tip"]),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => PiperPlayer.speak(fullText, voice: "cori"),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.stop_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () => PiperPlayer.stop(),
                ),

                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Listen to this insight as audio.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            "Sources checked online",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SMALL SECTIONS
  // -------------------------------------------------------------
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text.toString(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.38,
              color: Colors.white.withOpacity(0.96),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PLACEHOLDER
  // -------------------------------------------------------------
  Widget _placeholderCard() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Text(
        "Set your level and details, then tap “Analyse Stress” to see how this pattern usually feels.",
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // LOADING — ROTATING FACTS
  // -------------------------------------------------------------
  Widget _loadingCard() {
    final fact = _waitingFacts[_factIndex];

    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shimmerBox(140, 16),
          const SizedBox(height: 12),
          shimmerBox(double.infinity, 12),
          const SizedBox(height: 6),
          shimmerBox(double.infinity, 12),
          const SizedBox(height: 6),
          shimmerBox(220, 12),
          const SizedBox(height: 18),
          Text(
            fact,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ERROR CARD
  // -------------------------------------------------------------
  Widget _errorCard() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 28,
            color: Colors.white70,
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? "Unknown error",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          _magicButton(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // LOGO + GLASS WRAPPER
  // -------------------------------------------------------------
  Widget _glowLogo(String asset, double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _cyanGlow.withOpacity(0.45),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: Image.asset(asset, height: size),
      ),
    );
  }

  Widget shimmerBox(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
