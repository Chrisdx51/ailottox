// lib/moodcast/moodcast_feed_screen.dart
// X-STYLE MOOD FEED — IMAGE + VIDEO SUPPORT + REACTIONS + COMMENTS

import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';  // ⭐ Required for YouTube/TikTok
import 'package:share_plus/share_plus.dart';            // ⭐ Required for the Share button
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:profanity_filter/profanity_filter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../screens/input_screen.dart'; // AILottoXInputScreen
import '../main.dart'; // LiquidBackground + isVip
import '../widgets/moodcast_banner.dart';
import '../ad_ids.dart';

// -------------------------------------------------------------
// MODELS + ENUMS
// -------------------------------------------------------------

enum MoodFilter { all, positive, negative }

class MoodPost {
  final String id;
  final String userId; // author id
  bool isPositive;
  final String author;
  final bool isAnonymous;
  final DateTime time;
  final String text;

  // NEW: simple positive / negative reaction counts
  int positive; // ❤️
  int negative; // 💔

  // MEDIA
  final String? imageUrl;
  final String? videoUrl;

  MoodPost({
    required this.id,
    required this.userId,
    required this.isPositive,
    required this.author,
    required this.isAnonymous,
    required this.time,
    required this.text,
    required this.positive,
    required this.negative,
    this.imageUrl,
    this.videoUrl,
  });
}


class MoodComment {
  final String id;
  final String userId;
  final String text;
  final bool isAnonymous;
  final DateTime time;
  String author;

  MoodComment({
    required this.id,
    required this.userId,
    required this.text,
    required this.isAnonymous,
    required this.time,
    required this.author,
  });
}

// -------------------------------------------------------------
// LINK PREVIEW MODEL + FETCH
// -------------------------------------------------------------

class LinkPreviewData {
  final String url;
  final String title;
  final String description;
  final String image;

  LinkPreviewData({
    required this.url,
    required this.title,
    required this.description,
    required this.image,
  });
}

Future<LinkPreviewData?> fetchLinkPreview(String url) async {
  try {
    final api = Uri.parse(
      "https://auranaguidance.co.uk/api/moodcast/link_preview",
    );

    final response = await http.post(
      api,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"url": url}),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);

    return LinkPreviewData(
      url: data["url"] ?? "",
      title: data["title"] ?? "",
      description: data["description"] ?? "",
      image: data["image"] ?? "",
    );
  } catch (e) {
    debugPrint("❌ Link preview error: $e");
    return null;
  }
}

// -------------------------------------------------------------
// MAIN SCREEN — X STYLE FEED
// -------------------------------------------------------------

class MoodCastFeedScreen extends StatefulWidget {
  const MoodCastFeedScreen({super.key});

  @override
  State<MoodCastFeedScreen> createState() => _MoodCastFeedScreenState();
}

class _MoodCastFeedScreenState extends State<MoodCastFeedScreen> {
  MoodFilter _filter = MoodFilter.all;
  List<MoodPost> _posts = [];
  final Map<String, String> _usernameCache = {};
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // TOP BANNER AD (used inside list)
  BannerAd? _topBanner;
  bool _topBannerReady = false;

