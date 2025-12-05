// lib/moodcast/lucky_cycle_screen.dart
// Conscious Cycle Lab — Scientific Weekly Pattern Analysis (FINAL CLEAN VERSION)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart'; // isVip + LiquidBackground
import '../screens/vip_paywall_screen.dart';
import '../widgets/moodcast_banner.dart';

const _cyanGlow = Color(0xFF00F0FF);
const _mintGlow = Color(0xFF72FFD6);
const _deepNavy = Color(0xFF050815);

class LuckyCycleScreen extends StatefulWidget {
  const LuckyCycleScreen({super.key});

  @override
  State<LuckyCycleScreen> createState() => _LuckyCycleScreenState();
}

class _LuckyCycleScreenState extends State<LuckyCycleScreen>
    with SingleTickerProviderStateMixin {
  // Questions
  String? q1, q2, q3, q5, q7, q8;

  // Results
  bool loading = false;
  Map<String, dynamic>? freeData;
  Map<String, dynamic>? vipData;
  String? errorMsg;

  // Info panel animation
  late AnimationController infoCtrl;
  late Animation<double> infoAnim;

  // rotating scientific facts
  int factIndex = 0;
  final facts = [
    "Cognitive sharpness fluctuates across weekly behavioural cycles.",
    "Mental workload influences decision accuracy throughout the week.",
    "Short-term recovery patterns shape clarity windows each day.",
    "Focus stability rises and falls in predictable micro-rhythms.",
    "Behaviour science shows timing affects judgement and motivation.",
  ];

  @override
  void initState() {
    super.initState();
    infoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    infoAnim = CurvedAnimation(parent: infoCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    infoCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // SMALL HELPER FOR SAFE FIELD ACCESS
  // -------------------------------------------------------------
  String _f(Map<String, dynamic>? j, String key) {
    if (j == null) return "";
    final v = j[key];
    if (v == null) return "";
    return v.toString().trim();
  }

  // -------------------------------------------------------------
  // VALIDATION
  // -------------------------------------------------------------
  bool _validate() {
    if (q1 == null ||
        q2 == null ||
        q3 == null ||
        q5 == null ||
        q7 == null ||
        q8 == null) {
      setState(() => errorMsg = "Please answer all questions first");
      return false;
    }
    return true;
  }

  // -------------------------------------------------------------
  // API CALLS — GET with query parameters
  // -------------------------------------------------------------
  Future<void> _analyse() async {
    if (!_validate()) return;

    setState(() {
      loading = true;
      errorMsg = null;
      freeData = null;
      vipData = null;
      factIndex = (factIndex + 1) % facts.length;
    });

    final params = {
      "focus_quality": q1!,
      "clarity": q2!,
      "confidence": q3!,
      "productivity": q5!,
      "mental_load": q7!,
      "emotional_balance": q8!,
    };

    try {
      if (isVip) {
        await _getVip(params);
      } else {
        await _getFree(params);
      }
    } catch (_) {
      setState(() => errorMsg = "No connection — try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _getFree(Map<String, String> params) async {
    final uri = Uri.https("auranaguidance.co.uk", "/api/moodcast/cycle2", params);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      setState(() => errorMsg = "Server error (${res.statusCode})");
      return;
    }

    final decoded = json.decode(res.body);
    if (decoded is Map<String, dynamic>) {
      setState(() => freeData = decoded);
    } else {
      setState(() => errorMsg = "Unexpected response format.");
    }
  }

  Future<void> _getVip(Map<String, String> params) async {
    final uri =
    Uri.https("auranaguidance.co.uk", "/api/moodcast/cycle2_vip", params);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      setState(() => errorMsg = "Server error (${res.statusCode})");
      return;
    }

    final decoded = json.decode(res.body);
    if (decoded is Map<String, dynamic>) {
      setState(() => vipData = decoded);
    } else {
      setState(() => errorMsg = "Unexpected response format.");
    }
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final showLoadingBar = loading;

    return Scaffold(
      backgroundColor: _deepNavy,
      body: Stack(
        children: [
          SafeArea(
            child: LiquidBackground(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isVip) const MoodCastBanner(),
                    if (!isVip) const SizedBox(height: 10),

                    if (showLoadingBar) _loadingBar(),
                    if (showLoadingBar) const SizedBox(height: 6),

                    _topBar(),
                    const SizedBox(height: 20),

                    Center(
                      child: Image.asset(
                        "assets/images/logo1.png",
                        height: 90,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _intro(),
                    const SizedBox(height: 20),

                    _questionCard(),
                    const SizedBox(height: 20),

                    _analyseButton(),
                    const SizedBox(height: 25),

                    if (loading) _loadingCard(),

                    if (errorMsg != null) _errorCard(),

                    // FREE RESULT + VIP TEASER
                    if (!isVip && freeData != null) ...[
                      _freeResult(freeData!),
                      const SizedBox(height: 20),
                      _vipTeaser(),
                    ],

                    // VIP RESULT
                    if (isVip && vipData != null) _vipResult(vipData!),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Info bottom sheet
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
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            isVip ? "CONSCIOUS CYCLE — VIP" : "Conscious Cycle Lab",
            style: GoogleFonts.orbitron(
              color: isVip ? _mintGlow : _cyanGlow,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          onPressed: () => infoCtrl.forward(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // QUESTIONS
  // -------------------------------------------------------------
  Widget _intro() {
    return Text(
      "Every week follows cognitive and behavioural rhythms. "
          "Answer the scientific questions below to map your position.",
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white70,
        height: 1.45,
      ),
    );
  }

  Widget _questionCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _question(
            "How steady does your focus feel today?",
            ["Unsteady", "Manageable", "Stable"],
                (v) => setState(() => q1 = v),
            q1,
          ),
          _question(
            "How clear does your thinking feel?",
            ["Foggy", "Moderate", "Clear"],
                (v) => setState(() => q2 = v),
            q2,
          ),
          _question(
            "How confident do your decisions feel?",
            ["Low", "Reasonable", "Strong"],
                (v) => setState(() => q3 = v),
            q3,
          ),
          _question(
            "How productive does today feel?",
            ["Low", "Steady", "High"],
                (v) => setState(() => q5 = v),
            q5,
          ),
          _question(
            "How heavy does your mental load feel?",
            ["Light", "Average", "Heavy"],
                (v) => setState(() => q7 = v),
            q7,
          ),
          _question(
            "How balanced do you feel emotionally?",
            ["Off-balance", "Neutral", "Balanced"],
                (v) => setState(() => q8 = v),
            q8,
          ),
        ],
      ),
    );
  }

  Widget _question(
      String title,
      List<String> options,
      Function(String) select,
      String? selected,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(
              color: _cyanGlow,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map(
                  (o) => GestureDetector(
                onTap: () => select(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected == o
                        ? const LinearGradient(
                      colors: [_cyanGlow, _mintGlow],
                    )
                        : null,
                    color: selected == o
                        ? null
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == o
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    o,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: selected == o
                          ? Colors.black
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ACTION BUTTON
  // -------------------------------------------------------------
  Widget _analyseButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: loading ? null : _analyse,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cyanGlow, _mintGlow]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _mintGlow.withOpacity(0.4),
                blurRadius: 25,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isVip && !loading)
                const Icon(Icons.star, color: Colors.black, size: 16),
              if (isVip && !loading) const SizedBox(width: 6),
              Text(
                loading
                    ? "Analysing..."
                    : isVip
                    ? "Generate VIP Insight"
                    : "Analyse Cycle",
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
  // RESULTS — FREE (ALL 9 FIELDS)
  // -------------------------------------------------------------
  Widget _freeResult(Map<String, dynamic> j) {
    final title = _f(j, "title");
    final cycleName = _f(j, "cycle_name");
    final desc = _f(j, "cycle_description");
    final bestWindow = _f(j, "best_action_window");
    final behaviour = _f(j, "behaviour");
    final timingPattern = _f(j, "timing_pattern");
    final science = _f(j, "science");
    final tip = _f(j, "tip");
    final sources = _f(j, "sources");

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge("FREE INSIGHT"),
          const SizedBox(height: 10),

          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),

          if (cycleName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                cycleName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ),

          if (desc.isNotEmpty)
            _section("Cycle description", desc),

          const Divider(color: Colors.white12),

          if (bestWindow.isNotEmpty)
            _section("Optimal timing", bestWindow),

          if (behaviour.isNotEmpty)
            _section("Likely behaviour", behaviour),

          if (timingPattern.isNotEmpty)
            _section("Timing pattern", timingPattern),

          if (science.isNotEmpty)
            _section("Science context", science),

          if (tip.isNotEmpty)
            _section("Today’s suggestion", tip),

          if (sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                sources,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white38,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RESULTS — VIP (ALL 9 FIELDS, PREMIUM LAYOUT)
  // -------------------------------------------------------------
  Widget _vipResult(Map<String, dynamic> j) {
    final title = _f(j, "title");
    final cycleName = _f(j, "cycle_name");
    final desc = _f(j, "cycle_description");
    final bestWindow = _f(j, "best_action_window");
    final behaviour = _f(j, "behaviour");
    final timingPattern = _f(j, "timing_pattern");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MAIN VIP HEADER CARD
        _glassVip(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _vipHeader(),
              const SizedBox(height: 12),

              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),

              if (cycleName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    cycleName.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // TWO SMALL TILES
        Row(
          children: [
            Expanded(
              child: _vipTile(
                "OPTIMAL TIMING",
                bestWindow,
                Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vipTile(
                "BEHAVIOUR",
                behaviour,
                Icons.psychology_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // TIMING PATTERN
        _vipTile(
          "TIMING PATTERN",
          timingPattern,
          Icons.timeline,
          full: true,
        ),
      ],
    );
  }


  // -------------------------------------------------------------
  // VIP / FREE UI HELPERS
  // -------------------------------------------------------------
  Widget _vipTile(String title, String content, IconData icon,
      {bool full = false}) {
    if (content.trim().isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _cyanGlow, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style:
            GoogleFonts.orbitron(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vipHeader() {
    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient:
            const LinearGradient(colors: [_cyanGlow, _mintGlow]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.star,
                  size: 12, color: Colors.black),
              const SizedBox(width: 5),
              Text(
                "VIP INTELLIGENCE",
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.verified, color: _mintGlow, size: 16),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.orbitron(
          fontSize: 10,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _section(String title, String val) {
    if (val.trim().isEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            GoogleFonts.orbitron(fontSize: 11, color: _cyanGlow),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TEASER — FOR FREE USERS
  // -------------------------------------------------------------
  Widget _vipTeaser() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
      ),
      child: _glassVip(
        child: Column(
          children: [
            const Icon(Icons.lock_outline,
                color: Colors.white, size: 28),
            const SizedBox(height: 10),
            Text(
              "Unlock advanced weekly intelligence",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "GO VIP",
                style: GoogleFonts.orbitron(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // LOADING BAR + CARDS
  // -------------------------------------------------------------
  Widget _loadingBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation(isVip ? _mintGlow : _cyanGlow),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              isVip
                  ? "Calculating advanced timing windows..."
                  : "AI is analysing your pattern…",
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(140, 12),
          const SizedBox(height: 8),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 6),
          _shimmer(double.infinity, 12),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 15, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  facts[factIndex],
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _errorCard() {
    return _glass(
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.white60, size: 30),
          const SizedBox(height: 10),
          Text(
            errorMsg ?? "",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // GLASS ELEMENTS
  // -------------------------------------------------------------
  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassVip({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cyanGlow.withOpacity(0.15),
                _deepNavy.withOpacity(0.5),
              ],
            ),
            border: Border.all(color: _cyanGlow.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // INFO PANEL
  // -------------------------------------------------------------
  Widget _infoPanel() {
    return SizeTransition(
      sizeFactor: infoAnim,
      axisAlignment: -1,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding:
              const EdgeInsets.fromLTRB(18, 20, 18, 40),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F20).withOpacity(0.9),
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
                    "How this works",
                    style: GoogleFonts.orbitron(
                      color: _mintGlow,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Behavioural research shows that cognition, clarity, "
                        "motivation and mental load follow weekly patterns. "
                        "By combining your inputs with factual scientific data, "
                        "the Lab maps your current cycle position.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => infoCtrl.reverse(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Close",
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
