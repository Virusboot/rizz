import 'package:flutter/material.dart';

import 'backend.dart';
import 'likes_matches.dart';
import 'models.dart';
import 'profile.dart';
import 'theme.dart';
import 'widgets.dart';

// ---------------------------------------------------------------- discover

class DiscoverScreen extends StatefulWidget {
  final AppUser me;
  final PoolController pool;
  const DiscoverScreen({super.key, required this.me, required this.pool});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Set<String> filters = <String>{};
  bool busy = false;

  static const chipDefs = <String, String>{
    'dating': 'Dating',
    'casual': 'Casual',
    'verified': 'Verified',
    'active': 'Active today',
    'new': 'New here',
  };

  bool _passes(AppUser u) {
    final now = DateTime.now();
    if (filters.contains('dating') &&
        !(u.intent == LookingFor.dating || u.intent == LookingFor.both)) {
      return false;
    }
    if (filters.contains('casual') &&
        !(u.intent == LookingFor.casual || u.intent == LookingFor.both)) {
      return false;
    }
    if (filters.contains('verified') && !u.verified) return false;
    if (filters.contains('active')) {
      final la = u.lastActive;
      if (la == null || now.difference(la).inHours > 24) return false;
    }
    if (filters.contains('new')) {
      final ca = u.createdAt;
      if (ca == null || now.difference(ca).inDays > 7) return false;
    }
    return true;
  }

