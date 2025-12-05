// lib/moodcast/weather_lab_screen.dart
// VisionGlass Weather & Mood Lab — FIXED: no auto-start + clearer country input

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';
import '../widgets/moodcast_banner.dart';

const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _deepNavy = Color(0xFF050815);

class WeatherLabScreen extends StatefulWidget {
  const WeatherLabScreen({super.key});

  @override
  State<WeatherLabScreen> createState() => _WeatherLabScreenState();
}

class _WeatherLabScreenState extends State<WeatherLabScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _locationController =
  TextEditingController(text: "");

  final TextEditingController _reasonController = TextEditingController();

  String _selectedMood = "neutral";
  double _stressValue = 5;
  String _sleepQuality = "average";

  bool _isLoading = false;
  Map<String, dynamic>? _data;
  String? _error;

  int _factIndex = 0;
  final List<String> _loadingFacts = const [
    "Low sunlight reduces serotonin, influencing mood stability.",
    "Sudden temperature shifts can increase internal tension.",
    "Consistent mild weather supports clearer decision-making.",
    "High humidity slows cognitive processing.",
    "Windy conditions increase emotional sensitivity.",
    "Cold weather narrows focus but reduces motivation.",
  ];

  Timer? _factTimer;

  late AnimationController _infoController;
  late Animation<double> _infoAnimation;

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

    // ❌ REMOVED — automatic AI start
    // _fetchWeatherInsight();
  }

  @override
  void dispose() {
    _stopFactTimer();
    _locationController.dispose();
    _reasonController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  void _startFactTimer() {
    _stopFactTimer();
    _factTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isLoading) {
        _stopFactTimer();
        return;
      }
      setState(() {
        _factIndex = (_factIndex + 1) % _loadingFacts.length;
      });
    });
  }

  void _stopFactTimer() {
    _factTimer?.cancel();
    _factTimer = null;
  }

  // --------------------------------------------------------------------
  // BACKEND CALL
  // --------------------------------------------------------------------
  Future<void> _fetchWeatherInsight() async {
    final location = _locationController.text.trim().isEmpty
        ? "Unknown"
        : _locationController.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
      _factIndex = (_factIndex + 1) % _loadingFacts.length;
    });

    _startFactTimer();

    final query = {
      "location": location,
      "mood": _selectedMood,
      "stress_level": _stressValue.round().toString(),
      "sleep_quality": _sleepQuality,
      "reason_for_checking": _reasonController.text.trim(),
      "scientific": "true",
    };

    final url = Uri.https(
      "auranaguidance.co.uk",
      "/api/moodcast/weather",
      query,
    );

    try {
      final res = await http.get(url);

      if (res.statusCode != 200) {
        setState(() {
          _error = "Server error (${res.statusCode})";
          _isLoading = false;
        });
        _stopFactTimer();
        return;
      }

      setState(() {
        _data = json.decode(res.body);
        _isLoading = false;
      });
      _stopFactTimer();
    } catch (e) {
      setState(() {
        _error = "No connection — try again.";
        _isLoading = false;
      });
      _stopFactTimer();
    }
  }

  // --------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------
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
                    _topBar(),
                    const SizedBox(height: 10),

                    const MoodCastBanner(),
                    const SizedBox(height: 8),

