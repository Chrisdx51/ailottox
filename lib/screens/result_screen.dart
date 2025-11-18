// 🧬 AILottoX — Result Screen (HyperGlass + AI Reflection v4)

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/user_profile.dart';
import 'package:audioplayers/audioplayers.dart';

class ResultScreen extends StatefulWidget {
  final UserProfile profile;
  final String lotteryName;
  final List<int> mainNumbers;
  final List<int> bonusNumbers;
  final bool isVip;
  final String? vipMode; // ⭐ NEW

  const ResultScreen({
    super.key,
    required this.profile,
    required this.lotteryName,
    required this.mainNumbers,
    required this.bonusNumbers,
    required this.isVip,
    this.vipMode,  // ⭐ NEW
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late ConfettiController _confetti;
  late VideoPlayerController _bgVideo;
  bool _videoReady = false;
  // 🔊 Audio players
  late final AudioPlayer _sfxPlayer;    // small ping
  late final AudioPlayer _voicePlayer;  // ElevenLabs later
  bool _isReading = false;              // is TTS playing?

  // AI text
  String _fullAffirmation = "";
  String _shownAffirmation = "";
  String _vipExplanation = "";
  String? _aiError;
  bool _loadingAffirmation = true;
  bool _loadingVip = false;
  Timer? _typeTimer;

  // number reveal
  int _visibleCount = 0;

  // AILottoX accent (same as home screen)
  Color get _accent => const Color(0xFF00FEFC);

  Color get _accentSoft => const Color(0xFF72FFD6);

  @override
  void initState() {
    super.initState();

    _sfxPlayer = AudioPlayer();
    _voicePlayer = AudioPlayer();
    _autoSaveToHistory();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..repeat();

    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
// ⭐ VIP Nebula Background Video
    if (widget.isVip) {
      _bgVideo = VideoPlayerController.asset(
        'assets/video/background.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..setLooping(true)
        ..setVolume(0.0)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _videoReady = true);
            _bgVideo.play();
          }
        });
    }

    _startNumberReveal();
    _fetchAffirmation();
    if (widget.isVip) {
      _fetchVipExplanation();
    }
    // -----------------------------------------
// 🔄 Force screen refresh every second
// (Needed so rotating messages actually rotate)
// -----------------------------------------
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});  // <-- refreshes the UI automatically
    });
  }

  Future<void> _playCelebrate() async {
    try {
      await _sfxPlayer.play(AssetSource('audio/result_ping.mp3'));
    } catch (_) {
      // we silently ignore errors – no crash if audio fails
    }
  }


  @override
  void dispose() {
    _pulse.dispose();
    _confetti.dispose();
    _typeTimer?.cancel();

    if (widget.isVip) {
      _bgVideo.dispose();
    }
    _sfxPlayer.dispose();    // 🔊 new
    _voicePlayer.dispose();  // 🔊 new

    super.dispose();
  }


  // 🔢 reveal numbers one by one
  void _startNumberReveal() {
    final total = widget.mainNumbers.length + widget.bonusNumbers.length;
    for (int i = 0; i < total; i++) {
      Future.delayed(Duration(milliseconds: 900 * (i + 1)), () {
        if (!mounted) return;
        setState(() {
          _visibleCount = i + 1;
        });
      });
    }
  }

  Future<void> _autoSaveToHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing list
    List<String> saved = prefs.getStringList("history") ?? [];

    // Build the new entry (JSON string)
    final entry = jsonEncode({
      "lottery": widget.lotteryName,
      "main": widget.mainNumbers,
      "bonus": widget.bonusNumbers,
      "date": DateTime.now().toIso8601String(),
    });

    // Add to top of the list
    saved.insert(0, entry);

    // Free users: keep last 10
