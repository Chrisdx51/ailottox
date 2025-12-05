// 🧬 AILottoX — Input Screen (VIP Magic + Remember Me Edition)

import 'dart:ui';
import 'dart:convert'; // ⭐ For saving profile as JSON

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/user_profile.dart';
import 'lottery_selection_screen.dart';
import 'package:ai_lotto_generator/ad_ids.dart';

class AILottoXInputScreen extends StatefulWidget {
  const AILottoXInputScreen({super.key});

  @override
  State<AILottoXInputScreen> createState() => _AILottoXInputScreenState();
}

class _AILottoXInputScreenState extends State<AILottoXInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customColourController = TextEditingController();

  // VIP magic text fields
  final TextEditingController _auraController = TextEditingController();
  final TextEditingController _spiritController = TextEditingController();

  DateTime? _selectedDob;

  // 8 colours → 4 per row
  final List<_ColourChoice> _colours = const [
    _ColourChoice(name: "Red", color: Color(0xFFFF6B6B)),
    _ColourChoice(name: "Orange", color: Color(0xFFFFA552)),
    _ColourChoice(name: "Yellow", color: Color(0xFFFFF176)),
    _ColourChoice(name: "Green", color: Color(0xFF6EFFB5)),
    _ColourChoice(name: "Blue", color: Color(0xFF4FC3F7)),
    _ColourChoice(name: "Indigo", color: Color(0xFF7E57C2)),
    _ColourChoice(name: "Violet", color: Color(0xFFE040FB)),
    _ColourChoice(name: "White", color: Color(0xFFFFFFFF)),
  ];

  String? _selectedColourName;

  // VIP tuning state
  double _energyLevel = 50; // 0–100 slider
  String _selectedElement = "Air";
  TimeOfDay _luckyHour = const TimeOfDay(hour: 19, minute: 0);

  // Remember Me toggle (for everyone)
  bool _rememberMe = false;

  late AnimationController _glow;
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // ⭐ Load Banner Ad (VIP-safe)
    if (!isVip) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdIds.bannerTop,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            setState(() {
              _isBannerReady = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
        request: const AdRequest(),
      )..load();
    }

    // ⭐ Try to auto-fill from stored profile
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customColourController.dispose();
    _auraController.dispose();
    _spiritController.dispose();
    _glow.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🔁 Remember Me — Load saved profile (if enabled)
  // ----------------------------------------------------------
  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('ailottox_remember_me') ?? false;
    if (!remember) return;

    final raw = prefs.getString('ailottox_profile');
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _rememberMe = true;

        _nameController.text = data['name'] ?? '';

        final dobStr = data['dob'] as String?;
        if (dobStr != null) {
          _selectedDob = DateTime.tryParse(dobStr);
        }

        _selectedColourName = data['selectedColourName'] as String?;
        _customColourController.text = data['customColour'] as String? ?? '';

        // VIP magic (safe even if not VIP)
        _energyLevel = (data['energy'] as num?)?.toDouble() ?? 50;
        _selectedElement = data['element'] as String? ?? "Air";

        final h = data['luckyHourH'] as int?;
        final m = data['luckyHourM'] as int?;
        if (h != null && m != null) {
          _luckyHour = TimeOfDay(hour: h, minute: m);
        }

        _auraController.text = data['auraTone'] as String? ?? '';
        _spiritController.text = data['spiritAnimal'] as String? ?? '';
      });
    } catch (_) {
      // If anything goes wrong, just ignore and show empty form
    }
  }

  // ----------------------------------------------------------
  // 💾 Remember Me — Save or clear stored profile
  // ----------------------------------------------------------
  Future<void> _handleRemember(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      final map = {
        "name": profile.name,
        "dob": profile.dob.toIso8601String(),
        "colour": profile.colour,
        "selectedColourName": _selectedColourName,
        "customColour": _customColourController.text.trim(),
        "energy": _energyLevel,
        "element": _selectedElement,
        "luckyHourH": _luckyHour.hour,
        "luckyHourM": _luckyHour.minute,
        "auraTone": _auraController.text.trim(),
        "spiritAnimal": _spiritController.text.trim(),
      };

      await prefs.setBool('ailottox_remember_me', true);
      await prefs.setString('ailottox_profile', jsonEncode(map));
    } else {
      await prefs.remove('ailottox_remember_me');
      await prefs.remove('ailottox_profile');
    }
  }

  // ----------------------------------------------------------
  // Modern Glass DOB Picker (Cupertino scroll wheel)
  // ----------------------------------------------------------
  Future<void> _pickDob() async {
    // Close keyboard before opening picker
    FocusScope.of(context).unfocus();

    DateTime tempDate = _selectedDob ?? DateTime(1990, 1, 1);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Select Date of Birth",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        maximumYear: DateTime.now().year - 18,
                        minimumYear: DateTime.now().year - 100,
                        initialDateTime: tempDate,
                        onDateTimeChanged: (value) {
                          tempDate = value;
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDob = tempDate);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00FEFC).withOpacity(0.4),
                              const Color(0xFF72FFD6).withOpacity(0.4),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Confirm",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // 🕒 Lucky Hour picker (VIP magic)
  // ----------------------------------------------------------
  Future<void> _pickLuckyHour() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _luckyHour,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FEFC),
              surface: Color(0xFF050814),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _luckyHour = picked;
      });
    }
  }

  // ----------------------------------------------------------
  // ✅ SAVE and move to Lottery Selection
  // ----------------------------------------------------------
  void _save() async {
    final name = _nameController.text.trim();
    final custom = _customColourController.text.trim();
    final colour = _selectedColourName ?? custom;

    if (name.isEmpty || _selectedDob == null || colour.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields.")),
      );
      return;
    }

    final profile = UserProfile(
      name: name,
      dob: _selectedDob!,
      colour: colour,
    );

    // ⭐ Remember Me (for everyone) — store or clear
    await _handleRemember(profile);

    // Navigate to Lottery Selection Screen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LotterySelectionScreen(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let Flutter resize when keyboard opens
      resizeToAvoidBottomInset: true,
      body: LiquidBackground(
        child: Column(
          children: [
            // ⭐ Banner safely below the device status bar
            if (!isVip && _isBannerReady)
              SafeArea(
                top: true,
                bottom: false,
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),


            // ⭐ Page content scrolls under the banner cleanly
            Expanded(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 22,
                        right: 22,
                        top: 0,
                        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _GlassPanel(
                            glow: _glow,
                            nameController: _nameController,
                            customColourController: _customColourController,
                            auraController: _auraController,
                            spiritController: _spiritController,
                            dob: _selectedDob,
                            onPickDob: _pickDob,
                            colours: _colours,
                            selected: _selectedColourName,
                            onColourTap: (c) {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _selectedColourName = c;
                                _customColourController.clear();
                              });
                            },
                            // Remember Me
                            rememberMe: _rememberMe,
                            onRememberMeChanged: (value) {
                              setState(() {
                                _rememberMe = value;
                              });
                            },
                            // VIP magic
                            energyLevel: _energyLevel,
                            onEnergyChanged: (value) {
                              setState(() {
                                _energyLevel = value;
                              });
                            },
                            selectedElement: _selectedElement,
                            onElementChanged: (value) {
                              setState(() {
                                _selectedElement = value;
                              });
                            },
                            luckyHour: _luckyHour,
                            onPickLuckyHour: _pickLuckyHour,
                            onSave: _save,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

class _ColourChoice {
  final String name;
  final Color color;
  const _ColourChoice({required this.name, required this.color});
}

// ---------------------------------------------------------------------------
// MAIN GLASS PANEL
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  final AnimationController glow;
  final TextEditingController nameController;
  final TextEditingController customColourController;
  final TextEditingController auraController;
  final TextEditingController spiritController;
  final DateTime? dob;
  final VoidCallback onPickDob;

  final List<_ColourChoice> colours;
  final String? selected;
  final void Function(String) onColourTap;

  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;

  // VIP magic
  final double energyLevel;
  final ValueChanged<double> onEnergyChanged;
  final String selectedElement;
  final ValueChanged<String> onElementChanged;
  final TimeOfDay luckyHour;
  final VoidCallback onPickLuckyHour;

  final VoidCallback onSave;

  const _GlassPanel({
    required this.glow,
    required this.nameController,
    required this.customColourController,
    required this.auraController,
    required this.spiritController,
    required this.dob,
    required this.onPickDob,
    required this.colours,
    required this.selected,
    required this.onColourTap,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.energyLevel,
    required this.onEnergyChanged,
    required this.selectedElement,
    required this.onElementChanged,
    required this.luckyHour,
    required this.onPickLuckyHour,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Larger glowing logo
              ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.05).animate(
                  CurvedAnimation(parent: glow, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 95,
                  height: 95,
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

              const SizedBox(height: 18),

              // Smaller title
              Text(
                "Enter Your Details",
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFFDAF7FF),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Your details help AI Lotto X craft a personalised\nlucky number sequence made just for you.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.38,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

              const SizedBox(height: 24),

              _GlassField(
                label: "Your Name",
                controller: nameController,
                hint: "Enter your first name",
              ),

              const SizedBox(height: 18),

              _DobField(
                dob: dob,
                onTap: onPickDob,
              ),

              const SizedBox(height: 22),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choose Favourite Colour",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.88),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 4 per row fixed grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                childAspectRatio: 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                physics: const NeverScrollableScrollPhysics(),
                children: colours.map((c) {
                  return _ColourBubble(
                    choice: c,
                    isSelected: selected == c.name,
                    onTap: () => onColourTap(c.name),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              _GlassField(
                label: "Or Type Your Colour",
                controller: customColourController,
                hint: "Type your colour (if not listed)",
              ),

              const SizedBox(height: 18),

              // ⭐ Remember Me row (for everyone)
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (value) =>
                        onRememberMeChanged(value ?? false),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.70),
                      width: 1,
                    ),
                    checkColor: Colors.black,
                    activeColor: const Color(0xFF00FEFC),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Remember my details for next time",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                  ),
                ],
              ),

              // ⭐ VIP Magic Block (only when VIP)
              if (isVip) ...[
                const SizedBox(height: 22),
                _VipMagicPanel(
                  energyLevel: energyLevel,
                  onEnergyChanged: onEnergyChanged,
                  selectedElement: selectedElement,
                  onElementChanged: onElementChanged,
                  luckyHour: luckyHour,
                  onPickLuckyHour: onPickLuckyHour,
                  auraController: auraController,
                  spiritController: spiritController,
                ),
              ],

              const SizedBox(height: 24),

              _SaveButton(onTap: () {
                FocusScope.of(context).unfocus();
                onSave();
              }),
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

  const _GlassField({
    required this.label,
    required this.hint,
    required this.controller,
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
// DOB FIELD (short label, no overflow)
// ---------------------------------------------------------------------------

class _DobField extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onTap;

  const _DobField({required this.dob, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = dob == null
        ? "DD / MM / YYYY"
        : "${dob!.day.toString().padLeft(2, '0')}/"
        "${dob!.month.toString().padLeft(2, '0')}/"
        "${dob!.year}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DOB",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.88),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: dob == null
                            ? Colors.white.withOpacity(0.55)
                            : Colors.white,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ],
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
// NEON COLOUR BUBBLE
// ---------------------------------------------------------------------------

class _ColourBubble extends StatelessWidget {
  final _ColourChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColourBubble({
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 32 : 26,
        height: isSelected ? 32 : 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              choice.color.withOpacity(0.95),
              choice.color.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: choice.color.withOpacity(0.65),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
              : [],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VIP MAGIC PANEL
// ---------------------------------------------------------------------------

class _VipMagicPanel extends StatelessWidget {
  final double energyLevel;
  final ValueChanged<double> onEnergyChanged;
  final String selectedElement;
  final ValueChanged<String> onElementChanged;
  final TimeOfDay luckyHour;
  final VoidCallback onPickLuckyHour;
  final TextEditingController auraController;
  final TextEditingController spiritController;

  const _VipMagicPanel({
    required this.energyLevel,
    required this.onEnergyChanged,
    required this.selectedElement,
    required this.onElementChanged,
    required this.luckyHour,
    required this.onPickLuckyHour,
    required this.auraController,
    required this.spiritController,
  });

  @override
  Widget build(BuildContext context) {
    final elements = ["Air", "Fire", "Water", "Earth", "Ether"];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00FEFC).withOpacity(0.45),
              width: 1.1,
            ),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00FEFC).withOpacity(0.24),
                const Color(0xFF72FFD6).withOpacity(0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "VIP Lucky Pattern Boost",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 0.8,
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
              ),


              const SizedBox(height: 10),

              // Energy slider
              Text(
                "Intensity Boost",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: const Color(0xFF00FEFC),
                  inactiveTrackColor: Colors.white.withOpacity(0.18),
                  thumbColor: const Color(0xFF00FEFC),
                ),
                child: Slider(
                  min: 0,
                  max: 100,
                  value: energyLevel.clamp(0, 100),
                  onChanged: onEnergyChanged,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${energyLevel.round()}%",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Element chips
              Text(
                "Element Focus",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: elements.map((e) {
                  final selected = e == selectedElement;
                  return GestureDetector(
                    onTap: () => onElementChanged(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF00FEFC)
                              : Colors.white.withOpacity(0.30),
                          width: 0.9,
                        ),
                        gradient: LinearGradient(
                          colors: selected
                              ? [
                            Colors.white.withOpacity(0.18),
                            Colors.white.withOpacity(0.06),
                          ]
                              : [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                      ),
                      child: Text(
                        e,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Lucky hour
              Text(
                "Lucky Hour Boost",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onPickLuckyHour,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.30)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        luckyHour.format(context),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.80),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Aura tone
              _GlassField(
                label: "Aura Tone (VIP)",
                controller: auraController,
                hint: "e.g. Electric calm, deep glow",
              ),

              const SizedBox(height: 10),

              // Spirit animal
              _GlassField(
                label: "Spirit Animal (VIP)",
                controller: spiritController,
                hint: "e.g. Wolf, Hawk, Dolphin",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SAVE BUTTON
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveButton({required this.onTap});

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
            "Continue to Lottery Options",
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
