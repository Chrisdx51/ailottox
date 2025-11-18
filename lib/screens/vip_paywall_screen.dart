import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../main.dart'; // for setVipStatus(), isVip

class VipPaywallScreen extends StatefulWidget {
  const VipPaywallScreen({super.key});

  @override
  State<VipPaywallScreen> createState() => _VipPaywallScreenState();
}

class _VipPaywallScreenState extends State<VipPaywallScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;

  late final Stream<List<PurchaseDetails>> _purchaseStream;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _storeAvailable = false;
  bool _loadingProducts = true;
  bool _processingPurchase = false;

  List<ProductDetails> _products = [];
  String? _errorMessage;

  // 🔑 STEP 1: SET YOUR REAL PRODUCT IDS HERE
  // ANDROID: Google Play subscription product ID
  static const String _androidVipProductId = 'ailottoxsub';


  // iOS: App Store subscription product ID
  static const String _iosVipProductId = 'ailottox_vip_monthly_ios';

  Set<String> get _kProductIds => Platform.isAndroid
      ? {_androidVipProductId}
      : {_iosVipProductId};

  @override
  void initState() {
    super.initState();

    _purchaseStream = _iap.purchaseStream;
    _subscription = _purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        setState(() {
          _processingPurchase = false;
          _errorMessage = "Purchase error. Please try again.";
        });
      },
      onDone: () {},
    );

    _initStore();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🛒 INITIALISE STORE & LOAD PRODUCTS
  // ----------------------------------------------------------
  Future<void> _initStore() async {
    setState(() {
      _loadingProducts = true;
      _errorMessage = null;
    });

    final bool available = await _iap.isAvailable();
    if (!available) {
      setState(() {
        _storeAvailable = false;
        _loadingProducts = false;
        _errorMessage = "Store not available. Check your connection or store setup.";
      });
      return;
    }

    final ProductDetailsResponse response =
    await _iap.queryProductDetails(_kProductIds);

    if (response.error != null) {
      setState(() {
        _storeAvailable = false;
        _loadingProducts = false;
        _errorMessage = "Could not load products. (${response.error!.message})";
      });
      return;
    }

    if (response.productDetails.isEmpty) {
      setState(() {
        _storeAvailable = false;
        _loadingProducts = false;
        _errorMessage =
        "No subscription products found.\nCheck your product IDs in Play Console / App Store.";
      });
      return;
    }

    setState(() {
      _storeAvailable = true;
      _loadingProducts = false;
      _products = response.productDetails;
    });
  }

  // ----------------------------------------------------------
  // 🧾 HANDLE PURCHASE UPDATES
  // ----------------------------------------------------------
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          setState(() {
            _processingPurchase = true;
          });
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchaseDetails);
          break;

        case PurchaseStatus.error:
          setState(() {
            _processingPurchase = false;
            _errorMessage = "Purchase failed. Please try again.";
          });
          break;

        case PurchaseStatus.canceled:
          setState(() {
            _processingPurchase = false;
            _errorMessage = "Purchase cancelled.";
          });
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  // ----------------------------------------------------------
  // ✅ SUCCESSFUL PURCHASE → TOGGLE VIP + CLOSE PAGE
  // ----------------------------------------------------------
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      setState(() {
        _processingPurchase = true;
      });

      final String productId = purchaseDetails.productID;

      // 🔥 VERY IMPORTANT: This is the REAL receipt
      final String purchaseToken =
          purchaseDetails.verificationData.serverVerificationData;

      // 1️⃣ SEND RECEIPT TO SUPABASE (Supabase will verify & set expiry)
      await sendVipReceiptToSupabase(
        productId: productId,
        purchaseToken: purchaseToken,
        expiresAt: DateTime.now().toUtc(), // TEMP – backend overwrites this!
      );

      // 2️⃣ Immediately set local VIP = true (so UI updates instantly)
      await setVipStatus(
        true,
        productId: productId,
        purchaseToken: purchaseToken,
      );

      // 3️⃣ Reload VIP from Supabase with the real expiry
      await loadVipStatusFromSupabase();

      if (!mounted) return;

      setState(() {
        _processingPurchase = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✨ VIP Activated")),
      );

      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processingPurchase = false;
        _errorMessage =
        "VIP activation error. If you were charged, contact support.";
      });
    }
  }



  // ----------------------------------------------------------
  // 🛒 START PURCHASE FLOW
  // ----------------------------------------------------------
  Future<void> _buy(ProductDetails product) async {
    setState(() {
      _processingPurchase = true;
      _errorMessage = null;
    });

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    // Subscriptions also use buyNonConsumable in in_app_purchase
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // ----------------------------------------------------------
  // 🔁 RESTORE (especially important on iOS)
  // ----------------------------------------------------------
  Future<void> _restorePurchases() async {
    setState(() {
      _processingPurchase = true;
      _errorMessage = null;
    });
    await _iap.restorePurchases();
  }

  // ----------------------------------------------------------
  // 🧱 UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ProductDetails? product =
    _products.isNotEmpty ? _products.first : null;

    return Scaffold(
      body: Stack(
        children: [
          // 🌌 Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF091020),
                  Color(0xFF05070D),
                  Colors.black,
                ],
              ),
            ),
          ),

          // ✨ Shimmer layer
          const Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: _GlassShimmer(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              child: Column(
                children: [
                  // ◀ Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "← Back",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 💠 Logo
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FEFC).withOpacity(0.45),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset("assets/images/logo1.png"),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🌟 Title
                  Text(
                    "Unlock AILottoX VIP",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDAF7FF),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Upgrade to VIP for deeper AI-crafted number patterns,\n"
                        "exclusive visuals and an ad-free experience.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const _VipFeatureBox(),

                  const SizedBox(height: 24),

                  if (_loadingProducts)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (!_storeAvailable || product == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _errorMessage ??
                            "Store not ready. Check your store setup and product IDs.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    )
                  else ...[
                      // 🧾 Small plan summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                            width: 1.1,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.description,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                height: 1.3,
                                color: Colors.white.withOpacity(0.80),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.price, // already includes currency symbol
                              style: GoogleFonts.orbitron(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF72FFD6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 💎 Purchase button
                      GestureDetector(
                        onTap: _processingPurchase ? null : () => _buy(product),
                        child: Opacity(
                          opacity: _processingPurchase ? 0.6 : 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                height: 60,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.22),
                                    width: 1.2,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00FEFC),
                                      Color(0xFF00B3A8),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: _processingPurchase
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                      : Text(
                                    "Continue • ${product.price}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 🔁 Restore
                      GestureDetector(
                        onTap: _processingPurchase ? null : _restorePurchases,
                        child: Text(
                          "Restore purchases",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.80),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Text(
                    "Subscriptions are billed through your ${Platform.isAndroid ? "Google Play" : "App Store"} account.\n"
                        "No predictions. Entertainment only.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// 📦 VIP Features Box
// -------------------------------------------------------
class _VipFeatureBox extends StatelessWidget {
  const _VipFeatureBox();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _VipPoint("Premium generator modes"),
              _VipPoint("Ad-free experience"),
              _VipPoint("Richer AI-guided patterns"),
              _VipPoint("VIP-only visual themes"),
              _VipPoint("Saved history & pattern recall"),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipPoint extends StatelessWidget {
  final String text;
  const _VipPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF72FFD6), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// ✨ Shimmer
// -------------------------------------------------------
class _GlassShimmer extends StatefulWidget {
  const _GlassShimmer();

  @override
  State<_GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<_GlassShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(_controller.value * 250 - 125, 0),
          child: Container(
            width: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
