import 'package:flutter/material.dart';

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
      body: SafeArea(bottom: false, child: _page()),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: kLine),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            _item(0, Icons.explore_outlined, 'Discover'),
            _item(1, Icons.auto_awesome_outlined, 'Sparks'),
            _item(2, Icons.favorite_border, 'Likes You'),
            _item(3, Icons.chat_bubble_outline, 'Matches'),
            _item(4, Icons.person_outline, 'Profile'),
          ]),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final sel = tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: sel ? kBrand : kInk),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? kBrand : kMuted)),
          ]),
        ),
      ),
    );
  }
}