  Future<void> _like(AppUser u) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final matchId = await Backend.like(widget.me, u);
      widget.pool.removeUser(u.uid);
      if (matchId != null && mounted) {
        await showMatchDialog(context,
            me: widget.me, other: u, matchId: matchId);
      }
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pass(AppUser u) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Backend.pass(u.uid);
      widget.pool.passed(u);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _undo() async {
    final last = widget.pool.lastPassed;
    if (last == null || busy) return;
    try {
      await Backend.undoPass(last.uid);
      widget.pool.undoPass();
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
  }

  Future<void> _safety(AppUser u) async {
    final done =
        await showSafetySheet(context, otherId: u.uid, otherName: u.name);
    if (done) widget.pool.removeUser(u.uid);
  }

  void _openPrefs() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PreferencesScreen(me: widget.me, pool: widget.pool),
      ),
    );
  }

  Widget _chips() {
    final keys = chipDefs.keys.toList();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final k = keys[i];
          final sel = filters.contains(k);
          return ChoiceChip(
            label: Text(chipDefs[k]!),
            selected: sel,
            showCheckmark: false,
            selectedColor: kInk,
            backgroundColor: Colors.white,
            side: const BorderSide(color: kLine),
            shape: const StadiumBorder(),
            labelStyle: TextStyle(color: sel ? Colors.white : kInk),
            onSelected: (_) => setState(() {
              if (sel) {
                filters.remove(k);
              } else {
                filters.add(k);
              }
            }),
          );
        },
      ),
    );
  }

  Widget _content(PoolController pool) {
    final list = pool.pool.where(_passes).toList();
    if (pool.loading && pool.pool.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pool.error != null && pool.pool.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'Could not load',
        body: pool.error!,
        cta: 'Try again',
        onCta: () => pool.load(widget.me),
      );
    }
    if (list.isEmpty) {
      final filtered = filters.isNotEmpty && pool.pool.isNotEmpty;
      return EmptyState(
        icon: Icons.travel_explore,
        title: filtered ? 'No one matches these filters' : 'You are all caught up',
        body: filtered
            ? 'Try removing a filter to see more people.'
            : 'New people join every day. Widen your age range in preferences or check back soon.',
        cta: filtered ? 'Clear filters' : 'Refresh',
        onCta: filtered
            ? () => setState(filters.clear)
            : () => pool.load(widget.me),
      );
    }
    final u = list.first;
    return Stack(children: [
      ListView(
        key: ValueKey(u.uid),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              icon: Icon(Icons.undo,
                  color: pool.lastPassed == null ? kLine : kInk),
              onPressed: pool.lastPassed == null ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _safety(u),
            ),
          ]),
          ProfileBody(user: u, onLike: () => _like(u)),
        ],
      ),
      Positioned(
        left: 24,
        bottom: 16,
        child: RoundButton(
          icon: Icons.close,
          iconColor: kMuted,
          onTap: () => _pass(u),
        ),
      ),
      Positioned(
        right: 24,
        bottom: 16,
        child: RoundButton(
          icon: Icons.favorite,
          iconColor: kBrand,
          elevation: 4,
          onTap: () => _like(u),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          const RizzLogo(size: 26),
          const Spacer(),
          IconButton(icon: const Icon(Icons.tune), onPressed: _openPrefs),
        ]),
      ),
      _chips(),
      Expanded(
        child: AnimatedBuilder(
          animation: widget.pool,
          builder: (context, _) => _content(widget.pool),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ sparks

class SparksScreen extends StatefulWidget {
  final AppUser me;
  final PoolController pool;
  const SparksScreen({super.key, required this.me, required this.pool});

  @override
  State<SparksScreen> createState() => _SparksScreenState();
}

class _SparksScreenState extends State<SparksScreen> {
  bool busy = false;

  Future<void> _spark(AppUser u) async {
    if (busy) return;
    if (!widget.me.canSpark) {
      toast(context,
          'Your next Spark is in ${widget.me.sparkDaysLeft} day(s).');
      return;
    }
    setState(() => busy = true);
    try {
      final matchId = await Backend.like(widget.me, u, spark: true);
      widget.pool.removeUser(u.uid);
      if (mounted) toast(context, 'Spark sent to ${u.name}');
      if (matchId != null && mounted) {
        await showMatchDialog(context,
            me: widget.me, other: u, matchId: matchId);
      }
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pass(AppUser u) async {
    try {
      await Backend.pass(u.uid);
      widget.pool.passed(u);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
  }

  void _open(AppUser u) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          user: u,
          likeLabel: widget.me.canSpark ? 'Send Spark' : 'Like',
          onLike: () async {
            if (widget.me.canSpark) {
              await _spark(u);
            } else {
              try {
                final matchId = await Backend.like(widget.me, u);
                widget.pool.removeUser(u.uid);
                if (matchId != null && mounted) {
                  await showMatchDialog(context,
                      me: widget.me, other: u, matchId: matchId);
                }
              } catch (e) {
                if (mounted) toast(context, Backend.friendlyError(e));
              }
            }
          },
          onPass: () => _pass(u),
          onRemoved: () => widget.pool.removeUser(u.uid),
        ),
      ),
    );
  }

  Widget _tile(AppUser u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              width: 64, height: 64, child: NetImage(url: u.mainPhoto)),
        ),
        title: Row(children: [
          Flexible(
            child: Text('${u.name}, ${u.age}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (u.verified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 16, color: kBrand),
          ],
        ]),
        subtitle: Text('${u.city}  •  ${intentLabel(u.intent)}'),
        trailing: widget.me.canSpark
            ? IconButton(
                icon: const Icon(Icons.auto_awesome, color: kBrand),
                tooltip: 'Send Spark',
                onPressed: () => _spark(u),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => _open(u),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Column(children: [
      screenTitle(
        'Sparks',
        trailing: Chip(
          avatar: const Icon(Icons.auto_awesome, size: 16, color: kBrand),
          label: Text(me.canSpark ? 'Sparks (1)' : 'Sparks (0)'),
          backgroundColor: const Color(0xFFFBE3E5),
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            me.canSpark
                ? 'Top picks for you. Send your free weekly Spark to someone who stands out. Sparks are shown first in their Likes.'
                : 'Top picks for you. Your next free Spark is in ${me.sparkDaysLeft} day(s).',
            style: const TextStyle(color: kMuted),
          ),
        ),
      ),
      Expanded(
        child: AnimatedBuilder(
          animation: widget.pool,
          builder: (context, _) {
            final pool = widget.pool;
            if (pool.loading && pool.pool.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final picks = pool.pool.take(10).toList();
            if (picks.isEmpty) {
              return const EmptyState(
                icon: Icons.auto_awesome,
                title: 'No top picks right now',
                body: 'Check back soon. New people join every day.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: picks.map(_tile).toList(),
            );
          },
        ),
      ),
    ]);
  }
}
