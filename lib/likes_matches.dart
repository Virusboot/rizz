import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backend.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// ------------------------------------------------------------ match dialog

/// Shows "It's a match" and opens the chat if the user taps Say hello.
Future<void> showMatchDialog(
  BuildContext context, {
  required AppUser me,
  required AppUser other,
  required String matchId,
}) async {
  final openChat = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Avatar(url: me.mainPhoto, radius: 38),
          const SizedBox(width: 12),
          Avatar(url: other.mainPhoto, radius: 38),
        ]),
        const SizedBox(height: 18),
        const Text("It's a match!",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('You and ${other.name} like each other.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted)),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kBrand,
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Say hello'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep browsing'),
        ),
      ]),
    ),
  );
  if (openChat == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          matchId: matchId,
          otherId: other.uid,
          otherName: other.name,
          otherPhoto: other.mainPhoto,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- likes

class LikesScreen extends StatefulWidget {
  final AppUser me;
  final PoolController pool;
  const LikesScreen({super.key, required this.me, required this.pool});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  List<LikeItem>? items;
  String? error;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Backend.likesReceived(widget.me);
      if (!mounted) return;
      setState(() {
        items = l;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = Backend.friendlyError(e));
    }
  }

  void _removeLocal(String id) {
    final l = items;
    if (l == null || !mounted) return;
    setState(() => items = l.where((i) => i.user.uid != id).toList());
  }

  Future<void> _likeBack(AppUser u) async {
    if (_processing.contains(u.uid)) return;
    HapticFeedback.mediumImpact();
    setState(() => _processing.add(u.uid));
    try {
      final matchId = await Backend.like(widget.me, u);
      widget.pool.removeUser(u.uid);
      _removeLocal(u.uid);
      if (matchId != null && mounted) {
        await showMatchDialog(context,
            me: widget.me, other: u, matchId: matchId);
      }
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _processing.remove(u.uid));
    }
  }

  Future<void> _pass(AppUser u) async {
    if (_processing.contains(u.uid)) return;
    HapticFeedback.lightImpact();
    setState(() => _processing.add(u.uid));
    try {
      await Backend.pass(u.uid);
      widget.pool.removeUser(u.uid);
      _removeLocal(u.uid);
      if (mounted) toast(context, 'Passed on ${u.name}');
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _processing.remove(u.uid));
    }
  }

  void _open(LikeItem item) {
    final u = item.user;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          user: u,
          likeLabel: 'Like back',
          onLike: () => _likeBack(u),
          onPass: () => _pass(u),
          onRemoved: () {
            widget.pool.removeUser(u.uid);
            _removeLocal(u.uid);
          },
        ),
      ),
    );
  }

  Widget _card(LikeItem item) {
    final u = item.user;
    final isWorking = _processing.contains(u.uid);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: item.spark
            ? Border.all(color: kBrand, width: 2)
            : Border.all(color: kLine),
        boxShadow: [
          BoxShadow(
            color: item.spark
                ? kBrand.withOpacity(0.2)
                : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Clickable Photo Area
            GestureDetector(
              onTap: () => _open(item),
              child: NetImage(url: u.mainPhoto),
            ),

            // Gradient Overlay
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.92),
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // VIP Spark Badge
            if (item.spark)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kBrand, kBrandOrange],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: kBrand.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Spark',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          )),
                    ],
                  ),
                ),
              ),

            // User Info & Quick Action Buttons at Bottom
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _open(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${u.name}, ${u.age}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (u.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 15, color: kBrand),
                            ],
                          ],
                        ),
                        if (u.city.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            u.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Action Buttons
                  Row(
                    children: [
                      // Pass Button
                      Expanded(
                        child: GestureDetector(
                          onTap: isWorking ? null : () => _pass(u),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Like Back Button
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: isWorking ? null : () => _likeBack(u),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [kBrand, kBrandOrange],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: kBrand.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isWorking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.favorite_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Match',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    Widget body;
    if (error != null && l == null) {
      body = EmptyState(
        icon: Icons.wifi_off,
        title: 'Could not load',
        body: error!,
        cta: 'Try again',
        onCta: _load,
      );
    } else if (l == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (l.isEmpty) {
      body = EmptyState(
        icon: Icons.favorite_border,
        title: 'No new likes yet',
        body:
            'When someone likes your profile, they will appear here. Answer prompts or send a Spark to get noticed!',
        cta: 'Refresh',
        onCta: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            // Subtitle banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kLine),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: kBrand, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.length} ${l.length == 1 ? "person" : "people"} liked you! Match to start chatting.',
                      style: TextStyle(
                        color: kInk.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                itemCount: l.length,
                itemBuilder: (_, i) => _card(l[i]),
              ),
            ),
          ],
        ),
      );
    }
    return Column(children: [
      screenTitle('Likes You'),
      Expanded(child: body),
    ]);
  }
}

// ----------------------------------------------------------------- matches

class MatchesScreen extends StatefulWidget {
  final AppUser me;
  const MatchesScreen({super.key, required this.me});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late final Stream<List<MatchItem>> stream = Backend.watchMatches();

  AppUser get me => widget.me;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      screenTitle('Matches'),
      Expanded(
        child: StreamBuilder<List<MatchItem>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off,
                title: 'Could not load',
                body: Backend.friendlyError(snap.error!),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No matches yet',
                body: 'When a like is mutual, you can start chatting here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(color: kLine),
              itemBuilder: (_, i) {
                final m = list[i];
                final name = m.otherName(me.uid);
                final mine = m.lastSender == me.uid;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(url: m.otherPhoto(me.uid), radius: 28),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    m.lastMessage.isEmpty
                        ? 'Say hello'
                        : (mine ? 'You: ${m.lastMessage}' : m.lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        matchId: m.id,
                        otherId: m.otherId(me.uid),
                        otherName: name,
                        otherPhoto: m.otherPhoto(me.uid),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// -------------------------------------------------------------------- chat

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String otherId;
  final String otherName;
  final String? otherPhoto;
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherId,
    required this.otherName,
    this.otherPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctrl = TextEditingController();
  late final Stream<List<ChatMsg>> stream =
      Backend.watchMessages(widget.matchId);
  bool sending = false;

  @override
  void initState() {
    super.initState();
    Backend.openChatId = widget.matchId;
  }

  @override
  void dispose() {
    if (Backend.openChatId == widget.matchId) Backend.openChatId = null;
    ctrl.dispose();
    super.dispose();
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _send([String? customText]) async {
    final t = (customText ?? ctrl.text).trim();
    if (t.isEmpty || sending) return;
    if (customText == null) ctrl.clear();
    setState(() => sending = true);
    try {
      await Backend.sendMessage(widget.matchId, t, otherId: widget.otherId);
    } catch (e) {
      if (mounted) {
        if (customText == null) ctrl.text = t;
        toast(context, Backend.friendlyError(e));
      }
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _menu(String v) async {
    if (v == 'unmatch') {
      final ok = await confirmDialog(
        context,
        title: 'Unmatch ${widget.otherName}?',
        body: 'This deletes your chat. You will not see each other in matches.',
        confirmText: 'Unmatch',
        danger: true,
      );
      if (!ok) return;
      await Backend.removeMatch(widget.matchId);
      if (mounted) Navigator.pop(context);
      return;
    }
    final done = await showSafetySheet(
      context,
      otherId: widget.otherId,
      otherName: widget.otherName,
      matchId: widget.matchId,
    );
    if (done && mounted) Navigator.pop(context);
  }

  Widget _bubble(ChatMsg m, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? kBrand : kSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.text,
                style: TextStyle(color: mine ? Colors.white : kInk)),
            if (m.at != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_hm(m.at!),
                    style: TextStyle(
                        fontSize: 10,
                        color: mine ? Colors.white70 : kMuted)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Backend.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          Avatar(url: widget.otherPhoto, radius: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(widget.otherName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'unmatch', child: Text('Unmatch')),
              PopupMenuItem(value: 'safety', child: Text('Report or block')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: kSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Be kind and respectful. Never send money or share OTPs. Meet in a public place first. You can stop any conversation at any time.',
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: StreamBuilder<List<ChatMsg>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chat not available',
                    body: 'This chat may have been closed.',
                    cta: 'Go back',
                    onCta: () => Navigator.pop(context),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return Center(
                    child: Text('Say hi to ${widget.otherName}.',
                        style: const TextStyle(color: kMuted)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) =>
                      _bubble(msgs[i], msgs[i].sender == me),
                );
              },
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (final prompt in const [
                'Hey! How has your day been? 😊',
                'Coffee or drinks this weekend? ☕',
                'Loved your profile! ✨',
                'What is your go-to weekend vibe? 🍕',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: kSoft,
                    side: const BorderSide(color: kLine),
                    label: Text(prompt,
                        style: const TextStyle(fontSize: 12, color: kInk)),
                    onPressed: () => _send(prompt),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  maxLength: 1000,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: inputDeco('Message').copyWith(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: kBrand),
                onPressed: _send,
                icon: const Icon(Icons.arrow_upward),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
