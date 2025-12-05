// lib/moodcast/moodcast_submit_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // LiquidBackground + isVip
import '../widgets/moodcast_banner.dart';
import 'moodcast_feed_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:profanity_filter/profanity_filter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';





class MoodCastSubmitScreen extends StatefulWidget {
  const MoodCastSubmitScreen({super.key});

  @override
  State<MoodCastSubmitScreen> createState() => _MoodCastSubmitScreenState();
}

class _MoodCastSubmitScreenState extends State<MoodCastSubmitScreen> {
  String _statusText = "";
  bool _showStatusBox = false;
  double _fadeIn = 0.0;

  int _postsThisHour = 0;
  int _postsLeft = 10;
  int _minutesLeft = 60;
  bool _isMember = false; // user but not VIP
  Timer? _limitTimer;

  MoodPolarity _polarity = MoodPolarity.positive;
  bool _isAnonymous = true;
  bool _isSubmitting = false;
  bool _submitLock = false;


// -------------------------------------------------------------
// MEDIA STATE (only one allowed: photo OR video)
// -------------------------------------------------------------
  String? _imagePath; // local path before upload
  String? _videoPath; // local path before upload
  String _mediaType = "none"; // "none", "image", "video"
  String? _videoThumbnail;

  final TextEditingController _textController = TextEditingController();

// -------------------------------------------------------------
// AI SUGGESTION — MoodCast ideas from FastAPI
// -------------------------------------------------------------
  String? _suggestionText;
  bool _loadingSuggestion = false;
  final filter = ProfanityFilter();

  Future<String?> uploadMediaToServer(String filePath, String type) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("UPLOAD ERROR: no user");
        return null;
      }

      // Read the local file
      final file = File(filePath);
      if (!await file.exists()) {
        print("UPLOAD ERROR: file does not exist");
        return null;
      }

      final bytes = await file.readAsBytes();

      // Extension
      final ext = filePath.split('.').last.toLowerCase();

      // BUCKET NAMES (your real ones)
      final bucketName =
      type == "image" ? "moodcast_photos" : "moodcast_videos";

      // Content type
      final contentType =
      type == "image" ? "image/$ext" : "video/mp4";

      // File path inside bucket
      final folder = type == "image" ? "photos" : "videos";
      final fileName =
          "${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext";
      final path = "$folder/$fileName";

      // Upload to Supabase Storage
      await supabase.storage.from(bucketName).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );

      // Public URL to store in database
      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print("UPLOAD ERROR (Supabase): $e");
      return null;
    }
  }






  Future<void> _fetchSuggestion() async {
    setState(() => _loadingSuggestion = true);

    try {
      final uri = Uri.parse("https://auranaguidance.co.uk/api/moodcast/suggest");

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"prompt": "Give the user a small idea"}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;
        setState(() {
          _suggestionText =
              data["suggestion"] ?? "Try sharing one honest moment.";
          _loadingSuggestion = false;
        });

      } else {
        if (!mounted) return;
        setState(() {
          _suggestionText = "Couldn't load ideas. Try again.";
          _loadingSuggestion = false;
        });

      }
    } catch (e) {
      setState(() {
        _suggestionText = "Couldn't load ideas. Try again.";
        _loadingSuggestion = false;
      });
    }
  }


  // -------------------------------------------------------------