// VIP users: unlimited
    if (!widget.isVip) {
      if (saved.length > 10) {
        saved = saved.sublist(0, 10);
      }
    }


    // Save back
    await prefs.setStringList("history", saved);
  }

  // ✨ fetch affirmation from /ailottox/affirmation (streamed text)
  Future<void> _fetchAffirmation() async {
    setState(() {
      _loadingAffirmation = true;
      _aiError = null;
    });

    try {
      final uri = Uri.parse(
        'https://auranaguidance.co.uk/api/ailottox/affirmation',
      );

      final body = jsonEncode({
        "name": widget.profile.name,
        "lottery": widget.lotteryName,
        "numbers": widget.mainNumbers,
        "bonus_numbers": widget.bonusNumbers,
        "mode": widget.isVip ? "vip" : "standard",
      });

      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (res.statusCode != 200) {
        setState(() {
          _aiError =
          "Could not load your reflection right now. You can still use your numbers.";
          _loadingAffirmation = false;
        });
        return;
      }

      final text = res.body.trim();
      if (!mounted) return;

      setState(() {
        _fullAffirmation = text;
        _shownAffirmation = "";
        _loadingAffirmation = false;
      });

      _startTypewriter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError =
        "Connection issue while loading your reflection. You can still use your numbers.";
        _loadingAffirmation = false;
      });
    }
  }

  void _startTypewriter() {
    _typeTimer?.cancel();
    const delay = Duration(milliseconds: 32);
    int index = 0;

    _typeTimer = Timer.periodic(delay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index >= _fullAffirmation.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _shownAffirmation += _fullAffirmation[index];
        index++;
      });
    });
  }

  // 👑 VIP explanation
  Future<void> _fetchVipExplanation() async {
    setState(() {
      _loadingVip = true;
    });

    try {
      final uri = Uri.parse(
        'https://auranaguidance.co.uk/api/ailottox/vip_explain',
      );

      final body = jsonEncode({
        "name": widget.profile.name,
        "dob": widget.profile.dob.toIso8601String(),
        "colour": widget.profile.colour,
        "lottery": widget.lotteryName,
        "main_numbers": widget.mainNumbers,
        "bonus_numbers": widget.bonusNumbers,
      });

      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = (data["vip_text"] as String?)?.trim() ?? "";
        if (!mounted) return;
        setState(() {
          _vipExplanation = text;
          _loadingVip = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loadingVip = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVip = false;
      });
    }
  }

  // 📥 Save draw — placeholder for history
  void _onSaveDraw() {
    final snackBar = SnackBar(
      content: Text(
        "This draw has been saved. You’ll soon see it in your History.",
        style: GoogleFonts.poppins(fontSize: 12),
      ),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // 📤 Share pattern via OS share sheet
  void _onShare() {
    final main = widget.mainNumbers.join(", ");
    final bonus = widget.bonusNumbers.isNotEmpty
        ? " | Bonus: ${widget.bonusNumbers.join(", ")}"
        : "";

    final text =
        "My AILottoX numbers for ${widget
        .lotteryName}:\nMain: $main$bonus\n\nGenerated with the AILottoX app.";

    Share.share(text, subject: "My AILottoX Numbers");
  }

  // 🏠 Back to home (clear back stack)
  void _onBackToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _onBackToHome();
        return false;
      },
      child: Scaffold(
        body: LiquidBackground(
          child: Stack(
            children: [

              // ⭐ STEP 11 — VIP FULLSCREEN VIDEO (BACKGROUND)
              if (widget.isVip && _videoReady)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _bgVideo.value.size.width,
                      height: _bgVideo.value.size.height,
                      child: VideoPlayer(_bgVideo),
                    ),
                  ),
                ),

              // ⭐ CONFETTI (unchanged)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.05,
                  numberOfParticles: 35,
                  gravity: 0.10,
                  shouldLoop: false,
                ),
              ),

              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),

                        child: Stack(
                          children: [

                            // ⭐ STEP 12 — VIP VIDEO INSIDE THE GLASS PANEL
                            if (widget.isVip && _videoReady)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _bgVideo.value.size.width,
                                      height: _bgVideo.value.size.height,
                                      child: VideoPlayer(_bgVideo),
                                    ),
                                  ),
                                ),
                              ),

                            // ⭐ MAIN GLASS PANEL CONTENT
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 26,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: widget.isVip
                                      ? const Color(0xFF72FFD6).withOpacity(0.32)
                                      : Colors.white.withOpacity(0.10),
                                  width: widget.isVip ? 1.4 : 1,
                                ),
                                gradient: LinearGradient(
                                  colors: widget.isVip
                                      ? [
                                    Colors.white.withOpacity(0.10),
                                    Colors.white.withOpacity(0.04),
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildLogo(),
                                    const SizedBox(height: 18),
                                    _buildTitle(),
                                    const SizedBox(height: 6),
                                    _buildSubtitle(),
                                    const SizedBox(height: 16),

                                    _buildLotteryHeaderBar(),
                                    const SizedBox(height: 22),

                                    _buildMainNumbers(),

                                    if (widget.bonusNumbers.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      _buildBonusNumbers(),
                                    ],

                                    const SizedBox(height: 24),

                                    _buildDescription(),
                                    const SizedBox(height: 16),

                                    _buildAffirmationCard(),

                                    if (widget.isVip) ...[
                                      const SizedBox(height: 14),
                                      _buildVipCard(),
                                    ],

                                    const SizedBox(height: 26),

                                    _VisionGlassPrimaryButton(
                                      text: "Save This Draw",
                                      accent: _accent,
                                      onTap: _onSaveDraw,
                                    ),

                                    const SizedBox(height: 12),

                                    _VisionGlassSecondaryButton(
                                      text: "Share Pattern",
                                      onTap: _onShare,
                                    ),

                                    const SizedBox(height: 10),

                                    _VisionGlassSecondaryButton(
                                      text: "Back to Home",
                                      onTap: _onBackToHome,
                                    ),

                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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



  // -------------------------------------------------------
  // UI sections
  // -------------------------------------------------------

  Widget _buildLogo() {
    final bool vip = widget.isVip;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final scale = 0.96 + 0.04 * math.sin(t * 2 * math.pi);

        return Stack(
          alignment: Alignment.center,
          children: [

            // ⭐ VIP ONLY — Glowing Crown Aura Behind Logo
            if (vip)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF72FFD6).withOpacity(0.40 + 0.15 * math.sin(t * 2 * math.pi)),
                      const Color(0xFF00FEFC).withOpacity(0.20),
                      Colors.transparent,
                    ],
                    radius: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF72FFD6).withOpacity(0.45),
                      blurRadius: 45,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),

            // ⭐ Actual Pulsing Logo (still animated)
            Transform.scale(
              scale: scale,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.45),
                      blurRadius: 35,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    "assets/images/logo1.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildTitle() {
    final bool vip = widget.isVip;

    return Text(
      "Your AI Lotto X Pattern",
      textAlign: TextAlign.center,
      style: GoogleFonts.orbitron(
        fontSize: vip ? 20 : 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: vip
            ? const Color(0xFF72FFD6) // soft VIP mint glow
            : const Color(0xFFDAF7FF),
        // normal ice blue
        shadows: vip
            ? [
          Shadow(
            color: const Color(0xFF72FFD6).withOpacity(0.75),
            blurRadius: 16,
          ),
        ]
            : [],
      ),
    );
  }


  Widget _buildSubtitle() {
    final bool vip = widget.isVip;

    return Text(
      "${widget.lotteryName} • ${vip ? "VIP Mode" : "Standard"}",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: vip
            ? const Color(0xFF72FFD6).withOpacity(0.95) // VIP mint
            : Colors.white.withOpacity(0.82), // normal
        shadows: vip
            ? [
          Shadow(
            color: const Color(0xFF72FFD6).withOpacity(0.55),
            blurRadius: 12,
          ),
        ]
            : [],
      ),
    );
  }


  // 🔷 Glass header bar instead of red pill
  Widget _buildLotteryHeaderBar() {
    final bool vip = widget.isVip;

    final Color vipAccent = const Color(0xFF00FEFC); // cyan
    final Color vipAccentSoft = const Color(0xFF72FFD6); // mint

    return Stack(
      children: [
        // 🌟 BACK GLOW (VIP stronger)
        Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: vip
                  ? [
                vipAccent.withOpacity(0.45),
                vipAccentSoft.withOpacity(0.45),
              ]
                  : [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: vip
                    ? vipAccent.withOpacity(0.35)
                    : Colors.black.withOpacity(0.10),
                blurRadius: vip ? 24 : 14,
                spreadRadius: vip ? 4 : 1,
              ),
            ],
          ),
        ),

        // 🌟 GLASS LAYER
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: vip
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.25),
                  width: vip ? 1.2 : 1,
                ),
                gradient: LinearGradient(
                  colors: vip
                      ? [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.10),
                  ]
                      : [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  "Pattern tuned for ${widget.lotteryName}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildDescription() {
    return Text(
      "These numbers were shaped around your saved details. "
          "If they feel good to you, you can use them on your next ticket. "
          "Always play for fun and keep it within your limits.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 10,
        height: 1.4,
        color: Colors.white.withOpacity(0.80),
      ),
    );
  }

  Widget _buildAffirmationCard() {
    // ❌ If AI failed → show friendly fallback
    if (_aiError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.03),
            ],
          ),
        ),
        child: Text(
          _aiError!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            height: 1.4,
            color: Colors.white.withOpacity(0.80),
          ),
        ),
      );
    }

    // ⭐ Rotating AI thinking messages
    final List<String> loadingMessages = [
      "Tuning a short reflection for your pattern...",
      "Aligning your pattern with your profile...",
      "Finding softer meaning behind the numbers...",
      "Shaping an intuitive reflection...",
      "Almost there..."
    ];

    final String message =
    loadingMessages[DateTime.now().second % loadingMessages.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isVip
              ? _accentSoft.withOpacity(0.45)
              : Colors.white.withOpacity(0.16),
          width: widget.isVip ? 1.4 : 1.0,
        ),
        gradient: LinearGradient(
          colors: widget.isVip
              ? [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.06),
          ]
              : [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),

      child: SizedBox(
        height: 120,
        child: _loadingAffirmation
            ? Center(
          child: Text(
            message,  // ⭐ NEW animated message
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              height: 1.4,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
        )
            : SingleChildScrollView(
          child: Text(
            _shownAffirmation,
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.45,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
        ),
      ),
    );
  }




  Widget _buildVipCard() {
    // ⭐ VIP rotating deeper analysis messages
    final List<String> deepMessages = [
      "Reading the deeper structure of your pattern…",
      "Analysing the hidden symmetry in your numbers…",
      "Matching your profile traits to numerical behaviour…",
      "Tracing subtle sequences across the spread…",
      "Uncovering deeper signature patterns…"
    ];

    final String thinkingMessage =
    deepMessages[DateTime.now().second % deepMessages.length];

    // ⭐ While loading + no explanation yet
    if (_loadingVip && _vipExplanation.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _accentSoft.withOpacity(0.55),
            width: 1.3,
          ),
          gradient: LinearGradient(
            colors: [
              _accentSoft.withOpacity(0.15),
              _accent.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SizedBox(
          height: 130,
          child: Center(
            child: Text(
              thinkingMessage, // ⭐ NEW rotating message
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ),
        ),
      );
    }

    // ❌ If VIP text didn't return anything
    if (_vipExplanation.isEmpty) {
      return const SizedBox.shrink();
    }

    // ⭐ FINAL VIP PANEL (unchanged)
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: RadialGradient(
                radius: 1.3,
                colors: [
                  _accentSoft.withOpacity(0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 1.3,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIXED — prevents horizontal overflow
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: _accent.withOpacity(0.85),
                        size: 20,
                      ),
                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          "VIP Pattern Insight",
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _accent.withOpacity(0.95),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),


                  const SizedBox(height: 10),

                  SizedBox(
                    height: 155,
                    child: SingleChildScrollView(
                      child: Text(
                        _vipExplanation,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.45,
                          color: Colors.white.withOpacity(0.94),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }





  Widget _buildMainNumbers() {
    final bool vip = widget.isVip;
    final String mode = widget.vipMode ?? "Pure Random";

    // Make a modifiable copy
    final List<int> nums = List<int>.from(widget.mainNumbers);

    // VIP MODE: Balanced Spread → visually sorted only
    if (vip && mode == "Balanced Spread") {
      nums.sort();
    }

    // VIP MODE: Signature Set → bigger orbs + softer glow
    if (vip && mode == "Signature Set") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Main Numbers",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (int i = 0; i < nums.length; i++)
                _AnimatedOrb(
                  number: nums[i],
                  index: i,
                  isBonus: false,
                  controller: _pulse,
                  accent: _accentSoft,
                  // softer VIP glow
                  visible: i < _visibleCount,
                ),
            ],
          ),
        ],
      );
    }

    // VIP MODE: High-Energy Layout → glowing line behind orbs
    if (vip && mode == "High-Energy Layout") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Main Numbers",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 10),

          Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EnergyPainter(nums.length),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < nums.length; i++)
                    _AnimatedOrb(
                      number: nums[i],
                      index: i,
                      isBonus: false,
                      controller: _pulse,
                      accent: _accent,
                      // bright cyan glow
                      visible: i < _visibleCount,
                    ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    // DEFAULT — PURE RANDOM (free users)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Main Numbers",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.88),
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (int i = 0; i < widget.mainNumbers.length; i++)
              _AnimatedOrb(
                number: widget.mainNumbers[i],
                index: i,
                isBonus: false,
                controller: _pulse,
                accent: _accent,
                // normal cyan glow
                visible: i < _visibleCount,
              ),
          ],
        ),
      ],
    );
  }


  Widget _buildBonusNumbers() {
    final bool vip = widget.isVip;
    final String mode = widget.vipMode ?? "Pure Random";

    // Make a modifiable copy (for VIP sorted modes if needed)
    final List<int> nums = List<int>.from(widget.bonusNumbers);

    // VIP MODE: Balanced Spread → sorted visually
    if (vip && mode == "Balanced Spread") {
      nums.sort();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bonus",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (int i = 0; i < nums.length; i++)
              _AnimatedOrb(
                number: nums[i],
                index: i + widget.mainNumbers.length,
                isBonus: true,
                controller: _pulse,
                accent: vip
                    ? _accentSoft // ⭐ VIP mint glow
                    : _accentSoft,
                // ⭐ Free users also get soft mint for bonus
                visible: widget.mainNumbers.length + i < _visibleCount,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🔮 Animated Orb (with visibility flag)
// ---------------------------------------------------------------------------
class _AnimatedOrb extends StatelessWidget {
  final int number;
  final int index;
  final bool isBonus;
  final AnimationController controller;
  final Color accent;
  final bool visible;

  const _AnimatedOrb({
    required this.number,
    required this.index,
    required this.isBonus,
    required this.controller,
    required this.accent,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    // 1️⃣ Soft, slow breathing pulse (no jitter)
    final double softPulse =
        0.97 + 0.03 * math.sin(controller.value * 2 * math.pi);

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      child: AnimatedScale(
        scale: visible ? softPulse : 0.7,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withOpacity(0.9),
                accent.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _EnergyPainter extends CustomPainter {
  final int count;
  _EnergyPainter(this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FEFC).withOpacity(0.22)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final spacing = size.width / (count + 1);

    for (int i = 0; i < count - 1; i++) {
      final p1 = Offset(spacing * (i + 1), size.height * 0.52);
      final p2 = Offset(spacing * (i + 2), size.height * 0.52);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}


// ---------------------------------------------------------------------------
// 💎 VisionGlass Buttons (same style as before)
// ---------------------------------------------------------------------------
class _VisionGlassPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color accent;

  const _VisionGlassPrimaryButton({
    required this.text,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Outer Glow Layer
          Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.55),
                  accent.withOpacity(0.28),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.40),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),

          // Inner Glass Layer
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.3,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.16),
                      Colors.white.withOpacity(0.06),
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
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _VisionGlassSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _VisionGlassSecondaryButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.20),
                width: 1.1,
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

