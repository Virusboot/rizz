import 'package:flutter/material.dart';

import 'backend.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// ----------------------------------------------------------------- profile

class ProfileScreen extends StatefulWidget {
  final AppUser me;
  final PoolController pool;
  const ProfileScreen({super.key, required this.me, required this.pool});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 3, vsync: this);
  bool busy = false;

  AppUser get me => widget.me;

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, {String? done}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
      if (done != null && mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reloadPool() async {
    final fresh = await Backend.getMe();
    if (fresh != null) widget.pool.load(fresh);
  }

  Widget _tile(
    IconData icon,
    Color bg,
    String title,
    String sub, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: bg,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  // ------------------------------------------------------------- get more

  int _strength() {
    var s = 0;
    s += (me.photos.length > 4 ? 4 : me.photos.length) * 10;
    s += (me.prompts.length > 3 ? 3 : me.prompts.length) * 10;
    if (me.verified) s += 20;
    if (Backend.emailVerified) s += 10;
    return s;
  }

  List<String> _tips() {
    final t = <String>[];
    if (me.photos.length < 4) t.add('Add more photos');
    if (me.prompts.length < 3) t.add('Answer all 3 prompts');
    if (!me.verified) t.add('Get verified with a selfie');
    if (!Backend.emailVerified) t.add('Verify your email');
    return t;
  }

  String _boostSub() {
    if (me.boosted) {
      final t = me.boostUntil!.toLocal();
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return 'Active now. You are boosted until $hh:$mm.';
    }
    if (me.canBoost) {
      return 'Get shown to more people for 30 minutes. Free during launch.';
    }
    return 'Available again in ${me.boostHoursLeft} hour(s).';
  }

  Widget _getMore() {
    final s = _strength();
    final tips = _tips();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profile strength: $s%',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s / 100,
              minHeight: 8,
              color: kBrand,
              backgroundColor: Colors.white,
            ),
          ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('•  $t', style: const TextStyle(color: kMuted)),
              ),
          ],
        ]),
      ),
      _tile(
        Icons.bolt,
        const Color(0xFF2F7A78),
        'Boost',
        _boostSub(),
        onTap: (me.canBoost && !me.boosted)
            ? () => _run(() async {
                  await Backend.boost();
                  _reloadPool();
                }, done: 'Boost started for 30 minutes')
            : null,
      ),
      _tile(
        Icons.auto_awesome,
        kBrand,
        'Spark',
        me.canSpark
            ? 'You have 1 free Spark this week. Send it from the Sparks tab.'
            : 'Your next free Spark is in ${me.sparkDaysLeft} day(s).',
      ),
    ]);
  }

  // --------------------------------------------------------------- safety

  Future<void> _selfie() async {
    if (me.verified || me.verifyPending) return;
    final ok = await confirmDialog(
      context,
      title: 'Verify with a selfie',
      body:
          'Take a clear selfie of your face. It is stored privately and only used by our team to check you match your photos.',
      confirmText: 'Take selfie',
    );
    if (!ok) return;
    await _run(() async {
      final sent = await Backend.submitSelfie();
      if (sent && mounted) {
        toast(context, 'Selfie sent. We will review it soon.');
      }
    });
  }

  Future<void> _email() async {
    await _run(() async {
      final ok = await Backend.checkOrSendEmailVerification();
      if (!mounted) return;
      toast(
          context,
          ok
              ? 'Your email is verified.'
              : 'Verification link sent. Check your inbox, then tap here again.');
      setState(() {});
    });
  }

  Widget _safety() {
    final emailOk = Backend.emailVerified;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _tile(
        me.verified ? Icons.verified : Icons.verified_outlined,
        kInk,
        'Selfie verification',
        me.verified
            ? 'You are verified.'
            : (me.verifyPending
                ? 'Under review. We will update you soon.'
                : 'You are not verified yet. Tap to start.'),
        onTap: _selfie,
      ),
      _tile(
        Icons.mark_email_read_outlined,
        const Color(0xFF5B8DEF),
        'Email verification',
        emailOk ? 'Your email is verified.' : 'Tap to send a verification link.',
        onTap: emailOk ? null : _email,
      ),
      _tile(
        Icons.pause_circle_outline,
        const Color(0xFF8D88C9),
        'Pause my profile',
        'Hide yourself from Discover. Your matches and chats stay.',
        trailing: Switch(
          value: me.paused,
          onChanged: busy ? null : (v) => _run(() => Backend.setPaused(v)),
        ),
      ),
      _tile(
        Icons.back_hand_outlined,
        kMuted,
        'Block list',
        'See and unblock people.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const BlockListScreen()),
        ),
      ),
      _tile(
        Icons.tips_and_updates_outlined,
        kMuted,
        'Safety tips',
        'Stay safe when you chat and meet.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SafetyTipsScreen()),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Need help right now?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('India helplines',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Emergency: 112'),
          Text('Women Helpline: 181'),
          Text('Tele-MANAS mental health support: 14416'),
        ]),
      ),
    ]);
  }

  // ------------------------------------------------------------- my rizz

  Future<void> _signOut() async {
    final ok = await confirmDialog(context,
        title: 'Sign out?', body: 'You can sign back in anytime.',
        confirmText: 'Sign out');
    if (ok) await Backend.signOut();
  }

  Future<void> _deleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'This permanently deletes your profile, photos, matches and chats. This cannot be undone.\n\nEnter your password to confirm.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: true,
            decoration: inputDeco('Password'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (pw == null || pw.isEmpty) return;
    try {
      await Backend.deleteAccount(pw);
    } catch (e) {
      // This screen may already be gone, so use the app-level messenger.
      messenger
          .showSnackBar(SnackBar(content: Text(Backend.friendlyError(e))));
    }
  }

  Widget _myRizz() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('I am looking for',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      SegmentedButton<LookingFor>(
        showSelectedIcon: false,
        segments: [
          for (final i in LookingFor.values)
            ButtonSegment<LookingFor>(value: i, label: Text(intentLabel(i))),
        ],
        selected: {me.intent},
        onSelectionChanged: busy
            ? null
            : (s) => _run(() async {
                  await Backend.setIntent(s.first);
                  await _reloadPool();
                }),
      ),
      const SizedBox(height: 20),
      _tile(
        Icons.edit_outlined,
        kInk,
        'Edit profile',
        'Photos, prompts, name and city',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => EditProfileScreen(me: me)),
        ),
      ),
      _tile(
        Icons.tune,
        kInk,
        'Dating preferences',
        'Who you want to see',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PreferencesScreen(me: me, pool: widget.pool),
          ),
        ),
      ),
      _tile(
        Icons.notifications_none,
        kInk,
        'Notifications',
        'Matches, messages and likes',
        trailing: Switch(
          value: me.notify,
          onChanged: busy ? null : (v) => _run(() => Backend.setNotifications(v)),
        ),
      ),
      _tile(Icons.logout, kMuted, 'Sign out', Backend.auth.currentUser?.email ?? '',
          onTap: _signOut),
      _tile(Icons.delete_outline, Colors.red, 'Delete account',
          'Permanently remove all your data',
          onTap: _deleteAccount),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
        child: Avatar(url: me.mainPhoto, radius: 56),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text(me.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        Icon(Icons.verified, color: me.verified ? kBrand : kLine),
      ]),
      const SizedBox(height: 8),
      TabBar(
        controller: tc,
        labelColor: kBrand,
        unselectedLabelColor: kMuted,
        indicatorColor: kBrand,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        dividerColor: kLine,
        tabs: const [
          Tab(text: 'Get more'),
          Tab(text: 'Safety'),
          Tab(text: 'My Hookin'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: tc,
          children: [_getMore(), _safety(), _myRizz()],
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------ edit profile

class EditProfileScreen extends StatefulWidget {
  final AppUser me;
  const EditProfileScreen({super.key, required this.me});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name =
      TextEditingController(text: widget.me.name);
  late final TextEditingController city =
      TextEditingController(text: widget.me.city);
  late LookingFor intent = widget.me.intent;
  late List<String> photos = [...widget.me.photos];
  late List<Prompt> prompts = [...widget.me.prompts];
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().length < 2) {
      toast(context, 'Enter your first name.');
      return;
    }
    if (city.text.trim().length < 2) {
      toast(context, 'Enter your city.');
      return;
    }
    if (photos.length < 2) {
      toast(context, 'Keep at least 2 photos.');
      return;
    }
    if (prompts.length < 2) {
      toast(context, 'Answer at least 2 prompts.');
      return;
    }
    setState(() => saving = true);
    try {
      await Backend.updateProfile(
        name: name.text,
        city: city.text,
        intent: intent,
        prompts: prompts,
        photos: photos,
      );
      // Remove files that are no longer used.
      for (final url in widget.me.photos) {
        if (!photos.contains(url)) await Backend.deletePhotoFile(url);
      }
      if (mounted) {
        toast(context, 'Profile saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Photos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        PhotoGrid(photos: photos, onChanged: (l) => setState(() => photos = l)),
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 20),
          child: Text('Touch and hold a photo to make it your main photo.',
              style: TextStyle(color: kMuted, fontSize: 12)),
        ),
        TextField(
          controller: name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: inputDeco('First name'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: city,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: inputDeco('City'),
        ),
        const SizedBox(height: 20),
        const Text('Looking for',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SegmentedButton<LookingFor>(
          showSelectedIcon: false,
          segments: [
            for (final i in LookingFor.values)
              ButtonSegment<LookingFor>(value: i, label: Text(intentLabel(i))),
          ],
          selected: {intent},
          onSelectionChanged: (s) => setState(() => intent = s.first),
        ),
        const SizedBox(height: 24),
        const Text('Prompts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        PromptEditor(initial: prompts, onChanged: (l) => prompts = l),
      ]),
    );
  }
}

// ------------------------------------------------------------- preferences

class PreferencesScreen extends StatefulWidget {
  final AppUser me;
  final PoolController pool;
  const PreferencesScreen({super.key, required this.me, required this.pool});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late String interested = widget.me.interestedIn;
  late RangeValues age = RangeValues(
    widget.me.ageMin.clamp(18, 60).toDouble(),
    widget.me.ageMax.clamp(18, 60).toDouble(),
  );
  late bool sameCity = widget.me.sameCity;
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await Backend.updatePrefs(
        interestedIn: interested,
        ageMin: age.start.round(),
        ageMax: age.end.round() >= 60 ? 99 : age.end.round(),
        sameCity: sameCity,
      );
      final fresh = await Backend.getMe();
      if (fresh != null) widget.pool.load(fresh);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Dating preferences',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('I am interested in',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final o in interestedOptions)
            ChoiceChip(
              label: Text(interestedLabel(o)),
              selected: interested == o,
              showCheckmark: false,
              selectedColor: kInk,
              backgroundColor: Colors.white,
              side: const BorderSide(color: kLine),
              labelStyle:
                  TextStyle(color: interested == o ? Colors.white : kInk),
              onSelected: (_) => setState(() => interested = o),
            ),
        ]),
        const SizedBox(height: 24),
        Text(
            'Age range: ${age.start.round()} to ${age.end.round()}${age.end.round() >= 60 ? '+' : ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        RangeSlider(
          values: age,
          min: 18,
          max: 60,
          divisions: 42,
          activeColor: kBrand,
          labels: RangeLabels('${age.start.round()}', '${age.end.round()}'),
          onChanged: (v) => setState(() => age = v),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: sameCity,
          onChanged: (v) => setState(() => sameCity = v),
          title: const Text('Only people in my city',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(widget.me.city),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your intent (Dating, Casual or Open to both) also decides who you see. Change it in My Rizz.',
          style: TextStyle(color: kMuted, fontSize: 13),
        ),
      ]),
    );
  }
}