// VIDEO TIMER
// -------------------------------------------------------------
  Timer? _videoTimer;
  int _videoSeconds = 0;

  void _startVideoTimer() {
    _videoTimer?.cancel();
    _videoSeconds = 0;

    _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_videoSeconds >= 120) {
        timer.cancel();
        return;
      }
      setState(() => _videoSeconds++);
    });
  }

  void _stopVideoTimer() {
    _videoTimer?.cancel();
    _videoSeconds = 0;
  }

  // -------------------------------------------------------------
  // TYPEWRITER STATUS BOX
  // -------------------------------------------------------------
  Future<void> _runTypewriterStatus() async {
    setState(() {
      _statusText = "";
      _showStatusBox = true;
      _fadeIn = 0.0;
    });

    const message = "✔ Checking for suitability…";
    for (int i = 0; i < message.length; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      setState(() {
        _statusText = message.substring(0, i + 1);
      });

    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _fadeIn = 1.0);

  }


  @override
  void dispose() {
    _limitTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();

    // Load initial hourly limit
    _loadHourlyLimit();

    // Auto-refresh every minute
    _limitTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => _loadHourlyLimit(),
    );
  }

  Future<void> _applyMoodToForecast(bool isPositive) async {
    final client = Supabase.instance.client;

    final today = DateTime.now();
    final todayDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day
        .toString().padLeft(2, '0')}";

    // 1. Get today's row (if missing → create)
    final rows = await client
        .from('forecast_daily')
        .select()
        .eq('day', todayDate)
        .limit(1);

    if (rows.isEmpty) {
      // Create fresh row
      final initialScore = isPositive ? 60 : 40;
      await client.from('forecast_daily').insert({
        'day': todayDate,
        'score': initialScore,
      });
      return;
    }

    // 2. Row exists → adjust score
    final int oldScore = rows.first['score'] ?? 50;

    final int newScore = (isPositive
        ? oldScore + 3 // Positive gives +3
        : oldScore - 3) // Negative gives -3
        .clamp(0, 100);

    // 3. Update Supabase
    await client
        .from('forecast_daily')
        .update({'score': newScore})
        .eq('day', todayDate);
  }

  // -------------------------------------------------------------
