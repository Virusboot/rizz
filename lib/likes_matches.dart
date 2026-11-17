import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Backend.likesReceived();
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
    }
  }

  Future<void> _pass(AppUser u) async {
    try {
      await Backend.pass(u.uid);
      widget.pool.removeUser(u.uid);
      _removeLocal(u.uid);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
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
    return GestureDetector(
      onTap: () => _open(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          NetImage(url: u.mainPhoto),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
              child: Text('${u.name}, ${u.age}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
          if (item.spark)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: kBrand, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Spark',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
        ]),
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
      body = const EmptyState(
        icon: Icons.favorite_border,
        title: 'No likes yet',
        body: 'Add more photos and answer a few prompts to get noticed sooner.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: l.length,
          itemBuilder: (_, i) => _card(l[i]),
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

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty || sending) return;
    ctrl.clear();
    setState(() => sending = true);
    try {
      await Backend.sendMessage(widget.matchId, t);
    } catch (e) {
      if (mounted) {
        ctrl.text = t;
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
