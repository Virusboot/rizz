import 'package:flutter/material.dart';

import 'backend.dart';
import 'models.dart';
import 'theme.dart';

// ------------------------------------------------------------------ helpers

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmText = 'Confirm',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText,
              style: TextStyle(color: danger ? Colors.red : kBrand)),
        ),
      ],
    ),
  );
  return r == true;
}

// -------------------------------------------------------------------- logo

class HookinLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  HookinLogoPainter({
    this.primaryColor = kBrand,
    this.secondaryColor = kBrandOrange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, secondaryColor],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Left hook
    final leftHook = Path();
    leftHook.moveTo(w * 0.44, h * 0.38);
    leftHook.cubicTo(w * 0.44, h * 0.22, w * 0.36, h * 0.12, w * 0.24, h * 0.12);
    leftHook.cubicTo(w * 0.08, h * 0.12, w * 0.05, h * 0.36, w * 0.18, h * 0.54);
    leftHook.cubicTo(w * 0.28, h * 0.68, w * 0.42, h * 0.80, w * 0.50, h * 0.88);
    canvas.drawPath(leftHook, paint);

    // Right hook interlocking
    final rightHook = Path();
    rightHook.moveTo(w * 0.56, h * 0.38);
    rightHook.cubicTo(w * 0.56, h * 0.22, w * 0.64, h * 0.12, w * 0.76, h * 0.12);
    rightHook.cubicTo(w * 0.92, h * 0.12, w * 0.95, h * 0.36, w * 0.82, h * 0.54);
    rightHook.cubicTo(w * 0.72, h * 0.68, w * 0.58, h * 0.80, w * 0.50, h * 0.88);
    canvas.drawPath(rightHook, paint);
  }

  @override
  bool shouldRepaint(covariant HookinLogoPainter old) =>
      old.primaryColor != primaryColor || old.secondaryColor != secondaryColor;
}

class HookinLogo extends StatelessWidget {
  final double size;
  final bool withName;
  const HookinLogo({super.key, this.size = 32, this.withName = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: HookinLogoPainter(),
        ),
        if (withName) ...[
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.88,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
              children: const [
                TextSpan(
                  text: 'hook',
                  style: TextStyle(color: kInk),
                ),
                TextSpan(
                  text: 'in',
                  style: TextStyle(color: kBrand),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

typedef RizzLogo = HookinLogo;
typedef RizzLogoPainter = HookinLogoPainter;

// ------------------------------------------------------------------ images

class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const NetImage({super.key, this.url, this.fit = BoxFit.cover});

  Widget _placeholder() => Container(
        color: kSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.person, color: kMuted, size: 36),
      );

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _placeholder();
    return Image.network(
      u,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: kSoft,
          alignment: Alignment.center,
          child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  const Avatar({super.key, this.url, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(child: NetImage(url: url)),
    );
  }
}

// ------------------------------------------------------------ small blocks

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onCta;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.cta,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            decoration:
                const BoxDecoration(color: kSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 52, color: kBrand),
          ),
          const SizedBox(height: 24),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 15)),
          if (cta != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kInk,
                  minimumSize: const Size(220, 50),
                  shape: const StadiumBorder()),
              onPressed: onCta,
              child: Text(cta!),
            ),
          ],
        ]),
      ),
    );
  }
}

Widget screenTitle(String t, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(children: [
        Text(t,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (trailing != null) trailing,
      ]),
    );

class LikeButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const LikeButton({super.key, required this.onTap, this.icon = Icons.favorite});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: kLine)),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: kBrand),
        ),
      ),
    );
  }
}

class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final double elevation;

  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
    this.elevation = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      shape: const CircleBorder(side: BorderSide(color: kLine)),
      elevation: elevation,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, size: 26, color: iconColor ?? kInk),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- photo grid

class PhotoGrid extends StatefulWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int max;
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onChanged,
    this.max = 6,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  bool uploading = false;

  Future<void> _add() async {
    if (uploading) return;
    setState(() => uploading = true);
    try {
      final url = await Backend.pickAndUploadPhoto();
      if (url != null) widget.onChanged([...widget.photos, url]);
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => uploading = false);
  }

  void _remove(int i) {
    final l = [...widget.photos]..removeAt(i);
    widget.onChanged(l);
  }

  void _makeMain(int i) {
    if (i == 0) return;
    final l = [...widget.photos];
    final p = l.removeAt(i);
    l.insert(0, p);
    widget.onChanged(l);
    toast(context, 'Set as your main photo');
  }

  Widget _photoTile(int i) {
    return GestureDetector(
      onLongPress: () => _makeMain(i),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          NetImage(url: widget.photos[i]),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _remove(i),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
          if (i == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Main',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _addTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _add,
      child: Container(
        decoration: BoxDecoration(
          color: kSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine),
        ),
        alignment: Alignment.center,
        child: uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add, size: 32, color: kBrand),
      ),
    );
  }

  Widget _emptyTile() => Container(
        decoration: BoxDecoration(
          color: kSoft,
          borderRadius: BorderRadius.circular(14),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.78,
      children: List.generate(widget.max, (i) {
        if (i < widget.photos.length) return _photoTile(i);
        if (i == widget.photos.length) return _addTile();
        return _emptyTile();
      }),
    );
  }
}

// ----------------------------------------------------------- prompt editor

