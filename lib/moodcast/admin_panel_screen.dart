// lib/moodcast/admin_panel_screen.dart
// MoodCast Admin Panel — Hidden Posts, Hidden Comments, Rejected Media

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  bool _loadingPosts = false;
  bool _loadingComments = false;

  final List<_AdminPost> _hiddenPosts = [];
  final List<_AdminComment> _hiddenComments = [];
  final List<_RejectedPost> _rejected = [];

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();

    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isAdmin) {
        await _loadHiddenPosts();
        await _loadHiddenComments();
        await _loadRejectedPosts();
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // CHECK ADMIN + LOAD
  // --------------------------------------------------------------------------
  Future<void> _checkAdminAndLoad() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _checkingAdmin = false;
        _isAdmin = false;
      });
      return;
    }

    final profile = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();

    _isAdmin = profile?['is_admin'] == true;

    setState(() {
      _checkingAdmin = false;
    });

    if (_isAdmin) {
      await _loadHiddenPosts();
      await _loadHiddenComments();
      await _loadRejectedPosts();
    }
  }

  // --------------------------------------------------------------------------
  // LOADERS
  // --------------------------------------------------------------------------
  Future<void> _loadRejectedPosts() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('mood_rejections')
        .select(
        'id, mood, image_url, video_url, created_at, user_id, reason_image, reason_video, reason_text')
        .order('created_at', ascending: false);

    _rejected
      ..clear()
      ..addAll(data.map<_RejectedPost>((row) {
        return _RejectedPost(
          id: row['id'],
          text: row['mood'] ?? '',
          imageUrl: row['image_url'],
          videoUrl: row['video_url'],
          time: DateTime.parse(row['created_at'].toString()),

          userId: row['user_id'],
          reasonImage: row['reason_image'],
          reasonVideo: row['reason_video'],
          reasonText: row['reason_text'],
        );
      }));

    setState(() {});
  }

  Future<void> _loadHiddenPosts() async {
    _loadingPosts = true;
    setState(() {});

    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('moods')
        .select('id,mood,timestamp,flag_count,featured,user_id')
        .eq('is_hidden', true)
        .order('timestamp', ascending: false);

    _hiddenPosts
      ..clear()
      ..addAll(
        data.map<_AdminPost>((row) {
          return _AdminPost(
            id: row['id'],
            text: row['mood'] ?? '',
            time: DateTime.parse(row['created_at'].toString()),

            flagCount: row['flag_count'] ?? 0,
            featured: row['featured'] ?? false,
            userId: row['user_id'],
          );
        }),
      );

    _loadingPosts = false;
    setState(() {});
  }

  Future<void> _loadHiddenComments() async {
    _loadingComments = true;
    setState(() {});

    final data = await Supabase.instance.client
        .from('mood_comments')
        .select('id,text,created_at,flag_count,user_id,mood_id')
        .eq('is_hidden', true)
        .order('created_at', ascending: false);

    _hiddenComments
      ..clear()
      ..addAll(
        data.map<_AdminComment>((row) {
          return _AdminComment(
            id: row['id'],
            text: row['text'] ?? '',
            time: DateTime.parse(row['created_at'].toString()),

            flagCount: row['flag_count'] ?? 0,
            userId: row['user_id'],
            moodId: row['mood_id'],
          );
        }),
      );

    _loadingComments = false;
    setState(() {});
  }

  // --------------------------------------------------------------------------
  // ADMIN ACTIONS
  // --------------------------------------------------------------------------
  Future<void> approvePost(String id) async {
    await Supabase.instance.client.rpc('approve_rejected_post',
        params: {'p_reject_id': id});
  }

  Future<void> deleteRejected(String id) async {
    await Supabase.instance.client.rpc('delete_rejected_post',
        params: {'p_reject_id': id});
  }

  Future<void> _restorePost(_AdminPost post) async {
    await Supabase.instance.client
        .rpc('restore_mood_post', params: {'moodid': post.id});
    _hiddenPosts.removeWhere((x) => x.id == post.id);
    setState(() {});
  }

  Future<void> _deletePost(_AdminPost post) async {
    await Supabase.instance.client
        .rpc('delete_mood_post', params: {'moodid': post.id});
    _hiddenPosts.removeWhere((x) => x.id == post.id);
    setState(() {});
  }

  Future<void> _restoreComment(_AdminComment c) async {
    await Supabase.instance.client
        .rpc('restore_mood_comment', params: {'commentid': c.id});
    _hiddenComments.removeWhere((x) => x.id == c.id);
    setState(() {});
  }

  Future<void> _deleteComment(_AdminComment c) async {
    await Supabase.instance.client
        .from('mood_comments')
        .delete()
        .eq('id', c.id);
    _hiddenComments.removeWhere((x) => x.id == c.id);
    setState(() {});
  }

  // --------------------------------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.black,
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child:
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("This account does not have admin access.",
              style: GoogleFonts.poppins(color: Colors.white70)),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: LiquidBackground(
            child: Column(
              children: [
                _header(),
                _subHeader(),
                _tabs(),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildHiddenPostsTab(),
                      _buildHiddenCommentsTab(),
                      _buildRejectedTab(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text("MoodCast Admin",
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.orbitron(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDAF7FF))),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
            onPressed: () async {
              await _loadHiddenPosts();
              await _loadHiddenComments();
              await _loadRejectedPosts();
            },
          ),
        ],
      ),
    );
  }

  Widget _subHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "Review hidden posts, comments, and rejected uploads.",
        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
      ),
    );
  }

  Widget _tabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withOpacity(0.05),
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 22),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.3),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(
            child: Row(children: [
              const Icon(Icons.article_outlined, size: 15),
              const SizedBox(width: 6),
              Text("Hidden Posts (${_hiddenPosts.length})",
                  style: GoogleFonts.poppins(fontSize: 11)),
            ]),
          ),
          Tab(
            child: Row(children: [
              const Icon(Icons.comment_outlined, size: 15),
              const SizedBox(width: 6),
              Text("Hidden Comments (${_hiddenComments.length})",
                  style: GoogleFonts.poppins(fontSize: 11)),
            ]),
          ),
          Tab(
            child: Row(children: [
              const Icon(Icons.report, size: 15),
              const SizedBox(width: 6),
              Text("Rejected (${_rejected.length})",
                  style: GoogleFonts.poppins(fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB: REJECTED POSTS
  // --------------------------------------------------------------------------
  Widget _buildRejectedTab() {
    if (_rejected.isEmpty) {
      return Center(
        child: Text("No rejected posts.",
            style: GoogleFonts.poppins(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _rejected.length,
      itemBuilder: (context, i) {
        final r = _rejected[i];

        return _glassTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Rejected Post",
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent)),
              const SizedBox(height: 6),

              if (r.text.isNotEmpty)
                Text(r.text,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white)),

              if (r.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(r.imageUrl!,
                      height: 160, fit: BoxFit.cover),
                ),
              ],

              // VIDEO PREVIEW (GLASS CARD WITH VIDEO ICON)
              if (r.videoUrl != null) ...[
                const SizedBox(height: 10),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 40,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            "Video attached",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],



              const SizedBox(height: 10),
              Text(
                "Reason: ${r.reasonImage ?? r.reasonVideo ?? r.reasonText ?? 'unknown'}",
                style:
                GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
              ),

              Text("${_timeAgo(r.time)} • user ${r.userId.substring(0, 8)}…",
                  style:
                  GoogleFonts.poppins(fontSize: 9, color: Colors.white54)),

              const SizedBox(height: 10),

              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await approvePost(r.id);
                      _rejected.removeAt(i);
                      setState(() {});
                      _snack("Post approved.");
                    },
                    child: const Text("Approve",
                        style: TextStyle(color: Colors.greenAccent)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await deleteRejected(r.id);
                      _rejected.removeAt(i);
                      setState(() {});
                      _snack("Post deleted.");
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // TAB: HIDDEN POSTS
  // --------------------------------------------------------------------------
  Widget _buildHiddenPostsTab() {
    if (_loadingPosts) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (_hiddenPosts.isEmpty) {
      return Center(
        child: Text("No hidden posts.",
            style: GoogleFonts.poppins(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _hiddenPosts.length,
      itemBuilder: (context, i) {
        final post = _hiddenPosts[i];

        return Dismissible(
          key: Key(post.id),
          background: _swipeBG(Colors.green, Icons.restore),
          secondaryBackground: _swipeBG(Colors.red, Icons.delete),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await _restorePost(post);
            } else {
              await _deletePost(post);
            }
            return false;
          },
          child: _glassTile(child: _postContent(post)),
        );
      },
    );
  }

  Widget _postContent(_AdminPost post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text("Post",
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(width: 6),
          _statusChip("Hidden • ${post.flagCount} flags", Colors.redAccent),
        ]),
        const SizedBox(height: 8),
        Text(post.text,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.white.withOpacity(0.95))),
        const SizedBox(height: 8),
        Text("${_timeAgo(post.time)} • user ${post.userId.substring(0, 8)}…",
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.white54)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TAB: HIDDEN COMMENTS
  // --------------------------------------------------------------------------
  Widget _buildHiddenCommentsTab() {
    if (_loadingComments) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (_hiddenComments.isEmpty) {
      return Center(
        child: Text("No hidden comments.",
            style: GoogleFonts.poppins(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _hiddenComments.length,
      itemBuilder: (context, i) {
        final c = _hiddenComments[i];

        return Dismissible(
          key: Key(c.id),
          background: _swipeBG(Colors.green, Icons.restore),
          secondaryBackground: _swipeBG(Colors.red, Icons.delete),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await _restoreComment(c);
            } else {
              await _deleteComment(c);
            }
            return false;
          },
          child: _glassTile(child: _commentContent(c)),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // COMMENT TILE CONTENT
  // --------------------------------------------------------------------------
  Widget _commentContent(_AdminComment c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text("Comment",
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(width: 6),
          _statusChip("Hidden • ${c.flagCount} flags", Colors.redAccent),
        ]),
        const SizedBox(height: 8),
        Text(c.text,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.white.withOpacity(0.95))),
        const SizedBox(height: 8),
        Text("${_timeAgo(c.time)} • user ${c.userId.substring(0, 8)}…",
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.white54)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // REUSABLE UI PIECES
  // --------------------------------------------------------------------------
  Widget _glassTile({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _swipeBG(Color color, IconData icon) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.7)),
          color: color.withOpacity(0.15)),
      child: Text(text,
          style: GoogleFonts.poppins(fontSize: 9, color: color)),
    );
  }
}

// --------------------------------------------------------------------------
// MODELS
// --------------------------------------------------------------------------
class _AdminPost {
  final String id;
  final String text;
  final DateTime time;
  final int flagCount;
  final bool featured;
  final String userId;

  _AdminPost({
    required this.id,
    required this.text,
    required this.time,
    required this.flagCount,
    required this.featured,
    required this.userId,
  });
}

class _AdminComment {
  final String id;
  final String text;
  final DateTime time;
  final int flagCount;
  final String userId;
  final String moodId;

  _AdminComment({
    required this.id,
    required this.text,
    required this.time,
    required this.flagCount,
    required this.userId,
    required this.moodId,
  });
}

class _RejectedPost {
  final String id;
  final String text;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime time;
  final String userId;
  final String? reasonImage;
  final String? reasonVideo;
  final String? reasonText;

  _RejectedPost({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.videoUrl,
    required this.time,
    required this.userId,
    required this.reasonImage,
    required this.reasonVideo,
    required this.reasonText,
  });
}
