// 🧬 AILottoX — Lottery Selection Screen (VisionGlass VIP Edition v2.0)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_profile.dart';
import 'custom_pick_screen.dart';
import 'generator_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_lotto_generator/ad_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------------------------------------------
// LOTTERY PRESETS
// -------------------------------------------------------
class LotteryConfig {
  final int numbersCount;
  final int rangeMax;
  final bool includeBonus;
  final int? bonusRangeMax;

  LotteryConfig({
    required this.numbersCount,
    required this.rangeMax,
    required this.includeBonus,
    this.bonusRangeMax,
  });
}

// 🔹 Standard + common lotteries (free + VIP)
final List<String> _freeLotteries = [
  "UK Lotto",
  "EuroMillions",
  "Powerball",
  "Mega Millions",
  "Thunderball",
  "Set For Life",
  "Custom Pick",
];

// 🔸 VIP-exclusive signature draws
final List<String> _vipLotteries = [
  "Mystic Pulse 6 (VIP)",
  "Crystal Sphere 7 (VIP)",
  "Quantum Boost 5 (VIP)",
];

LotteryConfig getSettingsForLottery(String name) {
  switch (name) {
    case "UK Lotto":
      return LotteryConfig(numbersCount: 6, rangeMax: 59, includeBonus: false);

    case "EuroMillions":
      return LotteryConfig(
        numbersCount: 5,
        rangeMax: 50,
        includeBonus: true,
        bonusRangeMax: 12,
      );

    case "Powerball":
      return LotteryConfig(
        numbersCount: 5,
        rangeMax: 69,
        includeBonus: true,
        bonusRangeMax: 26,
      );

    case "Mega Millions":
      return LotteryConfig(
        numbersCount: 5,
        rangeMax: 70,
        includeBonus: true,
        bonusRangeMax: 25,
      );

    case "Thunderball":
      return LotteryConfig(
        numbersCount: 5,
        rangeMax: 39,
        includeBonus: true,
        bonusRangeMax: 14,
      );

    case "Set For Life":
      return LotteryConfig(
        numbersCount: 5,
        rangeMax: 47,
        includeBonus: true,
        bonusRangeMax: 10,
      );

    case "Custom Pick":
      return LotteryConfig(
        numbersCount: 6,
        rangeMax: 60,
        includeBonus: false,
      );

    default:
      return LotteryConfig(
        numbersCount: 6,
        rangeMax: 60,
        includeBonus: false,
      );
  }
}

// -------------------------------------------------------
// MAIN SCREEN
// -------------------------------------------------------
class LotterySelectionScreen extends StatefulWidget {
  final UserProfile profile;

  const LotterySelectionScreen({super.key, required this.profile});

  @override
  State<LotterySelectionScreen> createState() => _LotterySelectionScreenState();
}

