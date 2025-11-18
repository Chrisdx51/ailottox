import 'dart:convert';
import 'dart:ui'; // ⭐ ADD THIS LINE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_lotto_generator/ad_ids.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();

    // ⭐ VIP-SAFE Banner
    if (!isVip) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdIds.bannerTop,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _isBannerReady = true),
          onAdFailedToLoad: (ad, err) => ad.dispose(),
        ),
      )..load();
    }
  }

  // ⭐ Load + VIP unlimited history logic
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList("history") ?? [];

    List<Map<String, dynamic>> list =
    saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    // NEWEST FIRST
    list.sort((a, b) {
      final da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      final db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return db.compareTo(da);
    });

    // FREE USERS TRIM TO LAST 10 ONLY
    if (!isVip) {
      if (list.length > 10) {
        list = list.sublist(0, 10);
        await prefs.setStringList(
          "history",
          list.map((e) => jsonEncode(e)).toList(),
        );
      }
    }

    setState(() {
      _history = list;
      _loading = false;
    });
  }

  // ⭐ Delete entry
  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setStringList(
      "history",
      _history.map((e) => jsonEncode(e)).toList(),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ⭐ Banner Ad
            if (!isVip && _isBannerReady)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),

            // ⭐ Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Text(
                      "← Home",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "History",
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDAF7FF),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? _loadingWidget()
                  : _history.isEmpty
                  ? _emptyWidget()
                  : _listWidget(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  Widget _loadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Text(
        "No saved patterns yet.\nGenerate your first AILottoX sequence!",
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  Widget _listWidget() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];

        final lottery = item["lottery"] ?? "Unknown";
        final main = List<int>.from(item["main"] ?? []);
        final bonus = List<int>.from(item["bonus"] ?? []);
        final date = DateTime.tryParse(item["date"] ?? "") ?? DateTime.now();

        return Dismissible(
          key: Key("item_$index"),
          direction: DismissDirection.endToStart,
          background: _deleteBg(),
          onDismissed: (_) => _deleteItem(index),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _glassCard(
              lottery: lottery,
              main: main,
              bonus: bonus,
              date: date,
            ),
          ),
        );
      },
    );
  }

  // ⭐ Vision Delete Background
  Widget _deleteBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete, color: Colors.white, size: 26),
    );
  }

  // ---------------------------------------------------------
  // ⭐ Modern VisionGlass History Card
  // ---------------------------------------------------------
  Widget _glassCard({
    required String lottery,
    required List<int> main,
    required List<int> bonus,
    required DateTime date,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lottery,
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDAF7FF),
                    ),
                  ),
                  Text(
                    _format(date),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // MAIN NUMBERS
              Text(
                "Main Numbers",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: main.map((n) => _ball(n, false)).toList(),
              ),

              if (bonus.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "Bonus",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: bonus.map((n) => _ball(n, true)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Premium Number Ball (Bigger + Softer)
  Widget _ball(int n, bool bonus) {
    final Color col = bonus
        ? const Color(0xFF72FFD6)
        : const Color(0xFF00FEFC);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            col.withOpacity(0.90),
            col.withOpacity(0.45),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: col.withOpacity(0.35),
            blurRadius: 14,
          ),
        ],
      ),
      child: Center(
        child: Text(
          n.toString(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  String _format(DateTime d) {
    return "${d.day}/${d.month}/${d.year}";
  }
}