// ⭐ AI IS ANALYSING BAR (same style as all other Labs)
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

                    const SizedBox(height: 8),

                    _introText(),
                    const SizedBox(height: 18),


                    _locationInput(), // ⭐ FIXED — clearer input
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

          _infoPanel(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // TOP BAR
  // --------------------------------------------------------------------
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
            "Weather & Mood Lab",
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

  // --------------------------------------------------------------------
  // INTRO TEXT
  // --------------------------------------------------------------------
  Widget _introText() {
    return Text(
      "This Lab analyses how sunlight, temperature and atmospheric conditions "
          "affect emotional regulation, alertness and behaviour.",
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white70,
        height: 1.38,
      ),
    );
  }

  // --------------------------------------------------------------------
  // ⭐ LOCATION — CLEAR INSTRUCTION + BRIGHTER INPUT
  // --------------------------------------------------------------------
  Widget _locationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter your country or city (required)",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 8),
        _glass(
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _locationController,
                  style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Type your city or country…",
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // PERSONALISATION CARD
  // --------------------------------------------------------------------
  Widget _personalisationCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personalise today’s analysis",
            style: GoogleFonts.orbitron(
              fontSize: 12,
              color: _cyanGlow,
            ),
          ),
          const SizedBox(height: 16),

          // Mood
          Text(
            "Current mood",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _moodChip("calm", Icons.self_improvement),
              _moodChip("neutral", Icons.horizontal_rule_rounded),
              _moodChip("low", Icons.cloud_rounded),
              _moodChip("tense", Icons.bolt_rounded),
              _moodChip("stressed", Icons.warning_amber_rounded),
            ],
          ),

          const SizedBox(height: 18),

          // Stress + slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Stress level (0–10)",
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white)),
              Text(
                _stressValue.round().toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  color: _mintGlow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

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
              onChanged: (v) => setState(() => _stressValue = v),
            ),
          ),

          const SizedBox(height: 18),

          // Sleep
          Text(
            "Sleep quality",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _sleepChip("good", "Good"),
              _sleepChip("average", "Average"),
              _sleepChip("poor", "Poor"),
            ],
          ),

          const SizedBox(height: 18),

          // Reason
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
              style:
              GoogleFonts.poppins(fontSize: 11, color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. unfocused, heavy, restless, flat…",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerRight,
            child: _sharpButton(
              _isLoading ? "Analysing…" : "Analyse",
              _isLoading ? null : _fetchWeatherInsight,
              dim: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  // Mood chip
  Widget _moodChip(String value, IconData icon) {
    final selected = _selectedMood == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedMood = value),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              value[0].toUpperCase() + value.substring(1),
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

  // Sharp button
  Widget _sharpButton(String text, VoidCallback? onTap, {bool dim = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.7 : 1,
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

  // --------------------------------------------------------------------
  // Loading + facts
  // --------------------------------------------------------------------
  Widget _loadingCard() {
    final fact = _loadingFacts[_factIndex];

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shimmer(140, 16),
          const SizedBox(height: 10),
          shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          shimmer(220, 12),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              fact,
              key: ValueKey(fact),
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

  Widget shimmer(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // --------------------------------------------------------------------
  // ERROR
  // --------------------------------------------------------------------
  Widget _errorCard() {
    return _glass(
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white54, size: 30),
          const SizedBox(height: 10),
          Text(
            _error ?? "Error",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _sharpButton("Retry", _fetchWeatherInsight),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // RESULT
  // --------------------------------------------------------------------
  Widget _resultCard(Map<String, dynamic> json) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("Emotional climate", json["title"]),
          _section("Weather snapshot", json["weather_state"]),
          _section("Sunlight influence", json["sunlight"]),
          _section("Temperature effect", json["temperature"]),
          _section("Air & wind impact", json["wind"]),
          _section("Scientific findings", json["science"]),
          _section("Behaviour patterns", json["behaviour"]),
          _section("Daily pattern", json["pattern"]),
          _section("Practical tip", json["tip"]),
          const SizedBox(height: 10),
          Text(
            "Scientific sources consulted",
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder before analysis
  Widget _placeholderCard() {
    return _glass(
      child: Text(
        "Set your mood, stress and sleep, then analyse how today’s weather interacts with emotional stability.",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  // Section
  Widget _section(String title, dynamic text) {
    if (text == null || text.toString().trim().isEmpty) return const SizedBox();

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
              fontWeight: FontWeight.w400,
              fontSize: 11,
              color: Colors.white.withOpacity(0.95),
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // INFO PANEL
  // --------------------------------------------------------------------
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
                    "This section combines behavioural science and meteorology. "
                        "It looks at how sunlight exposure, temperature change and air pressure "
                        "shift emotional regulation, focus and decision style.",
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

  // --------------------------------------------------------------------
  // GLASS WRAPPER
  // --------------------------------------------------------------------
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