// GENERATE A THUMBNAIL FOR VIDEO
// -------------------------------------------------------------
  Future<void> _generateVideoThumbnail(String path) async {
    try {
      final thumb = await VideoThumbnail.thumbnailFile(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 420,
        quality: 60,
      );

      if (thumb != null) {
        if (!mounted) return;
        setState(() {
          _videoThumbnail = thumb;
        });
      }

    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _loadHourlyLimit() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Get profile info again
    final profile = await supabase
        .from('profiles')
        .select('type, vip')
        .eq('id', user.id)
        .maybeSingle();

    final String accountType = profile?['type'] ?? 'guest';
    final bool vipFlag = profile?['vip'] ?? false;

    if (vipFlag || accountType != 'user') {
      // Not a member → no pill shown
      if (!mounted) return;
      setState(() {
        _isMember = false;
      });

      return;
    }

    _isMember = true;

    // Determine top-of-the-hour (UTC)
    final nowUtc = DateTime.now().toUtc();
    final hourStartUtc = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      nowUtc.hour,
    );

    // Count posts in this hour
    final rows = await supabase
        .from('moods')
        .select('id')
        .eq('user_id', user.id)
        .gte('timestamp', hourStartUtc.toIso8601String());

    final int count = rows.length;
    const int limit = 10;

    final resetAt = hourStartUtc.add(const Duration(hours: 1));
    final minsLeft = resetAt.difference(nowUtc).inMinutes.clamp(0, 60);

    if (!mounted) return;
    setState(() {
      _postsThisHour = count;
      _postsLeft = (limit - count).clamp(0, 10);
      _minutesLeft = minsLeft;
    });

  }



  // NEW — Moderates IMAGE FILE before uploading
  Future<bool> moderateImageFile(String filePath) async {
    try {
      final uri = Uri.parse("https://auranaguidance.co.uk/api/moderate/image");

      final request = http.MultipartRequest("POST", uri);
      request.files.add(await http.MultipartFile.fromPath("file", filePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      return data["safe"] == true;
    } catch (e) {
      print("IMAGE MOD ERROR: $e");
      return true; // fail-safe
    }
  }
// NEW — Moderates VIDEO FILE before uploading
  Future<bool> moderateVideoFile(String filePath) async {
    try {
      final uri = Uri.parse("https://auranaguidance.co.uk/api/moderate/video");

      final request = http.MultipartRequest("POST", uri);
      request.files.add(await http.MultipartFile.fromPath("file", filePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      final reason = (data["reason"] ?? "").toString().toLowerCase();

      // 🔥 FORCE-UNSAFE if server mentions nudity, sexual, explicit, NSFW etc.
      if (reason.contains("nudity") ||
          reason.contains("sexual") ||
          reason.contains("explicit") ||
          reason.contains("nsfw") ||
          reason.contains("unsafe")) {
        return false;
      }

      return data["safe"] == true;
    } catch (e) {
      print("VIDEO MOD ERROR: $e");
      return true; // fail-open
    }
  }



  Future<String?> compressImage(String path) async {
    final target = path.replaceAll(".jpg", "_small.jpg").replaceAll(".jpeg", "_small.jpeg").replaceAll(".png", "_small.png");

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        path,
        target,
        quality: 75,
      );

      return compressed?.path;
    } catch (_) {
      return path; // fallback
    }
  }


  // -------------------------------------------------------------
  // SUBMIT LOGIC — NOW SUPPORTS HOURLY & DAILY LIMITS
  //  • Guests: 1 post per day
  //  • Members (type == 'user'): 10 posts per hour
  //  • VIP (vip == true): unlimited
  // -------------------------------------------------------------
  Future<void> _handleSubmit() async {
    // RESET STATUS BOX BEFORE ANYTHING
    setState(() {
      _showStatusBox = false;
      _statusText = "";
      _fadeIn = 0.0;
    });

// --- FIXED: Allow media-only posts ---
    final text = _textController.text.trim();

    final bool hasText = text.isNotEmpty;
    final bool hasImage = (_mediaType == "image" && _imagePath != null);
    final bool hasVideo = (_mediaType == "video" && _videoPath != null);

    if (!hasText && !hasImage && !hasVideo) {
      // user provided nothing at all
      _showSimpleDialog(
        title: "Add something first",
        message: "Write a mood or attach a photo/video.",
      );
      return;
    }


// Start status animation only after passing basic validation
    await _runTypewriterStatus();


    // 🚨 HARD DOUBLE-SUBMIT LOCK
    if (_submitLock) return;
    _submitLock = true;

    // UI busy lock (spinner)
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => _isSubmitting = false);
        _submitLock = false;
        throw "You must be logged in to submit a mood.";
      }

      // -----------------------------------------------------------
      // 1) LOOK UP PROFILE (type + vip)
      // -----------------------------------------------------------
      final profile = await supabase
          .from('profiles')
          .select('type, vip')
          .eq('id', user.id)
          .maybeSingle();

      final String accountType = profile?['type'] ?? 'guest';
      final bool vipFlag = profile?['vip'] ?? false;

      // Work in UTC so it lines up with Supabase timestamptz
      final nowUtc = DateTime.now().toUtc();

      // -----------------------------------------------------------
      // 2) RATE LIMITS
      //    • VIP  → unlimited (skip all checks)
      //    • Guest → 1 per calendar day
      //    • User  → 10 per hour (top-of-the-hour window)
      // -----------------------------------------------------------
      if (!vipFlag) {
        if (accountType == 'guest') {
          // ---- GUEST: DAILY LIMIT (1 per day) ----
          final dayStartUtc =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

          final postsToday = await supabase
              .from('moods')
              .select('id')
              .eq('user_id', user.id)
              .gte('timestamp', dayStartUtc.toIso8601String());

          if (postsToday.length >= 1) {
            setState(() => _isSubmitting = false);
            _submitLock = false;

            // When does the next daily slot open?
            final resetAt = dayStartUtc.add(const Duration(days: 1));
            final secondsLeft = resetAt.difference(nowUtc).inSeconds;
            final hoursLeft = (secondsLeft / 3600).floor().clamp(0, 23);
            final minsLeft =
            ((secondsLeft % 3600) / 60).round().clamp(0, 59);

            final resetText = hoursLeft <= 0
                ? "Your next daily mood slot opens within the hour."
                : "New daily slot in about ${hoursLeft}h ${minsLeft}m.";

            _showSimpleDialog(
              title: "Daily limit reached",
              message:
              "Guests can share 1 mood per day.\n\n$resetText\n\nSign in or upgrade to post more often.",
            );
            return;
          }
        } else {
          // ---- MEMBER (type == 'user'): 10 PER HOUR ----
          const int hourlyLimit = 10;

          // Top-of-the-hour UTC window
          final hourStartUtc = DateTime.utc(
            nowUtc.year,
            nowUtc.month,
            nowUtc.day,
            nowUtc.hour,
          );

          final postsThisHour = await supabase
              .from('moods')
              .select('id')
              .eq('user_id', user.id)
              .gte('timestamp', hourStartUtc.toIso8601String());

          if (postsThisHour.length >= hourlyLimit) {
            setState(() => _isSubmitting = false);
            _submitLock = false;

            final resetAt = hourStartUtc.add(const Duration(hours: 1));
            final secondsLeft = resetAt.difference(nowUtc).inSeconds;
            final minutesLeft =
            (secondsLeft / 60).ceil().clamp(0, 60);

            _showSimpleDialog(
              title: "Hourly limit reached",
              message:
              "You’ve shared $hourlyLimit moods this hour.\n\n"
                  "You can post again in about $minutesLeft minutes.\n\n"
                  "VIP members can share unlimited moods.",
            );
            return;
          }
        }
      }

      // -----------------------------------------------------------
// CLEAN MODERATION WORKFLOW (text + image + video)
// -----------------------------------------------------------

      String? imageUrl;
      String? videoUrl;

      bool imageSafe = true;
      bool videoSafe = true;
      bool textSafe = true;

// 1) TEXT SCAN (ONLY if text exists)
      if (text.isNotEmpty) {
        // Profanity filter check
        if (filter.hasProfanity(text)) {
          _showSimpleDialog(
            title: "Please adjust your wording",
            message: "Some words in your message aren’t allowed. "
                "Try saying it in a calmer or friendlier way.",
          );
          setState(() {
            _isSubmitting = false;
            _submitLock = false;
          });
          return;
        }

        textSafe = true; // text is always considered safe now
      }



      if (_mediaType == "image" && _imagePath != null) {

        // 1) compress first
        final compressedPath = await compressImage(_imagePath!);

        // 2) moderate compressed file
        imageSafe = await moderateImageFile(compressedPath!);

        // 3) upload compressed file
        imageUrl = await uploadMediaToServer(compressedPath!, "image");
      }


// 3) VIDEO SCAN + UPLOAD
      if (_mediaType == "video" && _videoPath != null) {
        videoSafe = await moderateVideoFile(_videoPath!);
        videoUrl = await uploadMediaToServer(_videoPath!, "video");
      }

// 4) DECISION BASED ON SAFETY
      final bool allSafe = textSafe && imageSafe && videoSafe;

// 5) INSERT INTO THE CORRECT TABLE
      if (allSafe) {
        await supabase.from("moods").insert({
          "user_id": user.id,
          "mood": hasText ? text : null,
          "reflection": null,
          "is_positive": _polarity == MoodPolarity.positive,
          "anonymous": _isAnonymous,
          "image_url": imageUrl,
          "video_url": videoUrl,
          "is_hidden": false,
        });
      } else {
        await supabase.from("mood_rejections").insert({
          "user_id": user.id,
          "mood": hasText ? text : null,
          "image_url": imageUrl,
          "video_url": videoUrl,
          "reason_text": textSafe ? null : "text_unsafe",
          "reason_image": imageSafe ? null : "image_unsafe",
          "reason_video": videoSafe ? null : "video_unsafe",
        });
      }



// -----------------------------------------------------------
// FINAL UI HANDLING (works for SAFE & UNSAFE posts)
// -----------------------------------------------------------

// 1) Update forecast for SAFE posts only
      if (allSafe) {
        await _applyMoodToForecast(_polarity == MoodPolarity.positive);
      }

// 2) Refresh limit pill
      await _loadHourlyLimit();

// 3) FULL UI RESET (important!)
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitLock = false;
        _showStatusBox = false;
        _statusText = "";
        _fadeIn = 0.0;
        _textController.clear();
        _imagePath = null;
        _videoPath = null;
        _mediaType = "none";
      });