// -------------------------------------------------------------- block list

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  List<BlockedUser>? list;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Backend.blockedList();
      if (!mounted) return;
      setState(() {
        list = l;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = Backend.friendlyError(e));
    }
  }

  Future<void> _unblock(BlockedUser u) async {
    final ok = await confirmDialog(
      context,
      title: 'Unblock ${u.name}?',
      body: 'They may show up in Discover again.',
      confirmText: 'Unblock',
    );
    if (!ok) return;
    try {
      await Backend.unblock(u.id);
      await _load();
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = list;
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
        icon: Icons.back_hand_outlined,
        title: 'No one is blocked',
        body: 'People you block will appear here.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: l.length,
        separatorBuilder: (_, __) => const Divider(color: kLine),
        itemBuilder: (_, i) => ListTile(
          title: Text(l[i].name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: OutlinedButton(
            onPressed: () => _unblock(l[i]),
            child: const Text('Unblock'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Block list',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: body,
    );
  }
}

// ------------------------------------------------------------ safety tips

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const tips = <List<String>>[
    ['Consent comes first', 'Yes can become no at any moment. Respect it every time, and expect the same from others.'],
    ['Meet in public first', 'Choose a busy public place for the first meeting and arrange your own travel.'],
    ['Tell someone you trust', 'Share who you are meeting, where, and when. Check in after.'],
    ['Never send money', 'Do not send money, gift cards, OTPs, or bank details to anyone you met here.'],
    ['Keep personal details private', 'Wait before sharing your home address, workplace, or daily routine.'],
    ['Protect your health', 'Use protection and get tested regularly. Talk openly with partners.'],
    ['Trust your instincts', 'If something feels wrong, leave. You do not owe anyone an explanation.'],
    ['Report bad behaviour', 'Use Report on any profile or chat. Fake profiles, pressure, harassment and scams are not allowed.'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Safety tips',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in tips)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t[0],
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(t[1], style: const TextStyle(color: kMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
