import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_ids.dart';      // ⭐ using your real Ad IDs
import '../main.dart';       // for isVip flag

class MoodCastBanner extends StatefulWidget {
  const MoodCastBanner({super.key});

  @override
  State<MoodCastBanner> createState() => _MoodCastBannerState();
}

class _MoodCastBannerState extends State<MoodCastBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    // ⭐ VIP → hide ads completely
    if (isVip) return;

    _bannerAd = BannerAd(
      adUnitId: AdIds.bannerTop, // ⭐ uses your real ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint("MoodCast banner failed: $error");
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VIP → no ads
    if (isVip) return const SizedBox.shrink();

    if (!_isLoaded) {
      return const SizedBox(height: 0);
    }

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