  @override
  void initState() {
    super.initState();

    // ⭐ REQUIRED or ads never load
    MobileAds.instance.initialize();


    _loadPosts();

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });


    if (!isVip) {
      _topBanner = BannerAd(
        adUnitId: AdIds.bannerTop,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            setState(() {
              _topBannerReady = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _topBannerReady = false;
          },
        ),
      )..load();
    }

  }

  @override
  void dispose() {
    _topBanner?.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    // 1) Recent 24 hours — random window
    final recent = await supabase
        .from('moods')
        .select()
        .eq('is_hidden', false)
        .gte(
        'timestamp',
        DateTime.now()
            .subtract(const Duration(hours: 24))
            .toIso8601String())
        .order('timestamp', ascending: false)
        .limit(40);

    // 2) Last 48 hours — strong posts, still random
    final twoDays = await supabase
        .from('moods')
        .select()
        .eq('is_hidden', false)
        .gte(
        'timestamp',
        DateTime.now()
            .subtract(const Duration(hours: 48))
            .toIso8601String())
        .order('positive_count', ascending: false)
        .limit(20);

    // 3) Last 7 days — also ordered by positive_count
    final week = await supabase
        .from('moods')
        .select()
        .eq('is_hidden', false)
        .gte(
        'timestamp',
        DateTime.now()
            .subtract(const Duration(days: 7))
            .toIso8601String())
        .order('positive_count', ascending: false)
        .limit(20);

    // 4) Older posts — just some samples
    final older = await supabase
        .from('moods')
        .select()
        .eq('is_hidden', false)
        .lte(
        'timestamp',
        DateTime.now()
            .subtract(const Duration(days: 7))
            .toIso8601String())
        .order('timestamp', ascending: false)
        .limit(10);

    // Merge all sets
    final Map<String, dynamic> rawMap = {};
    for (final row in [...recent, ...twoDays, ...week, ...older]) {
      rawMap[row['id'].toString()] = row;
    }

    final mixed = rawMap.values.toList();

    // Strong randomisation
    mixed.shuffle();
    mixed.shuffle();
    mixed.shuffle();

    // Cap list
    const int maxPosts = 60;
    if (mixed.length > maxPosts) {
      mixed.shuffle();
      mixed.removeRange(maxPosts, mixed.length);
    }

    mixed.shuffle();

    // Build MoodPost list
    final List<MoodPost> loaded = [];

    for (final row in mixed) {
      final bool anonymousFlag = row['anonymous'] ?? false;

      String authorName = "Anonymous";
      if (!anonymousFlag) {
        final uid = row['user_id'].toString();

        if (_usernameCache.containsKey(uid)) {
          authorName = _usernameCache[uid]!;
        } else {
          final profile = await supabase
              .from('profiles')
              .select('display_name')
              .eq('id', uid)
              .maybeSingle();

          authorName = profile?['display_name'] ?? "User";
          _usernameCache[uid] = authorName;
        }
      }

      loaded.add(
        MoodPost(
          id: row['id'].toString(),
          userId: row['user_id'].toString(),
          isPositive: row['is_positive'] ?? true,
          author: authorName,
          isAnonymous: anonymousFlag,
          time: DateTime.parse(row['timestamp']),
          text: row['mood'] ?? "",
          positive: row['positive_count'] ?? 0,
          negative: row['negative_count'] ?? 0,
          imageUrl: row['image_url'],
          videoUrl: row['video_url'],
        ),
      );
    }

    setState(() {
      _posts = loaded;
      _isLoading = false;
    });
  }



  List<MoodPost> get _visiblePosts {
    List<MoodPost> filtered;

    if (_filter == MoodFilter.all) {
      filtered = List.from(_posts);
    } else {
      final wantPositive = _filter == MoodFilter.positive;
      filtered = _posts.where((p) => p.isPositive == wantPositive).toList();
    }

    return filtered;   // ❌ no shuffle here
  }


  void _setFilter(MoodFilter filter) {
    setState(() {
      _filter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final posts = _visiblePosts;
    final bool showBanner = !isVip && _topBannerReady;

    return Scaffold(
      body: SafeArea(
        child: LiquidBackground(
          child: Column(
            children: [
              // HEADER BAR (fixed)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "MoodCast Feed",
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDAF7FF),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () async {
                        await _loadPosts();
                      },

                    ),
                  ],
                ),
              ),

              // SMALL DESCRIPTION + FILTERS (fixed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "See what people are feeling right now.",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FilterChipRow(
                      active: _filter,
                      onChanged: _setFilter,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // MAIN X-STYLE FEED
              Expanded(
                child: RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  onRefresh: _loadPosts,
                  child: _isLoading && posts.isEmpty
                      ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : ListView.builder(
                    controller: _scrollController,    // ⭐ added
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                    itemCount: posts.length +

                        1 + // intro card
                        (showBanner ? 1 : 0), // banner optional
                    itemBuilder: (context, index) {
                      // 0: banner (if exists)
                      if (showBanner && index == 0) {
                        return Padding(
                          padding:
                          const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            height: _topBanner!.size.height
                                .toDouble(),
                            child: AdWidget(ad: _topBanner!),
                          ),
                        );
                      }

                      // Intro card index (after banner or at top)
                      final introIndex = showBanner ? 1 : 0;
                      if (index == introIndex) {
                        return const _FeedIntroCard();
                      }

                      // Posts
                      final postIndex =
                          index - (showBanner ? 2 : 1);
                      if (postIndex < 0 ||
                          postIndex >= posts.length) {
                        return const SizedBox.shrink();
                      }
                      final post = posts[postIndex];
                      return _PostTile(post: post);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ⭐ BACK TO TOP BUTTON
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF00FEFC),
        child: const Icon(Icons.arrow_upward, color: Colors.black),
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        },
      )
          : null,
    );

  }
}

