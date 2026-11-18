import 'package:flutter/material.dart';

import 'backend.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const lastStep = 3;

  int step = 0;
  bool saving = false;

  final name = TextEditingController();
  final city = TextEditingController();
  DateTime? dob;
  String? gender;
  String? interested;
  LookingFor? intent;
  List<String> photos = [];
  List<Prompt> prompts = [];

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  String? _check(int s) {
    switch (s) {
      case 0:
        if (name.text.trim().length < 2) return 'Enter your first name.';
        if (dob == null) return 'Select your date of birth.';
        if (ageFrom(dob!) < 18) return 'You must be 18 or older.';
        if (gender == null) return 'Select your gender.';
        if (interested == null) return 'Select who you want to meet.';
        return null;
      case 1:
        if (intent == null) return 'Choose what you are looking for.';
        if (city.text.trim().length < 2) return 'Enter your city.';
        return null;
      case 2:
        return null;
      default:
        return null;
    }
  }

  Future<void> _next() async {
    final err = _check(step);
    if (err != null) {
      toast(context, err);
      return;
    }
    if (step < lastStep) {
      setState(() => step++);
      return;
    }
    setState(() => saving = true);
    try {
      final finalPhotos = photos.isNotEmpty
          ? photos
          : [
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
            ];
      final finalPrompts = prompts.length >= 2
          ? prompts
          : [
              Prompt('A random fact I love', 'Coffee was discovered by goats'),
              Prompt('Typical Sunday', 'Chilling and listening to music'),
            ];

      await Backend.createProfile(
        name: name.text,
        dob: dob!,
        gender: gender!,
        interestedIn: interested!,
        intent: intent!,
        city: city.text,
        prompts: finalPrompts,
        photos: finalPhotos,
      );
      // AuthGate switches to the app automatically.
    } catch (e) {
      if (mounted) toast(context, Backend.friendlyError(e));
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: dob ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Your date of birth',
    );
    if (d != null) setState(() => dob = d);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _title(String t, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: kMuted, fontSize: 15)),
          const SizedBox(height: 20),
        ],
      );

  Widget _chips(
      List<String> values, String? selected, String Function(String) label,
      ValueChanged<String> onPick) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: selected == v,
          showCheckmark: false,
          selectedColor: kInk,
          backgroundColor: Colors.white,
          side: const BorderSide(color: kLine),
          labelStyle: TextStyle(color: selected == v ? Colors.white : kInk),
          onSelected: (_) => onPick(v),
        ),
    ]);
  }

  Widget _step0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('The basics', 'Tell us a little about you.'),
      TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        maxLength: 30,
        decoration: inputDeco('First name'),
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: inputDeco('Date of birth'),
          child: Text(dob == null ? 'Select' : _fmt(dob!),
              style: TextStyle(color: dob == null ? kMuted : kInk)),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6, bottom: 20),
        child: Text(
            'Hookin is for adults only (18+). Others see your age, never your birthday.',
            style: TextStyle(color: kMuted, fontSize: 12)),
      ),
      const Text('I am', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _chips(genders, gender, genderLabel, (v) => setState(() => gender = v)),
      const SizedBox(height: 20),
      const Text('I want to meet',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _chips(interestedOptions, interested, interestedLabel,
          (v) => setState(() => interested = v)),
    ]);
  }

  Widget _intentTile(LookingFor i, String desc) {
    final sel = intent == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => intent = i),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? kInk : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? kInk : kLine),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(intentLabel(i),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : kInk)),
            const SizedBox(height: 4),
            Text(desc,
                style: TextStyle(color: sel ? Colors.white70 : kMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _step1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('What are you looking for?',
          'Be upfront. You will only see people whose intentions fit yours.'),
      _intentTile(LookingFor.dating, 'Something real, with someone who wants the same.'),
      _intentTile(LookingFor.casual, 'Fun and no pressure, clear and honest from the start.'),
      _intentTile(LookingFor.both, 'Open to see where it goes.'),
      const SizedBox(height: 12),
      TextField(
        controller: city,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: inputDeco('Your city', hint: 'Noida'),
      ),
    ]);
  }

  Widget _step2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Add your photos',
          'Optional for now. You can continue without photos or tap below for demo photos.'),
      PhotoGrid(
        photos: photos,
        onChanged: (l) => setState(() => photos = l),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: const Icon(Icons.auto_awesome, color: kBrand, size: 18),
        label: const Text('Add demo photos', style: TextStyle(color: kBrand)),
        onPressed: () => setState(() => photos = [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
        ]),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text('Touch and hold a photo to make it your main photo.',
            style: TextStyle(color: kMuted, fontSize: 12)),
      ),
    ]);
  }

  Widget _step3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Show your personality', 'Answer at least 2 prompts.'),
      PromptEditor(
        initial: prompts,
        onChanged: (l) => prompts = l,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_step0, _step1, _step2, _step3];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              SizedBox(
                width: 80,
                child: step > 0
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: saving ? null : () => setState(() => step--),
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              const RizzLogo(size: 24),
              const Spacer(),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: saving ? null : Backend.signOut,
                    child: const Text('Sign out'),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (step + 1) / (lastStep + 1),
                minHeight: 5,
                color: kBrand,
                backgroundColor: kSoft,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: steps[step](),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kBrand,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: saving ? null : _next,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(step == lastStep ? 'Finish' : 'Continue'),
            ),
          ),
        ]),
      ),
    );
  }
}
