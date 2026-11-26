import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backend.dart';
import 'discover.dart';
import 'likes_matches.dart';
import 'models.dart';
import 'notifications.dart';
import 'profile.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  final AppUser me;
  const Shell({super.key, required this.me});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final PoolController pool = PoolController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    pool.load(widget.me);
    Backend.onAppOpen(widget.me);
    Notifications.requestedTab.addListener(_onTabRequest);
    Notifications.start();
  }

  void _onTabRequest() {
    final t = Notifications.requestedTab.value;
    if (t == null) return;
    Notifications.requestedTab.value = null;
    if (mounted) setState(() => tab = t);
  }

  @override
  void dispose() {
    Notifications.requestedTab.removeListener(_onTabRequest);
    pool.dispose();
    super.dispose();
  }

  Widget _page() {
    switch (tab) {
      case 0:
        return DiscoverScreen(me: widget.me, pool: pool);
      case 1:
        return SparksScreen(me: widget.me, pool: pool);
      case 2:
        return LikesScreen(me: widget.me, pool: pool);
      case 3:
        return MatchesScreen(me: widget.me);
      default:
        return ProfileScreen(me: widget.me, pool: pool);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey<int>(tab),
            child: _page(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: kLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x08FD3C87),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 5;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Animated sliding background pill indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: tab * itemWidth,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFEFF5),
                            Color(0xFFFFE5F0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: kBrand.withOpacity(0.20),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kBrand.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Row of navigation items
                  Row(
                    children: [
                      _item(0, Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
                      _item(1, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Sparks'),
                      _item(2, Icons.favorite_border_rounded, Icons.favorite_rounded, 'Likes'),
                      _item(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Matches'),
                      _item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData inactiveIcon, IconData activeIcon, String label) {
    final sel = tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (tab != i) {
            HapticFeedback.lightImpact();
            setState(() => tab = i);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with bounce scale & animated switcher between outline & filled
              AnimatedScale(
                scale: sel ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    sel ? activeIcon : inactiveIcon,
                    key: ValueKey<bool>(sel),
                    size: 22,
                    color: sel ? kBrand : kInk.withOpacity(0.65),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Label with animated font weight and color
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? kBrand : kMuted,
                  letterSpacing: sel ? 0.1 : 0,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
