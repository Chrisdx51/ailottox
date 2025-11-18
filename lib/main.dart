// ⚡ AI Lotto Generator — Main Navigation + Liquid Glass UI
// Production-ready with Supabase VIP subscriptions (Android + iOS)

import 'dart:io'; // ⭐ Needed for Platform checks
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import screens
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

// -----------------------------------------------------------
// ⭐ GLOBAL VIP FLAG
// -----------------------------------------------------------
bool isVip = false;
// -----------------------------------------------------------
// ⭐ Local Notifications (Android + iOS)
// -----------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised in background isolate
  await Firebase.initializeApp();
  // You can log or handle background data here later if you want
}


// -----------------------------------------------------------
// 🔐 1) SILENT LOGIN — one hidden user per device
// -----------------------------------------------------------
Future<void> _silentLogin() async {
  final prefs = await SharedPreferences.getInstance();

  final savedEmail = prefs.getString("anon_email");
  final savedPass = prefs.getString("anon_pass");

  final client = Supabase.instance.client;

  // Use existing hidden login
  if (savedEmail != null && savedPass != null) {
    try {
      await client.auth.signInWithPassword(
        email: savedEmail,
        password: savedPass,
      );
      return;
    } catch (_) {}
  }

  // Create new hidden user
  final now = DateTime.now().millisecondsSinceEpoch;
  final email = "user_$now@hidden.ailottox";
  final pass = "pw_$now-AILottoX";

  await client.auth.signUp(email: email, password: pass);

  await prefs.setString("anon_email", email);
  await prefs.setString("anon_pass", pass);
}

// -----------------------------------------------------------
// 🌟 2) LOAD VIP STATUS FROM SUPABASE
// -----------------------------------------------------------
Future<void> loadVipStatusFromSupabase() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    isVip = false;
    return;
  }

  final row = await client
      .from("vip_status")
      .select()
      .eq("user_id", user.id)
      .eq("app", "ai_lotto")
      .maybeSingle();

  if (row == null) {
    isVip = false;
    return;
  }

  final active = row["vip_active"] == true;
  final expiresRaw = row["expires_at"] as String?;
  final DateTime? expiresAt =
  expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;

  if (active && expiresAt != null && expiresAt.isAfter(DateTime.now().toUtc())) {
    isVip = true;
  } else {
    isVip = false;
  }
}

// -----------------------------------------------------------
// ✨ 3) UPDATE SUPABASE VIP STATUS
// -----------------------------------------------------------
Future<void> setVipStatus(
    bool value, {
      DateTime? expiresAt,
      String? productId,
      String? purchaseToken,
      String? platform,
    }) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    isVip = false;
    return;
  }

  final now = DateTime.now().toUtc();
  final expiry = (expiresAt ?? now.add(const Duration(days: 30))).toUtc();

  final existing = await client
      .from("vip_status")
      .select()
      .eq("user_id", user.id)
      .eq("app", "ai_lotto")
      .maybeSingle();

  final data = {
    "user_id": user.id,
    "app": "ai_lotto",
    "vip_active": value,
    "expires_at": expiry.toIso8601String(),
    "platform": platform ?? (Platform.isAndroid ? "android" : "ios"),
    "product_id": productId,
    "purchase_token": purchaseToken,
  };

  if (existing == null) {
    await client.from("vip_status").insert(data);
  } else {
    await client
        .from("vip_status")
        .update(data)
        .eq("id", existing["id"]);
  }

  isVip = value;
}

// -----------------------------------------------------------
// 🔥 4) SEND RECEIPT TO SUPABASE (RPC)
// -----------------------------------------------------------
Future<void> sendVipReceiptToSupabase({
  required String productId,
  required String purchaseToken,
  required DateTime expiresAt,
  String appName = "ai_lotto",
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) return;

  try {
    await client.rpc(
      'set_vip_receipt',
      params: {
        'p_user_id': user.id,
        'p_app': appName,
        'p_product_id': productId,
        'p_purchase_token': purchaseToken,
        'p_platform': Platform.isAndroid ? 'android' : 'ios',
        'p_expires_at': expiresAt.toUtc().toIso8601String(),
      },
    );
  } catch (e) {
    debugPrint("🔥 VIP RPC failed: $e");
  }
}

// -----------------------------------------------------------
// ⭐ MAIN
// -----------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Load environment
  await dotenv.load(fileName: ".env");

  // 2) Init Firebase (for notifications)
  await Firebase.initializeApp();

  // 3) Register background handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ⭐ Request notification permissions (Android 13+ needs this)
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

// ⭐ Must be enabled BEFORE token can be printed
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  final token = await FirebaseMessaging.instance.getToken();
  print("🔥 YOUR FCM TOKEN: $token");

  // 4) Init Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 5) Init Ads (AdMob)
  await MobileAds.instance.initialize();

  // 6) Hidden login
  await _silentLogin();

  // 7) Load VIP
  await loadVipStatusFromSupabase();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> _initLocalNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ailotto_channel', // id
      'AI Lotto Alerts', // title
      description: 'Shows notifications for AI Lotto Generator',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }


  // 8) Start app
  runApp(const AILottoApp());
}


// -----------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------
class AILottoApp extends StatelessWidget {
  const AILottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Lotto Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: const NavigationWrapper(),
    );
  }
}

// -----------------------------------------------------------
// ⭐ Bottom Navigation (Home + History Only)
// -----------------------------------------------------------
class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}


class _NavigationWrapperState extends State<NavigationWrapper> {
  int _index = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Listen for notifications while the app is open
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'ailotto_channel',
              'AI Lotto Alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }

      print("🔥 FCM in foreground: ${notification?.title}");
      print("📩 Message data: ${message.data}");
    });
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        indicatorColor: Colors.white.withOpacity(0.1),
        height: 65,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// ⭐ Background
// -----------------------------------------------------------
class LiquidBackground extends StatefulWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    bool useVideoBackground = false;

    if (useVideoBackground) {
      _controller = VideoPlayerController.asset('assets/videos/background.mp4')
        ..initialize().then((_) {
          _controller!.setLooping(true);
          _controller!.setVolume(0);
          _controller!.play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_controller != null && _controller!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else
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

        // Glow orbs
        const Positioned(
          top: -40,
          left: -20,
          child: GlowOrb(size: 220, opacity: 0.32),
        ),
        const Positioned(
          bottom: -60,
          right: -10,
          child: GlowOrb(size: 260, opacity: 0.26),
        ),

        // Streak
        Align(
          alignment: Alignment.topRight,
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 220,
              height: 500,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        SafeArea(child: widget.child),
      ],
    );
  }
}

class GlowOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const GlowOrb({
    super.key,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
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
