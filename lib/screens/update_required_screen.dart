import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String storeUrl = Platform.isAndroid
        ? "https://play.google.com/store/apps/details?id=com.ck.ailottox"
        : "https://apps.apple.com/app/id000000000"; // update when ready

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- BACKGROUND GRADIENT --- //
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.3,
                colors: [
                  Color(0xFF241B5C),
                  Color(0xFF050814),
                  Colors.black,
                ],
              ),
            ),
          ),

          // --- ORBS --- //
          Positioned(
            top: -40,
            left: -20,
            child: _orb(220, 0.26),
          ),
          Positioned(
            bottom: -60,
            right: -10,
            child: _orb(260, 0.22),
          ),

          // --- SHIMMER --- //
          Align(
            alignment: Alignment.topRight,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 220,
                height: 500,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.04),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                      ),
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
                        Icon(Icons.upgrade,
                            size: 70,
                            color: Colors.white.withOpacity(0.92)),

                        const SizedBox(height: 20),

                        Text(
                          "A Fresh Upgrade Awaits",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.orbitron(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: const Color(0xFFDAF7FF),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "This new version of MoodLotto X includes important improvements:\n\n"
                              "• Faster AI responses\n"
                              "• Smoother MoodCast experience\n"
                              "• New visual upgrades\n"
                              "• Stability and performance fixes\n\n"
                              "Please update to continue enjoying the best experience.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),

                        const SizedBox(height: 28),

                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(storeUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 38, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withOpacity(0.12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Text(
                              "Update Now",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  // --- ORB WIDGET --- //
  Widget _orb(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF7C4DFF).withOpacity(opacity),
            const Color(0xFF00E5FF).withOpacity(opacity * 0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
