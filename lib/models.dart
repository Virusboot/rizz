import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

enum LookingFor { dating, casual, both }

LookingFor intentFrom(String? s) {
  for (final i in LookingFor.values) {
    if (i.name == s) return i;
  }
  return LookingFor.both;
}

String intentLabel(LookingFor i) {
  switch (i) {
    case LookingFor.dating:
      return 'Dating';
    case LookingFor.casual:
      return 'Casual';
    case LookingFor.both:
      return 'Open to both';
  }
}

/// People only see each other when their intents are compatible.
bool intentCompatible(LookingFor a, LookingFor b) =>
    a == LookingFor.both || b == LookingFor.both || a == b;

const genders = ['man', 'woman', 'nonbinary'];
const interestedOptions = ['men', 'women', 'everyone'];

String genderLabel(String g) {
  switch (g) {
    case 'man':
      return 'Man';
    case 'woman':
      return 'Woman';
    case 'nonbinary':
      return 'Non-binary';
  }
  return g;
}

String interestedLabel(String g) {
  switch (g) {
    case 'men':
      return 'Men';
    case 'women':
      return 'Women';
    case 'everyone':
      return 'Everyone';
  }
  return g;
}

/// Does someone interested in [interestedIn] want a person of [gender]?
bool wants(String interestedIn, String gender) {
  if (interestedIn == 'everyone') return true;
  if (interestedIn == 'men') return gender == 'man';
  if (interestedIn == 'women') return gender == 'woman';
  return false;
}

int ageFrom(DateTime dob) {
  final n = DateTime.now();
  var a = n.year - dob.year;
  if (n.month < dob.month || (n.month == dob.month && n.day < dob.day)) a--;
  return a;
}

const promptQuestions = <String>[
  'A perfect night looks like',
  'I am weirdly good at',
  'We will get along if',
  'Typical Sunday',
  'Green flag I look for',
  'Unpopular opinion',
  'The way to win me over is',
  'I am looking for',
  'My simple pleasure',
  'Dating me is like',
  'I get way too excited about',
  'Two truths and a lie',
];

class Prompt {
  final String q;
  final String a;
  const Prompt(this.q, this.a);

  Json toMap() => {'q': q, 'a': a};

  factory Prompt.fromMap(Json m) =>
      Prompt((m['q'] ?? '') as String, (m['a'] ?? '') as String);
}

class AppUser {
  final String uid;
  final String name;
  final int age;
  final String gender;
  final String interestedIn;
  final LookingFor intent;
  final String city;
  final List<Prompt> prompts;
  final List<String> photos;
  final bool verified;
  final bool verifyPending;
  final bool paused;
  final bool notify;
  final bool onboarded;
  final int ageMin;
  final int ageMax;
  final bool sameCity;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final DateTime? lastSparkAt;
  final DateTime? boostUntil;
  final DateTime? lastBoostAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.intent,
    required this.city,
    required this.prompts,
    required this.photos,
    required this.verified,
    required this.verifyPending,
    required this.paused,
    required this.notify,
    required this.onboarded,
    required this.ageMin,
    required this.ageMax,
    required this.sameCity,
    this.createdAt,
    this.lastActive,
    this.lastSparkAt,
    this.boostUntil,
    this.lastBoostAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? <String, dynamic>{};
    final rawPrompts = (m['prompts'] ?? <dynamic>[]) as List;
    return AppUser(
      uid: d.id,
      name: (m['name'] ?? '') as String,
      age: (m['age'] ?? 18) as int,
      gender: (m['gender'] ?? 'man') as String,
      interestedIn: (m['interestedIn'] ?? 'everyone') as String,
      intent: intentFrom(m['intent'] as String?),
      city: (m['city'] ?? '') as String,
      prompts: rawPrompts
          .map((e) => Prompt.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      photos: List<String>.from((m['photos'] ?? <dynamic>[]) as List),
      verified: (m['verified'] ?? false) as bool,
      verifyPending: (m['verifyPending'] ?? false) as bool,
      paused: (m['paused'] ?? false) as bool,
      notify: (m['notify'] ?? true) as bool,
      onboarded: (m['onboarded'] ?? false) as bool,
      ageMin: (m['ageMin'] ?? 18) as int,
      ageMax: (m['ageMax'] ?? 45) as int,
      sameCity: (m['sameCity'] ?? false) as bool,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (m['lastActive'] as Timestamp?)?.toDate(),
      lastSparkAt: (m['lastSparkAt'] as Timestamp?)?.toDate(),
      boostUntil: (m['boostUntil'] as Timestamp?)?.toDate(),
      lastBoostAt: (m['lastBoostAt'] as Timestamp?)?.toDate(),
    );
  }

