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
  late AppUser me;
  bool busy = false;

  Future<void> _refillSpark([AppUser? u]) async {
    await Backend.resetSpark();
    final fresh = await Backend.getMe();
    if (!mounted) return;
    if (fresh != null) {
      setState(() => me = fresh);
      toast(context, 'Free Spark refilled! ✨');
      if (u != null) {
        await _confirmSpark(u);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    me = widget.me;
  }

  @override
  void didUpdateWidget(SparksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.me != oldWidget.me) {
      setState(() => me = widget.me);
    }
  }

  Future<void> _confirmSpark(AppUser u) async {
    if (busy) return;

    if (!me.canSpark) {
      final refill = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: kLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kBrandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: kBrand, size: 36),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No Sparks Remaining',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'You get 1 free Spark every week. Your next free Spark is in ${me.sparkDaysLeft} day(s).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: kMuted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrand,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Free Spark Refill (Test Refill)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Close', style: TextStyle(color: kMuted)),
                ),
              ],
            ),
          ),
        ),
      );

      if (refill == true) {
        await _refillSpark(u);
      }
      return;
    }

    final send = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: kLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [kBrand, kBrandOrange]),
                      boxShadow: [
                        BoxShadow(
                          color: kBrand.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Avatar(url: u.mainPhoto, radius: 42),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: kBrand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Send a Spark to ${u.name}? ✨',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'A Spark highlights your profile at the very top of ${u.name}\'s Likes with a golden VIP badge. Sparks are 3x more likely to match!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: kMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrand,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text('Send Spark ✨',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: kMuted)),
              ),
            ],
          ),
        ),
      ),
    );

    if (send != true) return;

    setState(() => busy = true);
    try {
      final matchId = await Backend.like(me, u, spark: true);
      widget.pool.removeUser(u.uid);
      setState(() {
        me = me.copyWith(lastSparkAt: DateTime.now());
      });
      if (mounted) toast(context, '✨ Spark sent to ${u.name}!');
      if (matchId != null && mounted) {
        await showMatchDialog(context, me: me, other: u, matchId: matchId);
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
          likeLabel: me.canSpark ? 'Send Spark ✨' : 'Like',
          onLike: () async {
            if (me.canSpark) {
              await _confirmSpark(u);
            } else {
              try {
                final matchId = await Backend.like(me, u);
                widget.pool.removeUser(u.uid);
                if (matchId != null && mounted) {
                  await showMatchDialog(context, me: me, other: u, matchId: matchId);
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

  Widget _sparkCard(AppUser u) {
    return GestureDetector(
      onTap: () => _open(u),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              NetImage(url: u.mainPhoto),
              // Gradient Shade
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x33000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.4, 0.7, 1.0],
                  ),
                ),
              ),
              // Floating Spark Button
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => _confirmSpark(u),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kBrand, kBrandOrange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kBrand.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Spark',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              // User Info at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${u.name}, ${u.age}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (u.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 16, color: kBrand),
                        ],
                      ],
                    ),
                    if (u.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        u.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      screenTitle(
        'Sparks',
        trailing: Chip(
          avatar: const Icon(Icons.auto_awesome, size: 16, color: kBrand),
          label: Text(me.canSpark ? 'Sparks (1)' : 'Sparks (0)'),
          backgroundColor: kBrandSoft,
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      ),
      // VIP Hero Banner
      Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: me.canSpark
                ? [const Color(0xFFFD3C87), const Color(0xFFFF5E97)]
                : [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (me.canSpark ? kBrand : Colors.black).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me.canSpark ? '1 Free Spark Available!' : 'Weekly Spark Used',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    me.canSpark
                        ? 'Pin your profile #1 in their Likes with VIP glow.'
                        : 'Next free spark in ${me.sparkDaysLeft} day(s).',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!me.canSpark) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kInk,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _refillSpark(),
                child: const Text('Refill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
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
            final picks = pool.pool.take(12).toList();
            if (picks.isEmpty) {
              return const EmptyState(
                icon: Icons.auto_awesome,
                title: 'No top picks right now',
                body: 'Check back soon. New people join every day.',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: picks.length,
              itemBuilder: (context, index) => _sparkCard(picks[index]),
            );
          },
        ),
      ),
    ]);
  }
}