// -------------------------------------------------------------
// INTRO CARD (TOP OF FEED, NOT AI, RANDOM LOTTO LINE)
// -------------------------------------------------------------

class _FeedIntroCard extends StatelessWidget {
  const _FeedIntroCard();

  @override
  Widget build(BuildContext context) {
    final List<String> promoLines = [
      "Today’s energy feels open. It might be a good day to try your lucky numbers.",
      "Your mood and your numbers are more connected than you think.",
      "If you’ve had a strong feeling today, it could be a perfect time to capture it in your lotto picks.",
      "Some days feel ordinary. Others feel charged. Listen to that nudge.",
      "If your gut keeps mentioning numbers today, don’t ignore it.",
    ];

    final String selectedLine =
    promoLines[DateTime.now().second % promoLines.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.03),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed duplicate banner
                SizedBox(height: 4),

                Text(
                  "Feeling a nudge to play?",
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDAF7FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedLine,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    height: 1.35,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AILottoXInputScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          "Tap here to open your AI Lotto input screen",
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: const Color(0xFF72FFD6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Color(0xFF72FFD6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SINGLE POST TILE (X STYLE LIST ITEM)
// -------------------------------------------------------------

class _PostTile extends StatefulWidget {
  final MoodPost post;

  const _PostTile({required this.post});

  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile> {
  bool _mediaTapLocked = false;
  String? _myReaction; // 'positive' or 'negative'

  bool _flaggedByMe = false;

  @override
  void initState() {
    super.initState();
    _loadMyReaction();
  }

  Future<void> _loadMyReaction() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('mood_reactions')
        .select('reaction_type')
        .eq('mood_id', widget.post.id)
        .eq('user_id', user.id)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _myReaction = response['reaction_type'];
      });
    }
  }

  Future<void> _replaceReaction(String newType) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.rpc('update_reaction', params: {
      'p_mood': widget.post.id,
      'p_user': user.id,
      'p_type': newType, // 'positive' or 'negative'
    });

    // refresh post
    final refreshed = await supabase
        .from('moods')
        .select()
        .eq('id', widget.post.id)
        .maybeSingle();

    if (refreshed != null) {
      setState(() {
        _myReaction = newType;
        widget.post.positive = refreshed['positive_count'] ?? 0;
        widget.post.negative = refreshed['negative_count'] ?? 0;
        widget.post.isPositive = refreshed['is_positive'] ?? true;
      });
    }
  }


  Future<void> _deletePost() async {
    final supabase = Supabase.instance.client;

    await supabase.rpc('delete_mood_post', params: {
      'moodid': widget.post.id,
    });

    if (!mounted) return;

    // 🔥 REMOVE FROM UI IMMEDIATELY
    final feedState = context.findAncestorStateOfType<_MoodCastFeedScreenState>();
    if (feedState != null) {
      feedState.setState(() {
        feedState._posts.removeWhere((p) => p.id == widget.post.id);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.black87,
        content: Text(
          "Post deleted.",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _flagPost() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1) Prevent double flagging (local UI lock)
    if (_flaggedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.black87,
          content: Text("You already flagged this post."),
        ),
      );
      return;
    }

    // 2) Flag in Supabase
    await supabase.rpc('flag_mood_post', params: {
      'moodid': widget.post.id,
      'userid': user.id,
    });

    // 3) Update local UI
    if (mounted) {
      setState(() {
        _flaggedByMe = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.black87,
          content: Text("Post flagged for review."),
        ),
      );
    }

    // 4) Check if Supabase hid it (flag_count ≥ 3)
    final refreshed = await supabase
        .from('moods')
        .select('is_hidden')
        .eq('id', widget.post.id)
        .maybeSingle();

    if (refreshed != null && refreshed['is_hidden'] == true) {
      // Hide instantly from UI
      if (mounted) {
        setState(() {});
      }
    }
  }



  void _openVideo(String url) {
    if (_mediaTapLocked) return;
    _mediaTapLocked = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: url),
      ),
    ).then((_) {
      _mediaTapLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canDelete =
        widget.post.userId == Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _MoodPostCard(
        post: widget.post,
        myReaction: _myReaction,
        flaggedByMe: _flaggedByMe,
        onReactionTap: _replaceReaction,
        onFlag: _flagPost,
        canDelete: canDelete,
        onDelete: canDelete ? _deletePost : null,

        onOpenVideo: _openVideo,
      ),
    );
  }
}