  String? get mainPhoto => photos.isEmpty ? null : photos.first;

  /// One free Spark every 7 days.
  bool get canSpark {
    final t = lastSparkAt;
    return t == null || DateTime.now().difference(t).inDays >= 7;
  }

  int get sparkDaysLeft {
    final t = lastSparkAt;
    if (t == null) return 0;
    final left = 7 - DateTime.now().difference(t).inDays;
    return left < 0 ? 0 : left;
  }

  bool get boosted {
    final t = boostUntil;
    return t != null && t.isAfter(DateTime.now());
  }

  /// One free Boost every 24 hours.
  bool get canBoost {
    final t = lastBoostAt;
    return t == null || DateTime.now().difference(t).inHours >= 24;
  }

  int get boostHoursLeft {
    final t = lastBoostAt;
    if (t == null) return 0;
    final left = 24 - DateTime.now().difference(t).inHours;
    return left < 0 ? 0 : left;
  }

  AppUser copyWith({
    String? name,
    int? age,
    String? gender,
    String? interestedIn,
    LookingFor? intent,
    String? city,
    List<Prompt>? prompts,
    List<String>? photos,
    bool? verified,
    bool? verifyPending,
    bool? paused,
    bool? notify,
    bool? onboarded,
    int? ageMin,
    int? ageMax,
    bool? sameCity,
    DateTime? createdAt,
    DateTime? lastActive,
    DateTime? lastSparkAt,
    DateTime? boostUntil,
    DateTime? lastBoostAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      intent: intent ?? this.intent,
      city: city ?? this.city,
      prompts: prompts ?? this.prompts,
      photos: photos ?? this.photos,
      verified: verified ?? this.verified,
      verifyPending: verifyPending ?? this.verifyPending,
      paused: paused ?? this.paused,
      notify: notify ?? this.notify,
      onboarded: onboarded ?? this.onboarded,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      sameCity: sameCity ?? this.sameCity,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      lastSparkAt: lastSparkAt ?? this.lastSparkAt,
      boostUntil: boostUntil ?? this.boostUntil,
      lastBoostAt: lastBoostAt ?? this.lastBoostAt,
    );
  }
}

class ChatMsg {
  final String id;
  final String sender;
  final String text;
  final DateTime? at;
  const ChatMsg(this.id, this.sender, this.text, this.at);

  factory ChatMsg.fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? <String, dynamic>{};
    return ChatMsg(
      d.id,
      (m['sender'] ?? '') as String,
      (m['text'] ?? '') as String,
      (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MatchItem {
  final String id;
  final List<String> users;
  final Json info;
  final String lastMessage;
  final String lastSender;
  final DateTime? lastAt;

  const MatchItem({
    required this.id,
    required this.users,
    required this.info,
    required this.lastMessage,
    required this.lastSender,
    this.lastAt,
  });

  factory MatchItem.fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? <String, dynamic>{};
    return MatchItem(
      id: d.id,
      users: List<String>.from((m['users'] ?? <dynamic>[]) as List),
      info: Map<String, dynamic>.from((m['info'] ?? <String, dynamic>{}) as Map),
      lastMessage: (m['lastMessage'] ?? '') as String,
      lastSender: (m['lastSender'] ?? '') as String,
      lastAt: (m['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  String otherId(String me) =>
      users.firstWhere((u) => u != me, orElse: () => me);

  Json _infoFor(String me) {
    final o = info[otherId(me)];
    return o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
  }

  String otherName(String me) => (_infoFor(me)['name'] ?? 'Match') as String;

  String? otherPhoto(String me) {
    final p = _infoFor(me)['photo'];
    return (p is String && p.isNotEmpty) ? p : null;
  }
}

class BlockedUser {
  final String id;
  final String name;
  const BlockedUser(this.id, this.name);
}

class LikeItem {
  final AppUser user;
  final bool spark;
  final DateTime? at;
  const LikeItem(this.user, this.spark, this.at);
}
