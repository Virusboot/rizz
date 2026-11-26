import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

  late AppUser me;

  @override
  void initState() {
    super.initState();
    me = widget.me;
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.me != oldWidget.me) {
      setState(() => me = widget.me);
    }
  }

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
    if (fresh != null) {
      if (mounted) setState(() => me = fresh);
      widget.pool.load(fresh);
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => EditProfileScreen(me: me)),
    );
    final fresh = await Backend.getMe();
    if (fresh != null && mounted) {
      setState(() => me = fresh);
      widget.pool.load(fresh);
    }
  }

  Future<void> _openPreferences() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PreferencesScreen(me: me, pool: widget.pool),
      ),
    );
    final fresh = await Backend.getMe();
    if (fresh != null && mounted) {
      setState(() => me = fresh);
      widget.pool.load(fresh);
    }
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
    if (Backend.emailVerified || me.emailVerified) s += 10;
    return s;
  }

  List<String> _tips() {
    final t = <String>[];
    if (me.photos.length < 4) t.add('Add more photos');
    if (me.prompts.length < 3) t.add('Answer all 3 prompts');
    if (!me.verified) t.add('Get verified with a selfie');
    if (!(Backend.emailVerified || me.emailVerified)) t.add('Verify your email');
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
            const SizedBox(height: 14),
            for (final t in tips)
              InkWell(
                onTap: () {
                  if (t.contains('photos') || t.contains('prompts')) {
                    _openEditProfile();
                  } else if (t.contains('selfie')) {
                    _selfie();
                  } else if (t.contains('email')) {
                    _email();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kBrand.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: kBrand, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: kMuted, size: 18),
                    ],
                  ),
                ),
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
    if (me.verified) {
      toast(context, 'Your profile is verified with a blue badge! ✓');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const Icon(Icons.verified_user_rounded, color: kBrand, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Verify Your Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a quick selfie or upload a photo to get verified and boost your profile credibility.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kMuted),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kBrandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: kBrand),
                ),
                title: const Text(
                  'Take a Selfie (Camera)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Capture your face in good lighting'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kLine),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: kInk),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Select a clear portrait photo'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kLine),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    await _run(() async {
      final sent = await Backend.submitSelfie(source: source);
      if (sent && mounted) {
        final fresh = await Backend.getMe();
        if (!mounted) return;
        setState(() {
          me = fresh ?? me.copyWith(verified: true, verifyPending: false);
        });
        toast(context, 'Profile verified successfully! 🎉');
      }
    });
  }

  Future<void> _email() async {
    final email = Backend.userEmail ?? 'No email address registered';
    var isVerified = Backend.emailVerified || me.emailVerified;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFEBF3FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVerified
                          ? Icons.mark_email_read_rounded
                          : Icons.mail_outline_rounded,
                      color: isVerified
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1E88E5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isVerified ? 'Email Verified' : 'Verify Your Email',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: kSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVerified
                        ? 'Your email address is verified. Your account is protected and you have earned +10% profile strength.'
                        : 'We will send a verification link to your email. Click the link in your inbox, then tap "Check Status" below.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 24),
                  if (isVerified) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrand,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Send Verification Link',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        try {
                          await Backend.sendEmailVerification();
                          if (mounted) {
                            toast(context,
                                'Verification link sent to $email! Check inbox/spam.');
                          }
                        } catch (e) {
                          if (mounted) {
                            toast(context, Backend.friendlyError(e));
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: const BorderSide(color: kLine),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Check Status (I Clicked Link)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final ok = await Backend.checkEmailVerification();
                        if (ok) {
                          setModalState(() => isVerified = true);
                          setState(() {
                            me = me.copyWith(emailVerified: true);
                          });
                          if (mounted) {
                            toast(context, 'Email verified successfully! 🎉');
                          }
                        } else {
                          if (mounted) {
                            toast(context,
                                'Not verified yet. Please click the link in your email first.');
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await Backend.markEmailVerifiedDirect();
                        setModalState(() => isVerified = true);
                        setState(() {
                          me = me.copyWith(emailVerified: true);
                        });
                        if (mounted) {
                          toast(context, 'Email marked as verified! ✓');
                        }
                      },
                      child: const Text(
                        'Instant Verify (Test Mode)',
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _safety() {
    final emailOk = Backend.emailVerified || me.emailVerified;
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
        emailOk
            ? Icons.mark_email_read_rounded
            : Icons.mark_email_unread_outlined,
        emailOk ? const Color(0xFF2E7D32) : const Color(0xFF5B8DEF),
        'Email verification',
        emailOk
            ? 'Your email is verified.'
            : (Backend.userEmail != null
                ? 'Verify ${Backend.userEmail}'
                : 'Tap to send a verification link.'),
        onTap: _email,
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('India 24/7 Helplines',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          _helplineRow('Emergency Services', '112'),
          const Divider(color: kLine, height: 16),
          _helplineRow('Women Safety Helpline', '181'),
          const Divider(color: kLine, height: 16),
          _helplineRow('Tele-MANAS Mental Health', '14416'),
        ]),
      ),
    ]);
  }

  Widget _helplineRow(String title, String number) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(number, style: const TextStyle(color: kBrand, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: kBrand,
            side: BorderSide(color: kBrand.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.copy_rounded, size: 14),
          label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: number));
            toast(context, 'Copied $number to clipboard');
          },
        ),
      ],
    );
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
      messenger
          .showSnackBar(SnackBar(content: Text(Backend.friendlyError(e))));
    }
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        if (copyable) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              toast(context, 'Copied $label');
            },
            child: const Icon(Icons.copy_rounded, size: 16, color: kBrand),
          ),
        ],
      ],
    );
  }

  void _showAccountInfo() {
    final email = Backend.userEmail ?? 'Not specified';
    final created = me.createdAt != null
        ? '${me.createdAt!.day}/${me.createdAt!.month}/${me.createdAt!.year}'
        : 'Active';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Details',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Email', email),
            const SizedBox(height: 10),
            _infoRow('Email Status',
                (Backend.emailVerified || me.emailVerified) ? 'Verified ✓' : 'Unverified'),
            const SizedBox(height: 10),
            _infoRow('Profile Badge', me.verified ? 'Verified ✓' : 'Standard'),
            const SizedBox(height: 10),
            _infoRow('Member Since', created),
            const SizedBox(height: 10),
            _infoRow('Account ID', me.uid, copyable: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(String title, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Official documentation and $title are published live:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                    color: kBrand, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              toast(context, 'Link copied to clipboard');
              Navigator.pop(ctx);
            },
            child: const Text('Copy Link'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
        onTap: _openEditProfile,
      ),
      _tile(
        Icons.tune,
        kInk,
        'Dating preferences',
        'Who you want to see',
        onTap: _openPreferences,
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
      _tile(
        Icons.account_circle_outlined,
        const Color(0xFF4A6572),
        'Account Details',
        Backend.auth.currentUser?.email ?? 'View your account details',
        onTap: _showAccountInfo,
      ),
      _tile(
        Icons.privacy_tip_outlined,
        const Color(0xFF34495E),
        'Privacy Policy',
        'How your data is protected',
        onTap: () => _showLegalDialog(
            'Privacy Policy', 'https://virusboot.github.io/rizz/privacy_policy.html'),
      ),
      _tile(
        Icons.description_outlined,
        const Color(0xFF5D6D7E),
        'Terms of Service',
        'User agreement and policies',
        onTap: () => _showLegalDialog(
            'Terms of Service', 'https://virusboot.github.io/rizz/terms_of_service.html'),
      ),
      _tile(
        Icons.shield_outlined,
        const Color(0xFF2C3E50),
        'Child Safety Standards',
        'Zero tolerance standards against CSAE',
        onTap: () => _showLegalDialog(
            'Child Safety Standards', 'https://virusboot.github.io/rizz/child_safety.html'),
      ),
      _tile(Icons.logout, kMuted, 'Sign out',
          Backend.auth.currentUser?.email ?? '',
          onTap: _signOut),
      _tile(Icons.delete_outline, Colors.red, 'Delete account',
          'Permanently remove all your data',
          onTap: _deleteAccount),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'HookIn v1.0.0 (Build 3)\nMade with ❤️ by KV Studio',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 12),
      // Avatar with edit button badge
      Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [kBrand, kBrandOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kBrand.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Avatar(url: me.mainPhoto, radius: 52),
          ),
          GestureDetector(
            onTap: _openEditProfile,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: kLine, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit_rounded, size: 16, color: kBrand),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // Name, Age and Verification Badge
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${me.name}, ${me.age}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _selfie,
            child: Tooltip(
              message: me.verified ? 'Verified Profile' : 'Tap to verify',
              child: Icon(
                Icons.verified,
                color: me.verified ? kBrand : kLine,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      if (me.city.isNotEmpty) ...[
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: kMuted),
            const SizedBox(width: 3),
            Text(me.city,
                style: const TextStyle(
                    fontSize: 13, color: kMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
      const SizedBox(height: 12),
      // Action buttons: "Edit Profile" & "Preferences"
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kInk,
                  side: const BorderSide(color: kLine),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit profile',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: _openEditProfile,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kInk,
                  side: const BorderSide(color: kLine),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Preferences',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: _openPreferences,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
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
        name: name.text.trim(),
        city: city.text.trim(),
        intent: intent,
        prompts: prompts,
        photos: photos,
      );
      // Remove files that are no longer used.
      for (final url in widget.me.photos) {
        if (!photos.contains(url)) await Backend.deletePhotoFile(url);
      }
      if (mounted) {
        toast(context, 'Profile saved successfully! ✨');
        Navigator.pop(context, true);
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
      if (mounted) {
        toast(context, 'Preferences updated! ✨');
        Navigator.pop(context, true);
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
          'Your intent (Dating, Casual or Open to both) also decides who you see. Change it in My Hookin.',
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
