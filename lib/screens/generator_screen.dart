// 🧬 AILottoX — Generator Screen (Clean Version — No Signature Draws)

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/user_profile.dart';
import 'result_screen.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_lotto_generator/ad_ids.dart';

class GeneratorScreen extends StatefulWidget {
  final UserProfile profile;
  final String lotteryName;

  final int numbersCount;
  final int rangeMax;
  final bool includeBonus;
  final int? bonusRangeMax;

  final bool isVip;

  const GeneratorScreen({
    super.key,
    required this.profile,
    required this.lotteryName,
    required this.numbersCount,
    required this.rangeMax,
    required this.includeBonus,
    this.bonusRangeMax,
    this.isVip = false,
  });

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with SingleTickerProviderStateMixin {

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _glow;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Ads only for free users
    if (!widget.isVip && !isVip) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdIds.bannerTop,
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _isBannerReady = true),
          onAdFailedToLoad: (ad, err) => ad.dispose(),
        ),
        request: const AdRequest(),
      )..load();

      InterstitialAd.load(
        adUnitId: 'ca-app-pub-5354629198133392/3064612221',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialReady = true;
          },
          onAdFailedToLoad: (_) => _isInterstitialReady = false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateTap() async {
    if (!widget.isVip && !isVip && _isInterstitialReady) {
      _interstitialAd!.show();
    }
    await _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        'https://auranaguidance.co.uk/api/ailottox/generate',
      );

      final body = {
        "name": widget.profile.name,
        "dob": widget.profile.dob.toIso8601String(),
        "colour": widget.profile.colour,
        "lottery": widget.lotteryName,
        "numbers_count": widget.numbersCount,
        "range_max": widget.rangeMax,
        "include_bonus": widget.includeBonus,
        "bonus_range_max": widget.bonusRangeMax,
        "mode": (widget.isVip || isVip) ? "vip" : "standard",
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage =
          "Server error: ${response.statusCode}. Please try again.";
          _isLoading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      if (data["ok"] != true) {
        setState(() {
          _errorMessage = data["detail"] ??
              data["error"] ??
              "Unexpected response from the generator.";
          _isLoading = false;
        });
        return;
      }

      final List<int> mainNumbers =
      (data["main_numbers"] as List).map((e) => e as int).toList();

      final List<int> bonusNumbers =
      (data["bonus_numbers"] as List).map((e) => e as int).toList();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            profile: widget.profile,
            lotteryName: widget.lotteryName,
            mainNumbers: mainNumbers,
            bonusNumbers: bonusNumbers,
            isVip: widget.isVip,
          ),
        ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final bool vipActive = widget.isVip || isVip;

    return Scaffold(
      body: LiquidBackground(
        child: Column(
          children: [
            if (!vipActive && _isBannerReady)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),

            Expanded(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: vipActive
                                ? const Color(0xFF72FFD6).withOpacity(0.35)
                                : Colors.white.withOpacity(0.12),
                          ),
                          gradient: LinearGradient(
                            colors: vipActive
                                ? [
                              const Color(0xFF00FEFC).withOpacity(0.18),
                              const Color(0xFF72FFD6).withOpacity(0.10),
                            ]
                                : [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                        ),
                        child: _buildContent(vipActive),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, bottomInset + 16),
              child: _BottomGenerateButton(
                isLoading: _isLoading,
                onTap: _isLoading ? null : _handleGenerateTap,
                vipActive: vipActive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool vipActive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          _buildLogo(vipActive),
          const SizedBox(height: 22),
          _buildTitle(vipActive),
          const SizedBox(height: 10),
          _buildSubtitle(),
          _buildVipSection(vipActive),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.redAccent,
              ),
            ),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildLogo(bool vipActive) {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _glow, curve: Curves.easeInOut),
      ),
      child: Container(
        width: vipActive ? 110 : 92,
        height: vipActive ? 110 : 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: vipActive
                  ? const Color(0xFF72FFD6).withOpacity(0.65)
                  : const Color(0xFF00FEFC).withOpacity(0.38),
              blurRadius: vipActive ? 48 : 28,
              spreadRadius: vipActive ? 12 : 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset("assets/images/logo1.png"),
        ),
      ),
    );
  }

  Widget _buildTitle(bool vipActive) {
    return Text(
      vipActive ? "VIP Generator Mode" : "Generate Your AILottoX Pattern",
      textAlign: TextAlign.center,
      style: GoogleFonts.orbitron(
        fontSize: vipActive ? 19 : 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: const Color(0xFFDAF7FF),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      "Draw Selected: ${widget.lotteryName}\nAI Lotto X is now shaping your lucky number sequence.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.35,
        color: Colors.white.withOpacity(0.88),
      ),
    );
  }


  Widget _buildVipSection(bool vipActive) {
    if (!vipActive) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 26),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
          child: Column(
            children: [
              Text(
                "VIP Mode Active",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your VIP profile is now applied to this generator.\nNo extra steps needed.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  height: 1.35,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomGenerateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  final bool vipActive;

  const _BottomGenerateButton({
    required this.isLoading,
    required this.onTap,
    required this.vipActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: vipActive
                    ? const Color(0xFF72FFD6)
                    : Colors.white.withOpacity(0.25),
                width: 1.3,
              ),
              gradient: LinearGradient(
                colors: vipActive
                    ? [
                  const Color(0xFF00FEFC).withOpacity(0.55),
                  const Color(0xFF72FFD6).withOpacity(0.55),
                ]
                    : [
                  const Color(0xFF00FEFC).withOpacity(0.35),
                  const Color(0xFF00B3A8).withOpacity(0.35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: vipActive
                      ? const Color(0xFF72FFD6).withOpacity(0.45)
                      : const Color(0xFF00FEFC).withOpacity(0.25),
                  blurRadius: vipActive ? 26 : 20,
                  spreadRadius: vipActive ? 6 : 2,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                vipActive
                    ? "Generate VIP Sequence"
                    : "Generate Numbers",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