// 4) Show popup — DIFFERENT messages
      if (allSafe) {
        _showSimpleDialog(
          title: "Submitted",
          message: "Your mood has been added into today’s national MoodCast flow.",
          goToFeed: true,
        );
      } else {
        _showSimpleDialog(
          title: "Received",
          message:
          "Your post has been reviewed.\nSome parts were held back for safety, but your message was still received.",
          goToFeed: false,
        );
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitLock = false;
        _showStatusBox = false;
      });


      _showSimpleDialog(
        title: "Error",
        message: "Something went wrong. Please try again.\n\n$e",
      );
    } // <-- END of try/catch

  } // <-- END of _handleSubmit()



  void _showUnsafeDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF050815).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 360, // prevents overflow on small screens
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text(
                    "Post Not Accepted",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Your post wasn’t accepted.\n"
                        "It contained content that isn’t suitable for MoodCast and was blocked to keep the community safe.\n\n"
                        "Please share something appropriate for everyone to see.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "OK",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF72FFD6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // -------------------------------------------------------------
  // SIMPLE DIALOG
  // -------------------------------------------------------------
  void _showSimpleDialog({
    required String title,
    required String message,
    bool goToFeed = false,
  }) {
    showDialog(
      context: context,
      builder: (_) =>
          Dialog(
            backgroundColor: const Color(0xFF050815).withOpacity(0.95),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog

                      if (goToFeed) {
                        Navigator.pop(context); // close submit screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MoodCastFeedScreen(),
                          ),
                        );
                      }
                    },
                    child: Text(
                      "OK",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF72FFD6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

// -------------------------------------------------------------
// AI SUGGESTION POPUP
// -------------------------------------------------------------
  void _showSuggestionPopup() {
    if (_suggestionText == null) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF050815).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Idea for Today",
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                constraints: const BoxConstraints(
                  maxHeight: 200,  // limit popup height
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _suggestionText!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 18),

              // Paste into textbox
              TextButton(
                onPressed: () {
                  _textController.text = _suggestionText!;
                  Navigator.pop(context);
                },
                child: Text(
                  "Paste this idea",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF72FFD6),
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // "WHY IT MATTERS" SHEET
  // -------------------------------------------------------------
  void _showWhyMattersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.80),
                        Colors.black.withOpacity(0.92),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 20),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Why the Mood of the Nation Matters",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDAF7FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "When thousands of people share honestly how they feel, "
                            "we get a living emotional weather map for the country.",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.white.withOpacity(0.90),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _whyPoint(
                        "Emotion spreads like weather.",
                        "Psychologists have found that moods can ripple "
                            "through social networks. Seeing the wider climate "
                            "helps people realise they’re not alone.",
                      ),
                      const SizedBox(height: 10),
                      _whyPoint(
                        "Naming feelings reduces pressure.",
                        "Simply putting words to how you feel can reduce "
                            "stress in the brain. Sharing a mood here is a small, "
                            "practical act of emotional hygiene.",
                      ),
                      const SizedBox(height: 10),
                      _whyPoint(
                        "Patterns reveal turning points.",
                        "Tracking the national mood over days and weeks can "
                            "show when things are lifting or getting heavier. "
                            "Those trends help people decide when to rest, connect "
                            "or reset.",
                      ),
                      const SizedBox(height: 10),
                      _whyPoint(
                        "Honesty creates healthier conversations.",
                        "When people admit both good and bad days, it becomes "
                            "easier for others to talk openly instead of "
                            "pretending everything is fine.",
                      ),
                      const SizedBox(height: 22),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Close",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _whyPoint(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF00FEFC), Color(0xFF72FFD6)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.96),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  // -------------------------------------------------------------
  // POSTING RULES SHEET
  // -------------------------------------------------------------
  void _showRulesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Posting Rules",
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDAF7FF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ruleLine(
                      "No violent, graphic or self-harm content.",
                    ),
                    _ruleLine(
                      "No pornographic, sexual or nude material.",
                    ),
                    _ruleLine(
                      "No hate, slurs or targeting any group or person.",
                    ),
                    _ruleLine(
                      "No harassment, bullying or threats.",
                    ),
                    _ruleLine(
                      "No criminal, extremist or shock content.",
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "MoodCast is a calm space for real feelings, "
                          "not shock or harm.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.80),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Got it",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF72FFD6),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ruleLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              size: 14, color: Color(0xFFDAF7FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withOpacity(0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LiquidBackground(
          child: Column(
            children: [
              const SizedBox(height: 6),
              _buildBackBar(context),
              const SizedBox(height: 6),

              // ⭐ Banner (auto-hides for VIP)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: MoodCastBanner(),
              ),
              const SizedBox(height: 8),

              // Content scrolls
              Expanded(
                child: SingleChildScrollView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleBlock(context),
                      const SizedBox(height: 18),
                      _buildHourlyLimitPill(),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          "Choose whether your mood is positive or negative",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      _buildMoodToggle(),
                      const SizedBox(height: 18),
                      _buildTextField(),
                      // -------------------------------------------------------------
// AI Suggestion Button
// -------------------------------------------------------------
                      GestureDetector(
                        onTap: _loadingSuggestion ? null : () async {
                          await _fetchSuggestion();
                          _showSuggestionPopup();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.10),
                                Colors.white.withOpacity(0.03),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 16,
                                  color: _loadingSuggestion
                                      ? Colors.white30
                                      : const Color(0xFF72FFD6)),
                              const SizedBox(width: 8),
                              Text(
                                _loadingSuggestion ? "Thinking…" : "Need ideas?",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      _buildMediaRow(),
                      const SizedBox(height: 14),
                      _buildAnonymousToggle(),
                      const SizedBox(height: 12),
                      _buildRulesButton(),
                      const SizedBox(height: 22),
                      // -------------------------------------------------------------
// STATUS BOX (typewriter + fade)
// -------------------------------------------------------------
                      if (_showStatusBox)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.10),
                                Colors.white.withOpacity(0.03),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusText,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedOpacity(
                                opacity: _fadeIn,
                                duration: const Duration(milliseconds: 700),
                                child: Text(
                                  "Image checks may take up to 90 seconds.\nVideo checks may take up to 3 minutes.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          "This isn’t just a feed — it’s a collective Mood.\n"
                              "When you post, you contribute to the nation’s emotional landscape.\n"
                              "All content is lightly moderated for safety, and you can help guide the Mood by swiping through others’ posts and choosing what resonates as positive or negative.",
                          textAlign: TextAlign.left,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            height: 1.4,
                            color: Colors.white70,
                          ),
                        ),
                      ),



                      _buildSubmitButton(),
                      const SizedBox(height: 18),
                      _buildFinePrint(),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyLimitPill() {
    if (!_isMember) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.03),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined,
              size: 16, color: Color(0xFF72FFD6)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "${_postsLeft} / 10 left • ${_minutesLeft == 0 ? 'resets soon' : 'resets in $_minutesLeft min'} • Upgrade for unlimited",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }


// -------------------------------------------------------------
// TOP BACK BAR (works with bottom nav + tabs)
// -------------------------------------------------------------
  Widget _buildBackBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // 1️⃣ If this screen was opened via push() (tabs / buttons) → normal back
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }

            // 2️⃣ If it's showing as a bottom-nav page → switch tab back to Vibes
            final navState =
            context.findAncestorStateOfType<State<NavigationWrapper>>();

            if (navState != null) {
              (navState as dynamic).goToTab(1); // 1 = Vibes / MoodCast feed tab
            }
          },
        ),
      ),
    );
  }



  // -------------------------------------------------------------
  // TITLE + SUBTITLE + "WHY THIS MATTERS" TAB
  // -------------------------------------------------------------
  Widget _buildTitleBlock(BuildContext context) {
    final width = MediaQuery
        .of(context)
        .size
        .width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Submit Your Mood",
          style: GoogleFonts.orbitron(
            fontSize: 18, // small enough to sit on one line
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "How are you really feeling today?\n"
              "Each mood you share gently shifts today’s national MoodCast.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),

        // full-width pill so it never overflows
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width - 20),
          child: GestureDetector(
            onTap: _showWhyMattersSheet,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.09),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "Why the national mood matters",
                      softWrap: true,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
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


// -------------------------------------------------------------
// OPTION C — FUTURISTIC LIQUID WAVE TOGGLE (FINAL VERSION)
// -------------------------------------------------------------
  Widget _buildMoodToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24, width: 1.1),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.03),
          ],
        ),
      ),
      child: Stack(
        children: [

          // Sliding indicator background
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: _polarity == MoodPolarity.positive
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: double.infinity * 0.45,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: _polarity == MoodPolarity.positive
                      ? const [Color(0xFF00FEFC), Color(0xFF72FFD6)]
                      : const [Color(0xFFFF4B7D), Color(0xFFFF9A8B)],
                ),
              ),
            ),
          ),

          // Foreground options
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _polarity = MoodPolarity.positive),
                  child: _ToggleItem(
                    label: "Positive",
                    waveType: WaveType.rising,
                    active: _polarity == MoodPolarity.positive,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _polarity = MoodPolarity.negative),
                  child: _ToggleItem(
                    label: "Negative",
                    waveType: WaveType.sinking,
                    active: _polarity == MoodPolarity.negative,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // -------------------------------------------------------------
  // TEXT FIELD (VisionGlass)
  // -------------------------------------------------------------
  Widget _buildTextField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            maxLength: 280,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Share today’s real moment — good or bad.\nExample: I lost my job, I saw a bad accident, I got a new job, or my Lotto X numbers matched!",
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white54,
              ),
              counterStyle: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
