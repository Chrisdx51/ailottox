// 🧬 AILottoX — Custom Pick Screen (HyperGlass Edition)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class CustomPickScreen extends StatefulWidget {
  const CustomPickScreen({super.key});

  @override
  State<CustomPickScreen> createState() => _CustomPickScreenState();
}

class _CustomPickScreenState extends State<CustomPickScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _bonusRangeController = TextEditingController();

  bool _includeBonus = false;

  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    _countController.dispose();
    _rangeController.dispose();
    _bonusRangeController.dispose();
    super.dispose();
  }

  void _continue() {
    final count = int.tryParse(_countController.text.trim());
    final rangeMax = int.tryParse(_rangeController.text.trim());
    final bonusRange = int.tryParse(_bonusRangeController.text.trim());

    // BASIC VALIDATION
    if (count == null || count < 1) {
      _show("Please enter how many numbers to generate.");
      return;
    }
    if (rangeMax == null || rangeMax < count) {
      _show("Please enter a valid main number range.");
      return;
    }
    if (_includeBonus && (bonusRange == null || bonusRange < 2)) {
      _show("Please enter a valid bonus number range.");
      return;
    }

    Navigator.pop(
      context,
      CustomPickData(
        count: count,
        rangeMax: rangeMax,
        includeBonus: _includeBonus,
        bonusRangeMax: bonusRange,
      ),
    );
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SingleChildScrollView(
                child: _GlassPanel(
                  glow: _glow,
                  countController: _countController,
                  rangeController: _rangeController,
                  bonusController: _bonusRangeController,
                  includeBonus: _includeBonus,
                  onBonusToggle: (v) => setState(() => _includeBonus = v),
                  onContinue: _continue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODEL FOR RETURNING CUSTOM PICK SETTINGS
// ---------------------------------------------------------------------------

class CustomPickData {
  final int count;
  final int rangeMax;
  final bool includeBonus;
  final int? bonusRangeMax;

  CustomPickData({
    required this.count,
    required this.rangeMax,
    required this.includeBonus,
    this.bonusRangeMax,
  });
}

// ---------------------------------------------------------------------------
// GLASS PANEL (Main Container)
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final AnimationController glow;
  final TextEditingController countController;
  final TextEditingController rangeController;
  final TextEditingController bonusController;
  final bool includeBonus;
  final void Function(bool) onBonusToggle;
  final VoidCallback onContinue;

  const _GlassPanel({
    required this.glow,
    required this.countController,
    required this.rangeController,
    required this.bonusController,
    required this.includeBonus,
    required this.onBonusToggle,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Logo
              ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.05)
                    .animate(CurvedAnimation(parent: glow, curve: Curves.easeInOut)),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FEFC).withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset("assets/images/logo1.png"),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                "Custom Number Settings",
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFFDAF7FF),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Define how many numbers you need\nand the range they can come from.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

              const SizedBox(height: 26),

              _GlassField(
                label: "How Many Numbers?",
                hint: "e.g. 6",
                controller: countController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              _GlassField(
                label: "Main Number Range",
                hint: "e.g. Max 50 → type 50",
                controller: rangeController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 26),

              // Bonus Ball Toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      "Include Bonus Ball?",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ),
                  Switch(
                    value: includeBonus,
                    onChanged: onBonusToggle,
                    activeColor: const Color(0xFF00FEFC),
                  ),
                ],
              ),


              if (includeBonus) ...[
                const SizedBox(height: 18),
                _GlassField(
                  label: "Bonus Ball Range",
                  hint: "e.g. Max 12",
                  controller: bonusController,
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: 30),

              _ContinueButton(onTap: onContinue),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GLASS FIELD
// ---------------------------------------------------------------------------

class _GlassField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _GlassField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.88),
          ),
        ),
        const SizedBox(height: 6),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.30)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.16),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CONTINUE BUTTON
// ---------------------------------------------------------------------------

class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00FEFC).withOpacity(0.35),
              const Color(0xFF72FFD6).withOpacity(0.35),
              const Color(0xFF8BFFDE).withOpacity(0.35),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FEFC).withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            "Continue",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