// -------------------------------------------------------------
// FILTER CHIPS
// -------------------------------------------------------------

class _FilterChipRow extends StatelessWidget {
  final MoodFilter active;
  final void Function(MoodFilter) onChanged;

  const _FilterChipRow({
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterPill(
          label: "All",
          selected: active == MoodFilter.all,
          onTap: () => onChanged(MoodFilter.all),
        ),
        _FilterPill(
          label: "Positive",
          selected: active == MoodFilter.positive,
          onTap: () => onChanged(MoodFilter.positive),
        ),
        _FilterPill(
          label: "Negative",
          selected: active == MoodFilter.negative,
          onTap: () => onChanged(MoodFilter.negative),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
    selected ? Colors.black87 : Colors.white.withOpacity(0.8);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: 1,
          ),
          gradient: LinearGradient(
            colors: selected
                ? [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.10),
            ]
                : [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// POST CARD (GLASSY X-STYLE CARD)
// -------------------------------------------------------------

class _MoodPostCard extends StatelessWidget {
  final MoodPost post;
  final String? myReaction;
  final bool flaggedByMe;                     // ⭐ NEW
  final void Function(String columnName) onReactionTap;
  final VoidCallback onFlag;
  final bool canDelete;
  final VoidCallback? onDelete;
  final void Function(String url) onOpenVideo;

  const _MoodPostCard({
    required this.post,
    required this.myReaction,
    required this.flaggedByMe,
    required this.onReactionTap,
    required this.onFlag,
    required this.canDelete,
    required this.onDelete,
    required this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildText(),
              const SizedBox(height: 8),

              // Link preview (if any link)
              FutureBuilder<LinkPreviewData?>(
                future: _extractAndFetchLink(post.text),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final data = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _openUrl(data.url),
                      child: LinkPreviewBox(data: data),
                    ),
                  );
                },
              ),

              _buildMedia(context),
              const SizedBox(height: 8),

              _buildMoodBar(post.isPositive),
              const SizedBox(height: 8),

              _buildReactions(context),
              const SizedBox(height: 8),

              Row(
                children: [
                  Text(
                    _timeAgo(post.time),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  // URL extract + fetch
  Future<LinkPreviewData?> _extractAndFetchLink(String text) async {
    final exp = RegExp(r'(https?://[^\s]+)');
    final match = exp.firstMatch(text);
    if (match == null) return null;
    final url = match.group(0)!;
    return await fetchLinkPreview(url);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not open url: $url");
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.40),
          ),
          child: Center(
            child: _FeedMoodWaveIcon(
              waveType: post.isPositive ? WaveType.rising : WaveType.sinking,
              isActive: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.isAnonymous ? "Anonymous" : post.author,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // ⭐ no ugly wrapping
              ),
              Text(
                post.isPositive ? "Positive mood" : "Heavier mood",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        // Removed time from here (now at bottom)
        if (canDelete) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 18,
            ),
          ),
        ],
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final text = post.text;
            String shareContent = text;

            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
              shareContent += "\n\nImage: ${post.imageUrl}";
            }
            if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
              shareContent += "\n\nVideo: ${post.videoUrl}";
            }

            await Share.share(shareContent);
          },
          child: const Icon(
            Icons.share_outlined,
            color: Colors.white70,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onFlag,
          child: Icon(
            Icons.flag,
            size: 18,
            color: flaggedByMe ? Colors.redAccent : Colors.white54,

          ),
        ),



      ],
    );
  }

  Widget _buildText() {
    return Text(
      post.text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.35,
        color: Colors.white.withOpacity(0.94),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final hasLink = RegExp(r'(https?://[^\s]+)').hasMatch(post.text);
    if (hasLink) return const SizedBox.shrink();

    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasVideo = post.videoUrl != null && post.videoUrl!.isNotEmpty;

    if (!hasImage && !hasVideo) {
      return const SizedBox.shrink();
    }

    if (hasImage) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullImageView(url: post.imageUrl!),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(post.imageUrl!, fit: BoxFit.cover),
          ),
        ),
      );

    }

    // VIDEO SUPPORT (TikTok / YouTube / MP4)
    final url = post.videoUrl!;
    final isYouTube = url.contains("youtube.com") || url.contains("youtu.be");


    // YouTube preview tile
    if (isYouTube) {
      return GestureDetector(
        onTap: () => onOpenVideo(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 200,
            color: Colors.black12,
            child: const Center(
              child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white),
            ),
          ),
        ),
      );
    }




    // MP4 auto-play inside feed
    return _InlineAutoVideoPlayer(videoUrl: url);

  }

  Widget _buildMoodBar(bool isPositive) {
    return Row(
      children: [
        Container(
          width: 15,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24, width: 0.9),
          ),
          child: Align(
            alignment:
            isPositive ? Alignment.bottomCenter : Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: isPositive
                        ? const [Color(0xFF00FEFC), Color(0xFF72FFD6)]
                        : const [Color(0xFFFF4B7D), Color(0xFFFF9A8B)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isPositive
                ? "This mood adds lift to today’s MoodCast."
                : "This mood adds weight to today’s MoodCast.",
            style: GoogleFonts.poppins(
              fontSize: 10,
              height: 1.3,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ReactionChip(
          icon: Icons.favorite,
          label: "Positive",
          count: post.positive,
          selected: myReaction == "positive",
          onTap: () => onReactionTap("positive"),
        ),
        _ReactionChip(
          icon: Icons.heart_broken,
          label: "Negative",
          count: post.negative,
          selected: myReaction == "negative",
          onTap: () => onReactionTap("negative"),
        ),
      ],
    );
  }


  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}

// -------------------------------------------------------------
// LINK PREVIEW WIDGET
// -------------------------------------------------------------

class LinkPreviewBox extends StatelessWidget {
  final LinkPreviewData data;

  const LinkPreviewBox({super.key, required this.data});

  bool _isValidImage(String url) {
    return url.isNotEmpty &&
        (url.startsWith("http://") || url.startsWith("https://")) &&
        (url.endsWith(".jpg") ||
            url.endsWith(".jpeg") ||
            url.endsWith(".png") ||
            url.endsWith(".webp") ||
            url.contains("image"));
  }

  @override
  Widget build(BuildContext context) {
    final bool showImage = _isValidImage(data.image);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      data.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(); // no red X ever
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              Text(
                data.title.isEmpty ? data.url : data.title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              if (data.description.isNotEmpty)
                Text(
                  data.description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.3,
                    color: Colors.white70,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 6),

              Text(
                data.url,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// INLINE AUTO-PLAYING MP4 WITH VISIBILITY DETECTOR
// -------------------------------------------------------------
class _InlineAutoVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _InlineAutoVideoPlayer({required this.videoUrl});

  @override
  State<_InlineAutoVideoPlayer> createState() => _InlineAutoVideoPlayerState();
}

class _InlineAutoVideoPlayerState extends State<_InlineAutoVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _visible = false;
  bool _muted = true;
  bool _paused = false;
  bool _showControls = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        _controller.setVolume(0.0);
        setState(() => _ready = true);
      });

    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
    _showControls = true;
    _startHideTimer();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0.0 : 1.0);
    });
    _showControls = true;
    _startHideTimer();
  }

  void _onTapVideo() {
    _togglePlay();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    // temporary unmute
    if (_muted) _controller.setVolume(1.0);
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    // revert mute state
    if (_muted) _controller.setVolume(0.0);
  }

  void _handleVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.30;

    if (!visible && _controller.value.isPlaying) {
      _controller.pause();
    }

    if (visible && !_paused && !_controller.value.isPlaying) {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _handleVisibility,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
          child: Stack(
            children: [
              // VIDEO
              GestureDetector(
                onTap: _onTapVideo,
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
                child: _ready
                    ? VideoPlayer(_controller)
                    : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),

              // BUFFERING INDICATOR
              if (_ready && _controller.value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),

              // PLAY/PAUSE — fades in/out
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          _paused ? Icons.play_arrow : Icons.pause,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

// MUTE BUTTON — ALWAYS VISIBLE
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      size: 18,
                      color: Colors.white,
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
}



// -------------------------------------------------------------
// FULLSCREEN UNIVERSAL VIDEO HANDLER (YOUTUBE / TIKTOK / MP4)
// -------------------------------------------------------------
class VideoPlayerScreen extends StatelessWidget {
  final String videoUrl;
  const VideoPlayerScreen({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final isYouTube =
        videoUrl.contains("youtube.com") || videoUrl.contains("youtu.be");


    if (isYouTube) {
      return _YouTubeScreen(url: videoUrl);
    }

    // fallback to MP4 fullscreen player
    return _MP4FullScreen(url: videoUrl);
  }
}

// -------------------------------------------------------------
// NEW YOUTUBE FULLSCREEN (2024 WEBVIEW API)
// -------------------------------------------------------------
class _YouTubeScreen extends StatefulWidget {
  final String url;
  const _YouTubeScreen({required this.url});

  @override
  State<_YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<_YouTubeScreen> {
  late final WebViewController controller;

  String _convert(String url) {
    if (url.contains("watch?v=")) {
      final id = url.split("watch?v=").last.split("&").first;
      return "https://www.youtube.com/embed/$id?autoplay=1&playsinline=1";
    }

    if (url.contains("youtu.be/")) {
      final id = url.split("youtu.be/").last;
      return "https://www.youtube.com/embed/$id?autoplay=1&playsinline=1";
    }

    return url;
  }

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..loadRequest(Uri.parse(_convert(widget.url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}






// -------------------------------------------------------------
// MP4 FULLSCREEN VIDEO PLAYER
// -------------------------------------------------------------
class _MP4FullScreen extends StatefulWidget {
  final String url;
  const _MP4FullScreen({required this.url});

  @override
  State<_MP4FullScreen> createState() => _MP4FullScreenState();
}

class _MP4FullScreenState extends State<_MP4FullScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller =
    VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _ready
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
                : const CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
          Positioned(
            top: 20,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}




// -------------------------------------------------------------
// REACTION CHIP (STATE PASSED IN)
// -------------------------------------------------------------

class _ReactionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF72FFD6) : Colors.white24,
            width: selected ? 1.4 : 0.9,
          ),
          gradient: LinearGradient(
            colors: selected
                ? [
              const Color(0xFF00FEFC).withOpacity(0.33),
              const Color(0xFF72FFD6).withOpacity(0.22),
            ]
                : [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: selected ? Colors.white : Colors.white70,
                fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: selected ? Colors.white : Colors.white54,
                fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WAVE ICON (FEED VERSION)
// -------------------------------------------------------------

enum WaveType { rising, sinking }

class _FeedMoodWaveIcon extends StatelessWidget {
  final WaveType waveType;
  final bool isActive;

  const _FeedMoodWaveIcon({
    required this.waveType,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final rising = waveType == WaveType.rising;

    return CustomPaint(
      size: const Size(22, 16),
      painter: _FeedWavePainter(
        rising: rising,
        glow: isActive,
      ),
    );
  }
}

class _FeedWavePainter extends CustomPainter {
  final bool rising;
  final bool glow;

  _FeedWavePainter({required this.rising, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;

    if (rising) {
      path.moveTo(0, h * 0.7);
      path.quadraticBezierTo(
          w * 0.25, h * 0.35, w * 0.5, h * 0.55);
      path.quadraticBezierTo(
          w * 0.75, h * 0.80, w, h * 0.30);
    } else {
      path.moveTo(0, h * 0.3);
      path.quadraticBezierTo(
          w * 0.25, h * 0.65, w * 0.5, h * 0.45);
      path.quadraticBezierTo(
          w * 0.75, h * 0.20, w, h * 0.70);
    }

    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withOpacity(0.20)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glowPaint);
    }

    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FEFC), Color(0xFFDAF7FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, mainPaint);
  }

  @override
  bool shouldRepaint(_FeedWavePainter oldDelegate) {
    return oldDelegate.rising != rising || oldDelegate.glow != glow;
  }
}






  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

class _FullImageView extends StatelessWidget {
  final String url;
  const _FullImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }
}
