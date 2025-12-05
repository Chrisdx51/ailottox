import 'dart:io';

class AdIds {
  // -------- APP ID (must match platform) --------
  static String get appId => Platform.isIOS
      ? 'ca-app-pub-5354629198133392~9874273599'  // iOS app ID
      : 'ca-app-pub-5354629198133392~4837525064'; // Android app ID


  // -------- TOP BANNER --------
  static String get bannerTop => Platform.isIOS
      ? 'ca-app-pub-5354629198133392/5274459707'  // iOS top banner
      : 'ca-app-pub-5354629198133392/1887261924'; // Android top banner


  // -------- INTERSTITIAL --------
  static String get interstitial => Platform.isIOS
      ? 'ca-app-pub-5354629198133392/9438448888'  // iOS interstitial
      : 'ca-app-pub-5354629198133392/3491479378'; // Android interstitial


  // -------- ⭐ NEW: NATIVE ADS (Feed Ads Every 8 Posts) --------
  static String get nativeFeed => Platform.isIOS
      ? 'ca-app-pub-5354629198133392/5085774907'  // iOS native ad
      : 'ca-app-pub-3940256099942544/2247696110'; // Android native ad
}
