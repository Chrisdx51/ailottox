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
import 'package:package_info_plus/package_info_plus.dart'; // ⭐ NEW
// Import screens
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'moodcast/mood_lotto_lab_screen.dart';
import 'moodcast/moodcast_feed_screen.dart';
import 'screens/input_screen.dart';
import 'moodcast/moodcast_submit_screen.dart';
import 'screens/update_required_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
// ⭐ AUTO-SUBSCRIBE TO MOOD POSTS TOPIC
// -----------------------------------------------------------
Future<void> subscribeToMoodNotifications() async {
  try {
    await FirebaseMessaging.instance.subscribeToTopic('mood_posts');
    print("🔥 Subscribed to mood_posts topic");
  } catch (e) {
    print("❌ Failed to subscribe to mood_posts: $e");
  }
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
    await client.from("vip_status").update(data).eq("id", existing["id"]);
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
// AUTH GATE — Shows LoginScreen or Home depending on session
// -----------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = client.auth.currentSession;

        // User logged in → Go to app
        if (session != null && session.user != null) {
          return const NavigationWrapper();
        }

        // Not logged in → Show Login Page
        return const LoginScreen();
      },
    );
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
  NotificationSettings settings =
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ⭐ Must be enabled BEFORE token can be printed
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  final token = await FirebaseMessaging.instance.getToken();
  print("🔥 YOUR FCM TOKEN: $token");

  // ⭐ Auto-subscribe to mood_posts
  await subscribeToMoodNotifications();


  // 4) Init Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 5) Init Ads (AdMob)
  await MobileAds.instance.initialize();

  // 7) Load VIP
  await loadVipStatusFromSupabase();

  // Local notifications setup (defined but not strictly required to call here)
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
// ⭐ VERSION CHECK — blocks the app if update is required
// -----------------------------------------------------------
Future<bool> checkAppVersion() async {
  final client = Supabase.instance.client;

  try {
    final row = await client
        .from('app_versions')
        .select()
        .eq('app_name', 'mood_lotto_x')
        .maybeSingle();

    if (row == null) return true;

    final String minAndroid = row['min_version_android'];
    final String minIos = row['min_version_ios'];

    // Read local version from the device
    final packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;

    // Compare based on platform
    if (Platform.isAndroid) {
      return _isVersionAllowed(currentVersion, minAndroid);
    } else {
      return _isVersionAllowed(currentVersion, minIos);
    }
  } catch (e) {
    // If anything goes wrong, DO NOT block the user
    return true;
  }
}

bool _isVersionAllowed(String current, String minimum) {
  final List<int> c = current.split('.').map(int.parse).toList();
  final List<int> m = minimum.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    if (c[i] > m[i]) return true;  // your app is newer → allowed
    if (c[i] < m[i]) return false; // your app is older → block
  }
  return true; // equal = allowed
}

// -----------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------
class AILottoApp extends StatefulWidget {
  const AILottoApp({super.key});




  @override
  State<AILottoApp> createState() => _AILottoAppState();
}

class _AILottoAppState extends State<AILottoApp> {
  // ⭐ Global tracking for MoodCast realtime
  RealtimeChannel? _moodChannel;
  int _newMoodCount = 0;
  bool _showNewMoodPopup = false;

  @override
  void initState() {
    super.initState();

    // ⭐ SUBSCRIBE to realtime inserts in moods table
    _moodChannel = Supabase.instance.client
        .channel('public:moods')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'moods',
      callback: (payload) {
        // New mood post inserted → increase global count
        setState(() {
          _newMoodCount++;

          if (_newMoodCount >= 5) {
            _showNewMoodPopup = true;

            // ⭐ Auto-hide after 4 seconds
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted && _showNewMoodPopup) {
                setState(() {
                  _showNewMoodPopup = false;
                  _newMoodCount = 0;
                });
              }
            });
          }
        });


        print("🔥 Realtime new mood detected: $_newMoodCount");
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _moodChannel?.unsubscribe();
    super.dispose();
  }

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

      // ⭐ GLOBAL WRAPPER FOR ALL SCREENS
      builder: (context, child) {
        return Stack(
          children: [
            child!,

            // ⭐ GLOBAL NEW POST POPUP — Smooth Fade + Slide
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                );

                final slide = Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ));

                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: _showNewMoodPopup
                  ? Padding(
                key: const ValueKey("popup"),
                padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showNewMoodPopup = false;
                      _newMoodCount = 0;
                    });

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MoodCastFeedScreen(),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.18),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "$_newMoodCount new posts — tap to dismiss",
                                  maxLines: 1,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
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
              )
                  : const SizedBox.shrink(),
            )

          ],
        );
      },

      home: FutureBuilder<bool>(
        future: checkAppVersion(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (snapshot.data == false) {
            return const UpdateRequiredScreen();
          }

          return const AuthGate();
        },
      ),

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

  // ⭐ Public helper so other screens can switch tab safely
  void goToTab(int index) {
    setState(() => _index = index);
  }

  // ⭐ MUST match bottom nav order:
  // 0 = Home
  // 1 = Vibes (Feed)
  // 2 = Submit
  // 3 = Lotto
  // 4 = Lab
  // 5 = History
  final List<Widget> _screens = const [
    HomeScreen(),             // 0 → Home
    MoodCastFeedScreen(),     // 1 → Vibes
    MoodCastSubmitScreen(),   // 2 → Submit
    AILottoXInputScreen(),    // 3 → Lotto
    MoodLottoLabScreen(),     // 4 → Lab
    HistoryScreen(),          // 5 → History
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
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Vibes',
          ),

          // ⭐ NEW — SUBMIT MOOD BUTTON
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Submit',
          ),

          NavigationDestination(
            icon: Icon(Icons.numbers_outlined),
            selectedIcon: Icon(Icons.numbers),
            label: 'Lotto',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Lab',
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
// ⭐ FIXED Liquid Background (no crashes / no black screen)
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

    // If you ever want video background, just set this to true
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
    return SizedBox.expand(
      child: Stack(
        children: [
          // --- BACKGROUND LAYER --- //
          if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
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

          // --- ORBS --- //
          Positioned(
            top: -40,
            left: -20,
            child: GlowOrb(size: 220, opacity: 0.32),
          ),
          Positioned(
            bottom: -60,
            right: -10,
            child: GlowOrb(size: 260, opacity: 0.26),
          ),

          // --- LIGHT STREAK --- //
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

          // --- CHILD CONTENT (SafeArea usually inside each screen) --- //
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// ⭐ Glow Orb
// -----------------------------------------------------------
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