// MEDIA ROW (Preview + Add Photo + Record Video)
// -------------------------------------------------------------
  Widget _buildMediaRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------
        // PHOTO PREVIEW + REMOVE BUTTON
        // ---------------------------------------------------------
        if (_mediaType == "image" && _imagePath != null)
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: FileImage(File(_imagePath!)),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _imagePath = null;
                      _mediaType = "none";
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

        // ---------------------------------------------------------
// VIDEO PREVIEW WITH THUMBNAIL + REMOVE BUTTON
// ---------------------------------------------------------
        if (_mediaType == "video" && _videoPath != null)
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: _videoThumbnail != null
                      ? DecorationImage(
                    image: FileImage(File(_videoThumbnail!)),
                    fit: BoxFit.cover,
                  )
                      : null,
                  color: Colors.black26,
                ),
                child: _videoThumbnail == null
                    ? const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Colors.white70,
                  ),
                )
                    : null,
              ),

              // Remove button
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _videoPath = null;
                      _videoThumbnail = null;
                      _mediaType = "none";
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),


        // ---------------------------------------------------------
// ACTION BUTTONS (FIXED)
// ---------------------------------------------------------
        Row(
          children: [
            // ADD PHOTO
            Expanded(
              child: _GlassChip(
                icon: Icons.photo_outlined,
                label: "Add Photo",
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1600,
                  );

                  if (picked != null) {
                    setState(() {
                      _mediaType = "image";
                      _imagePath = picked.path;
                      _videoPath = null;
                    });
                  }
                },
              ),
            ),

            const SizedBox(width: 10),

            // UPLOAD VIDEO
            Expanded(
              child: _GlassChip(
                icon: Icons.video_library_outlined,
                label: "Upload Video",
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickVideo(
                    source: ImageSource.gallery,
                  );

                  if (picked != null) {
                    final file = File(picked.path);
                    final int fileBytes = await file.length();
                    final double fileMb = fileBytes / (1024 * 1024);

                    if (fileMb > 50) {
                      _showSimpleDialog(
                        title: "Video too large",
                        message:
                        "This video is ${fileMb.toStringAsFixed(1)} MB.\nPlease keep videos under 50 MB.",
                      );
                      return;
                    }

                    setState(() {
                      _mediaType = "video";
                      _videoPath = picked.path;
                      _imagePath = null;
                      _videoThumbnail = null;
                    });

                    await _generateVideoThumbnail(picked.path);
                  }
                },
              ),
            ),

            const SizedBox(width: 10),

            // RECORD VIDEO
            Expanded(
              child: _GlassChip(
                icon: Icons.videocam_outlined,
                label: "Record",
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickVideo(
                    source: ImageSource.camera,
                    maxDuration: const Duration(minutes: 2),
                  );

                  if (picked != null) {
                    final file = File(picked.path);

                    final int fileBytes = await file.length();
                    final double fileMb = fileBytes / (1024 * 1024);

                    if (fileMb > 50) {
                      _showSimpleDialog(
                        title: "Video too large",
                        message:
                        "This video is ${fileMb.toStringAsFixed(1)} MB.\nPlease keep videos under 50 MB.",
                      );
                      return;
                    }

                    final controller = VideoPlayerController.file(file);
                    try {
                      await controller.initialize();
                      final duration = controller.value.duration;
                      await controller.dispose();

                      if (duration.inSeconds > 120) {
                        _showSimpleDialog(
                          title: "Video too long",
                          message: "MoodCast videos must be under 2 minutes.",
                        );
                        return;
                      }
                    } catch (_) {}

                    setState(() {
                      _mediaType = "video";
                      _videoPath = picked.path;
                      _imagePath = null;
                      _videoThumbnail = null;
                    });

                    await _generateVideoThumbnail(picked.path);
                  }
                },
              ),
            ),
          ],
        )

      ],
    );
  }


  // -------------------------------------------------------------
  // ANONYMOUS TOGGLE
  // -------------------------------------------------------------
  Widget _buildAnonymousToggle() {
    return Row(
      children: [
        Switch(
          value: _isAnonymous,
          activeColor: const Color(0xFF00FEFC),
          onChanged: (val) => setState(() => _isAnonymous = val),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            "Post this mood anonymously.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SMALL "POSTING RULES" BUTTON
  // -------------------------------------------------------------
  Widget _buildRulesButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _showRulesSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: Color(0xFFDAF7FF)),
              const SizedBox(width: 6),
              Text(
                "Posting rules",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SUBMIT BUTTON
  // -------------------------------------------------------------
  Widget _buildSubmitButton() {
    // HIDE BUTTON while status box is active
    if (_showStatusBox) {
      return const SizedBox.shrink();
    }

    final String label = _polarity == MoodPolarity.positive
        ? "Submit positive mood"
        : "Submit negative mood";

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _isSubmitting ? null : _handleSubmit,
        child: Stack(
          children: [
            // Outer glow
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00FEFC).withOpacity(0.55),
                    const Color(0xFF72FFD6).withOpacity(0.45),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FEFC).withOpacity(0.45),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),

            // Inner glass
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1.1,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.20),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                        : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // -------------------------------------------------------------
  // FINE PRINT — MATCHES NEW LIMITS
  // -------------------------------------------------------------
  Widget _buildFinePrint() {
    return Text(
      "Guests can share one mood each day.\n"
          "Members can share up to 10 moods per hour.\n"
          "VIP members can share unlimited moods and help shape the live MoodCast.",
      textAlign: TextAlign.left,
      style: GoogleFonts.poppins(
        fontSize: 11,
        height: 1.4,
        color: Colors.white60,
      ),
    );
  }
}

// -------------------------------------------------------------
// ENUMS
// -------------------------------------------------------------
enum MoodPolarity { positive, negative }

enum WaveType { rising, sinking }

class _ToggleItem extends StatelessWidget {
  final String label;
  final WaveType waveType;
  final bool active;

  const _ToggleItem({
    required this.label,
    required this.waveType,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MoodWaveIcon(
            waveType: waveType,
            isActive: active,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.black87 : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodWaveIcon extends StatelessWidget {
  final WaveType waveType;
  final bool isActive;

  const _MoodWaveIcon({
    required this.waveType,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bool rising = waveType == WaveType.rising;

    return CustomPaint(
      size: const Size(22, 18),
      painter: _WavePainter(
        rising: rising,
        glow: isActive,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool rising;
  final bool glow;

  _WavePainter({required this.rising, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: rising
            ? const [Color(0xFF00FEFC), Color(0xFF72FFD6)]
            : const [Color(0xFFFF4B7D), Color(0xFFFF9A8B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..colorFilter = glow
          ? const ColorFilter.mode(Colors.white24, BlendMode.srcATop)
          : null;

    final Paint mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: rising
            ? const [Color(0xFF00FEFC), Color(0xFFDAF7FF)]
            : const [Color(0xFFFF4B7D), Color(0xFFFFC1D0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();
    final double h = size.height;
    final double w = size.width;

    if (rising) {
      // Rising multi-peak wave
      path.moveTo(0, h * 0.75);
      path.quadraticBezierTo(w * 0.2, h * 0.40, w * 0.4, h * 0.55);
      path.quadraticBezierTo(w * 0.6, h * 0.80, w * 0.8, h * 0.30);
      path.quadraticBezierTo(w * 0.9, h * 0.10, w, h * 0.20);
    } else {
      // Sinking multi-peak wave
      path.moveTo(0, h * 0.25);
      path.quadraticBezierTo(w * 0.2, h * 0.60, w * 0.4, h * 0.45);
      path.quadraticBezierTo(w * 0.6, h * 0.20, w * 0.8, h * 0.70);
      path.quadraticBezierTo(w * 0.9, h * 0.90, w, h * 0.80);
    }

    if (glow) {
      canvas.drawPath(path, glowPaint);
    }
    canvas.drawPath(path, mainPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.rising != rising || oldDelegate.glow != glow;
  }
}

// -------------------------------------------------------------
// SMALL GLASS CHIP
// -------------------------------------------------------------
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 30,
            color: Colors.white70,
          ),
        ),

      ),
    );
  }

}