class PromptEditor extends StatefulWidget {
  final List<Prompt> initial;
  final ValueChanged<List<Prompt>> onChanged;
  final int count;
  const PromptEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.count = 3,
  });

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  late final List<String> qs;
  late final List<TextEditingController> ctrls;

  @override
  void initState() {
    super.initState();
    qs = List.generate(widget.count, (i) {
      if (i < widget.initial.length &&
          promptQuestions.contains(widget.initial[i].q)) {
        return widget.initial[i].q;
      }
      return promptQuestions[i % promptQuestions.length];
    });
    ctrls = List.generate(
      widget.count,
      (i) => TextEditingController(
          text: i < widget.initial.length ? widget.initial[i].a : ''),
    );
  }

  @override
  void dispose() {
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (var i = 0; i < qs.length; i++)
        if (ctrls[i].text.trim().isNotEmpty) Prompt(qs[i], ctrls[i].text.trim()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < qs.length; i++) ...[
          DropdownButtonFormField<String>(
            initialValue: qs[i],
            isExpanded: true,
            decoration: inputDeco('Prompt ${i + 1}'),
            items: promptQuestions
                .map((q) => DropdownMenuItem<String>(
                    value: q, child: Text(q, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => qs[i] = v);
              _emit();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrls[i],
            maxLength: 140,
            maxLines: 2,
            minLines: 1,
            decoration: inputDeco('Your answer'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ profile view

class ProfileBody extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLike;
  const ProfileBody({super.key, required this.user, required this.onLike});

  Widget _photo(String url) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              NetImage(url: url),
              Positioned(
                  right: 12, bottom: 12, child: LikeButton(onTap: onLike)),
            ]),
          ),
        ),
      );

  Widget _prompt(Prompt p) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLine),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.q, style: const TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 6),
                Text(p.a,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
              ],
            ),
          ),
          LikeButton(onTap: onLike),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final n = user.photos.length > user.prompts.length
        ? user.photos.length
        : user.prompts.length;
    final children = <Widget>[
      Row(children: [
        Flexible(
          child: Text(user.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Text('${user.age}',
            style: const TextStyle(fontSize: 20, color: kMuted)),
        if (user.verified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, color: kBrand, size: 22),
        ],
      ]),
      const SizedBox(height: 2),
      Text('${user.city}  •  ${intentLabel(user.intent)}',
          style: const TextStyle(color: kMuted)),
      const SizedBox(height: 12),
    ];
    for (var i = 0; i < n; i++) {
      if (i < user.photos.length) children.add(_photo(user.photos[i]));
      if (i < user.prompts.length) children.add(_prompt(user.prompts[i]));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// Full-screen profile with Pass / Like buttons. Used from Likes and Sparks.
class ProfileDetailScreen extends StatelessWidget {
  final AppUser user;
  final String likeLabel;
  final Future<void> Function() onLike;
  final Future<void> Function() onPass;
  final VoidCallback onRemoved;

  const ProfileDetailScreen({
    super.key,
    required this.user,
    required this.onLike,
    required this.onPass,
    required this.onRemoved,
    this.likeLabel = 'Like',
  });

  Future<void> _act(BuildContext context, Future<void> Function() f) async {
    // Close this screen first so any follow-up dialog or chat opens on the
    // screen underneath.
    Navigator.pop(context);
    await f();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () async {
              final done = await showSafetySheet(context,
                  otherId: user.uid, otherName: user.name);
              if (done) {
                onRemoved();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ProfileBody(user: user, onLike: () => _act(context, onLike)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                  foregroundColor: kInk,
                ),
                onPressed: () => _act(context, onPass),
                child: const Text('Pass'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                  backgroundColor: kBrand,
                ),
                onPressed: () => _act(context, onLike),
                child: Text(likeLabel),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ safety sheet

const reportReasons = <String>[
  'Fake profile or spam',
  'Inappropriate photos or messages',
  'Harassment or hate',
  'Seems underage',
  'Scam or asking for money',
  'Other',
];

/// Block / report flow. Returns true if the person should disappear from the
/// current screen (blocked or reported).
Future<bool> showSafetySheet(
  BuildContext context, {
  required String otherId,
  required String otherName,
  String? matchId,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.block),
          title: Text('Block $otherName'),
          subtitle: const Text('You will not see each other again.'),
          onTap: () => Navigator.pop(ctx, 'block'),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text('Report $otherName'),
          subtitle: const Text('We review every report. They are blocked too.'),
          onTap: () => Navigator.pop(ctx, 'report'),
        ),
      ]),
    ),
  );
  if (action == null || !context.mounted) return false;

  try {
    if (action == 'block') {
      final ok = await confirmDialog(
        context,
        title: 'Block $otherName?',
        body: 'Your chat with them will be deleted.',
        confirmText: 'Block',
        danger: true,
      );
      if (!ok) return false;
      await Backend.block(otherId);
      if (context.mounted) toast(context, '$otherName is blocked');
      return true;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('What is the problem?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final r in reportReasons)
            ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
        ]),
      ),
    );
    if (reason == null) return false;
    await Backend.report(otherId, reason, matchId: matchId);
    await Backend.block(otherId);
    if (context.mounted) {
      toast(context, 'Thanks. We will review your report.');
    }
    return true;
  } catch (e) {
    if (context.mounted) toast(context, Backend.friendlyError(e));
    return false;
  }
}