class _LotterySelectionScreenState extends State<LotterySelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedLottery;
  late AnimationController _logoGlow;
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  // ⭐ VIP: Cosmic Assisted Mode (UI only for now)
  bool _vipCosmicMode = false;
  bool get _isVipLogic => isVip;

  @override
  void initState() {
    super.initState();

    _logoGlow =
    AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    // ⭐ Load Banner Ad (VIP-safe)
    if (!isVip) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdIds.bannerTop,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            setState(() => _isBannerReady = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
        request: const AdRequest(),
      )
        ..load();
    }

    // ⭐ Load saved cosmic mode (VIP only)
    if (_isVipLogic) {
      _loadVipCosmicMode();
    }
  }

  Future<void> _loadVipCosmicMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vipCosmicMode = prefs.getBool("vip_cosmic_mode") ?? false;
    });
  }

  Future<void> _toggleVipCosmicMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vipCosmicMode = value;
    });
    await prefs.setBool("vip_cosmic_mode", value);
  }

  @override
  void dispose() {
    _logoGlow.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _continue() async {
    if (_selectedLottery == null) return;

    // Custom Pick → go to custom config screen first
    if (_selectedLottery == "Custom Pick") {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomPickScreen()),
      );

      if (result != null) {
        final custom = result;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GeneratorScreen(
                  profile: widget.profile,
                  lotteryName: "Custom Pick",
                  numbersCount: custom.count,
                  rangeMax: custom.rangeMax,
                  includeBonus: custom.includeBonus,
                  bonusRangeMax: custom.bonusRangeMax,
                  isVip: isVip,
                ),
          ),
        );
      }
      return;
    }

    // Normal & VIP lotteries
    final config = getSettingsForLottery(_selectedLottery!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GeneratorScreen(
              profile: widget.profile,
              lotteryName: _selectedLottery!,
              numbersCount: config.numbersCount,
              rangeMax: config.rangeMax,
              includeBonus: config.includeBonus,
              bonusRangeMax: config.bonusRangeMax,
              isVip: isVip,
            ),


      ),
    );
  }

  void _showVipUpsellDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF00FEFC).withOpacity(0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "VIP Exclusive Draws",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: const Color(0xFFDAF7FF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "These exclusive draws unlock deeper AILottoX patterns.\nUpgrade to access Mystic Pulse, Crystal Sphere and Quantum Boost.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.4,
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00FEFC).withOpacity(0.40),
                              const Color(0xFF72FFD6).withOpacity(0.40),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "OK",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Column(
          children: [
            // ⭐ TOP BANNER (VIP-safe)
            if (!_isVipLogic && _isBannerReady)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: double.infinity,
                child: AdWidget(ad: _bannerAd!),
              ),

            // ⭐ MAIN CONTENT AREA
            Expanded(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 26),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              _isVipLogic ? 0.20 : 0.10,
                            ),
                          ),
                          gradient: LinearGradient(
                            colors: _isVipLogic
                                ? [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.03),
                            ]
                                : [
                              Colors.white.withOpacity(0.07),
                              Colors.white.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildLogo(),
                              const SizedBox(height: 18),
                              _buildTitle(),
                              const SizedBox(height: 6),
                              if (_isVipLogic) _buildVipBadge(),

                              if (_isVipLogic) const SizedBox(height: 8),
                              _buildSubtitle(),
                              const SizedBox(height: 22),
                              if (_isVipLogic) _buildCosmicToggle(),
                              if (_isVipLogic) const SizedBox(height: 14),
                              _buildList(),
                              const SizedBox(height: 26),

                              // ⭐ Continue button
                              _VisionGlassPrimaryButton(
                                text: "Continue",
                                enabled: _selectedLottery != null,
                                onTap:
                                _selectedLottery != null ? _continue : () {},
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // UI PARTS
  // -------------------------------------------------------
  Widget _buildLogo() {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _logoGlow, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FEFC).withOpacity(_isVipLogic ? 0.50 : 0.35),
              blurRadius: _isVipLogic ? 32 : 24,
              spreadRadius: _isVipLogic ? 6 : 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset("assets/images/logo1.png", fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      "Choose Your Draw",
      textAlign: TextAlign.center,
      style: GoogleFonts.orbitron(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: const Color(0xFFDAF7FF),
      ),
    );
  }

  Widget _buildVipBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00FEFC).withOpacity(0.45),
            const Color(0xFF72FFD6).withOpacity(0.35),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.30),
          width: 1,
        ),
      ),
      child: Text(
        "VIP MODE ACTIVE",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      _isVipLogic
          ? "Pick a draw and AI Lotto X will generate a personalised set of lucky numbers shaped around your saved profile."
          : "Pick a draw and AI Lotto X will create your lucky numbers. VIP Mode unlocks deeper, richer shaping.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 11,
        height: 1.4,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }


  Widget _buildCosmicToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF72FFD6).withOpacity(0.65),
          width: 1.2,
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00FEFC).withOpacity(0.24),
            const Color(0xFF72FFD6).withOpacity(0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enhanced VIP Boost",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "When enabled, AI Lotto X applies extra VIP-level enhancements to your number pattern.",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    height: 1.3,
                    color: Colors.white.withOpacity(0.86),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: _vipCosmicMode,
            onChanged: (value) => _toggleVipCosmicMode(value),
            activeColor: const Color(0xFF00FEFC),
            activeTrackColor: const Color(0xFF72FFD6).withOpacity(0.65),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ---------------------------------------
        // FREE LOTTERIES
        // ---------------------------------------
        Column(
          children: _freeLotteries.map((lotteryName) {
            final selected = _selectedLottery == lotteryName;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _VisionGlassSelectable(
                text: lotteryName,
                selected: selected,
                locked: false,
                vipTag: false,
                onTap: () {
                  setState(() => _selectedLottery = lotteryName);
                },
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // ---------------------------------------
        // VIP LOTTERIES (Show locked if not VIP)
        // ---------------------------------------
        Column(
          children: _vipLotteries.map((lotteryName) {
            final selected = _selectedLottery == lotteryName;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _VisionGlassSelectable(
                text: lotteryName,
                selected: selected,
                locked: !_isVipLogic,   // ⭐ FREE USERS SEE LOCKED
                vipTag: true,      // ⭐ Shows VIP badge
                onTap: () {
                  if (!_isVipLogic) {
                    _showVipUpsellDialog(); // ⭐ FREE USERS GET UPGRADE POPUP
                    return;
                  }

                  // ⭐ VIP user selects normally
                  setState(() => _selectedLottery = lotteryName);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}



// -------------------------------------------------------
// 🔵 VisionGlass Selectable Row — FULL FIXED VERSION
// -------------------------------------------------------
class _VisionGlassSelectable extends StatelessWidget {
  final String text;
  final bool selected;
  final bool locked;
  final bool vipTag;
  final VoidCallback onTap;

  const _VisionGlassSelectable({
    required this.text,
    required this.selected,
    required this.locked,
    required this.vipTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = locked
        ? Colors.white.withOpacity(0.20)
        : selected
        ? const Color(0xFF72FFD6).withOpacity(0.80)
        : Colors.white.withOpacity(0.18);

    final gradientColors = locked
        ? [
      Colors.white.withOpacity(0.04),
      Colors.white.withOpacity(0.02),
    ]
        : selected
        ? [
      const Color(0xFF00FEFC).withOpacity(0.36),
      const Color(0xFF72FFD6).withOpacity(0.29),
    ]
        : [
      Colors.white.withOpacity(0.08),
      Colors.white.withOpacity(0.03),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.65 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.6 : 1.1,
                ),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              // 🔥 FIXED ROW (Overflow-proof)
              child: Row(
                children: [
                  // LEFT SIDE — Text + Optional VIP Tag
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (vipTag) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00FEFC).withOpacity(0.45),
                                  const Color(0xFF72FFD6).withOpacity(0.35),
                                ],
                              ),
                            ),
                            child: Text(
                              "VIP",
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // RIGHT SIDE ICON
                  locked
                      ? Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: Colors.white.withOpacity(0.85),
                  )
                      : Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withOpacity(0.80),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// -------------------------------------------------------
// 💎 VisionGlass Primary Button
// -------------------------------------------------------
class _VisionGlassPrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _VisionGlassPrimaryButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Stack(
          children: [
            // Outer glow
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00FEFC).withOpacity(0.40),
                    const Color(0xFF72FFD6).withOpacity(0.40),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FEFC).withOpacity(0.30),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Inner glass
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
