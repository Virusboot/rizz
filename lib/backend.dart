import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

/// All Firebase calls live here so the UI stays simple.
class Backend {
  Backend._();

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  static String get uid => auth.currentUser!.uid;

  /// True while an account is being deleted, so the UI does not flash the
  /// onboarding screen when the profile document disappears.
  static final ValueNotifier<bool> deleting = ValueNotifier<bool>(false);

  /// Id of the chat that is open on screen, so its pushes are not shown.
  static String? openChatId;

  static CollectionReference<Json> get users => db.collection('users');
  static CollectionReference<Json> get likes => db.collection('likes');
  static CollectionReference<Json> get matches => db.collection('matches');
  static CollectionReference<Json> get blocks => db.collection('blocks');

  static DocumentReference<Json> userRef(String id) => users.doc(id);

  static String matchIdFor(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ---------------------------------------------------------------- errors

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Try signing in.';
        case 'weak-password':
          return 'Choose a stronger password (at least 8 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a bit and try again.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'requires-recent-login':
          return 'Please sign in again and retry.';
      }
      return e.message ?? 'Something went wrong.';
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'You do not have permission to do that.';
      }
      if (e.code == 'unavailable') return 'No internet connection.';
      return e.message ?? 'Something went wrong.';
    }
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  // ------------------------------------------------------------------ auth

  static Future<void> signUp(String email, String password) async {
    final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {}
  }

  static Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  static Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> signOut() async {
    // Stop pushes for this account on this phone.
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null && auth.currentUser != null) {
        await userRef(uid).collection('tokens').doc(t).delete();
      }
    } catch (_) {}
    await auth.signOut();
  }

  /// Returns true if the email is verified, otherwise re-sends the link.
  static Future<bool> checkOrSendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = auth.currentUser;
    if (fresh != null && fresh.emailVerified) return true;
    await fresh?.sendEmailVerification();
    return false;
  }

  static bool get emailVerified => auth.currentUser?.emailVerified ?? false;

  // --------------------------------------------------------------- profile

  static Future<AppUser?> getMe() async {
    final d = await userRef(uid).get();
    if (!d.exists) return null;
    return AppUser.fromDoc(d);
  }

  static Future<void> createProfile({
    required String name,
    required DateTime dob,
    required String gender,
    required String interestedIn,
    required LookingFor intent,
    required String city,
    required List<Prompt> prompts,
    required List<String> photos,
  }) async {
    final age = ageFrom(dob);
    if (age < 18) throw Exception('You must be 18 or older to use Rizz.');
    final batch = db.batch();
    batch.set(userRef(uid), {
      'name': name.trim(),
      'age': age,
      'gender': gender,
      'interestedIn': interestedIn,
      'intent': intent.name,
      'city': city.trim(),
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'photos': photos,
      'verified': false,
      'verifyPending': false,
      'paused': false,
      'onboarded': true,
      'ageMin': max(18, age - 8),
      'ageMax': min(99, age + 12),
      'sameCity': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'lastSparkAt': null,
      'boostUntil': null,
      'lastBoostAt': null,
    });
    // Date of birth is private. Others only see the age.
    batch.set(userRef(uid).collection('private').doc('info'),
        {'dob': Timestamp.fromDate(dob)});
    await batch.commit();
  }

  static Future<void> updateProfile({
    required String name,
    required String city,
    required LookingFor intent,
    required List<Prompt> prompts,
    required List<String> photos,
  }) {
    return userRef(uid).update({
      'name': name.trim(),
      'city': city.trim(),
      'intent': intent.name,
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'photos': photos,
    });
  }

  static Future<void> setIntent(LookingFor i) =>
      userRef(uid).update({'intent': i.name});

  static Future<void> updatePrefs({
    required String interestedIn,
    required int ageMin,
    required int ageMax,
    required bool sameCity,
  }) {
    return userRef(uid).update({
      'interestedIn': interestedIn,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'sameCity': sameCity,
    });
  }

  static Future<void> setPaused(bool v) =>
      userRef(uid).update({'paused': v});

  static Future<void> setNotifications(bool v) =>
      userRef(uid).update({'notify': v});

  /// Called once per app open: refreshes lastActive and keeps age current.
  static Future<void> onAppOpen(AppUser me) async {
    final updates = <String, dynamic>{
      'lastActive': FieldValue.serverTimestamp(),
    };
    try {
      final p = await userRef(me.uid).collection('private').doc('info').get();
      final ts = p.data()?['dob'];
      if (ts is Timestamp) {
        final age = ageFrom(ts.toDate());
        if (age != me.age && age >= 18) updates['age'] = age;
      }
    } catch (_) {}
    try {
      await userRef(me.uid).update(updates);
    } catch (_) {}
  }

  static Future<void> boost() {
    return userRef(uid).update({
      'boostUntil':
          Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
      'lastBoostAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------- photos

  static Future<String?> pickAndUploadPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1440,
      imageQuality: 82,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final ref = storage
        .ref('photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<void> deletePhotoFile(String url) async {
    try {
      await storage.refFromURL(url).delete();
    } catch (_) {}
  }

  /// Takes a selfie and files it for manual review.
  /// A team member approves it by setting `verified: true` in the console.
  static Future<bool> submitSelfie() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (x == null) return false;
    final bytes = await x.readAsBytes();
    await storage
        .ref('verifications/$uid/selfie.jpg')
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    await userRef(uid).update({'verifyPending': true});
    return true;
  }

  // ------------------------------------------------------------- discovery

  /// People I have blocked. Blocked people cannot look up who blocked them;
  /// the database rules simply refuse their likes.
  static Future<Set<String>> _blockedIds() async {
    final s = await blocks.where('blocker', isEqualTo: uid).get();
    return s.docs.map((d) => d.data()['blocked'] as String).toSet();
  }

  static Future<Set<String>> _likedIds() async {
    final s = await likes.where('from', isEqualTo: uid).get();
    return s.docs.map((d) => d.data()['to'] as String).toSet();
  }

  static Future<Set<String>> _passedIds() async {
    final s = await userRef(uid).collection('passes').get();
    return s.docs.map((d) => d.id).toSet();
  }

  static bool _sameCity(AppUser a, AppUser b) =>
      a.city.trim().toLowerCase() == b.city.trim().toLowerCase();

  static bool _eligible(AppUser me, AppUser u) {
    if (u.photos.isEmpty) return false;
    if (!wants(me.interestedIn, u.gender)) return false;
    if (!wants(u.interestedIn, me.gender)) return false;
    if (u.age < me.ageMin || u.age > me.ageMax) return false;
    if (me.age < u.ageMin || me.age > u.ageMax) return false;
    if (!intentCompatible(me.intent, u.intent)) return false;
    if ((me.sameCity || u.sameCity) && !_sameCity(me, u)) return false;
    return true;
  }

  static double _score(AppUser me, AppUser u) {
    var s = 0.0;
    if (u.verified) s += 3;
    if (_sameCity(me, u)) s += 2;
    if (u.boosted) s += 6;
    final now = DateTime.now();
    final la = u.lastActive;
    if (la != null && now.difference(la).inDays < 3) s += 1.5;
    final ca = u.createdAt;
    if (ca != null && now.difference(ca).inDays < 7) s += 1;
    s += min(u.photos.length, 4) * 0.25;
    s += min(u.prompts.length, 3) * 0.25;
    return s;
  }

  /// People who match my preferences and I have not liked, passed or blocked.
  static Future<List<AppUser>> candidates(AppUser me) async {
    final sets = await Future.wait<Set<String>>(
        [_blockedIds(), _likedIds(), _passedIds()]);
    final exclude = <String>{me.uid, ...sets[0], ...sets[1], ...sets[2]};

    Query<Json> q = users
        .where('onboarded', isEqualTo: true)
        .where('paused', isEqualTo: false);
    if (me.interestedIn == 'men') {
      q = q.where('gender', isEqualTo: 'man');
    } else if (me.interestedIn == 'women') {
      q = q.where('gender', isEqualTo: 'woman');
    }
    // Newest first, in pages. Keep paging until there are enough people.
    q = q.orderBy('createdAt', descending: true);

    final rnd = Random();
    final scored = <MapEntry<AppUser, double>>[];
    DocumentSnapshot<Json>? cursor;
    for (var page = 0; page < 5; page++) {
      var pq = q.limit(300);
      if (cursor != null) pq = pq.startAfterDocument(cursor);
      final snap = await pq.get();
      for (final d in snap.docs) {
        if (exclude.contains(d.id)) continue;
        final u = AppUser.fromDoc(d);
        if (!_eligible(me, u)) continue;
        scored.add(MapEntry(u, _score(me, u) + rnd.nextDouble() * 2));
      }
      if (snap.docs.length < 300 || scored.length >= 100) break;
      cursor = snap.docs.last;
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  static Future<AppUser?> _safeUser(String id) async {
    try {
      final d = await userRef(id).get();
      if (!d.exists) return null;
      final u = AppUser.fromDoc(d);
      return u.onboarded ? u : null;
    } catch (_) {
      return null;
    }
  }

  /// People who liked me and I have not answered yet.
  static Future<List<LikeItem>> likesReceived() async {
    final snap = await likes.where('to', isEqualTo: uid).get();
    final sets = await Future.wait<Set<String>>(
        [_blockedIds(), _likedIds(), _passedIds()]);
    final exclude = <String>{...sets[0], ...sets[1], ...sets[2]};

    final docs = snap.docs
        .where((d) => !exclude.contains(d.data()['from'] as String))
        .toList();
    docs.sort((a, b) {
      final sa = (a.data()['spark'] ?? false) as bool;
      final sb = (b.data()['spark'] ?? false) as bool;
      if (sa != sb) return sa ? -1 : 1;
      final ta = (a.data()['createdAt'] as Timestamp?)?.toDate();
      final tb = (b.data()['createdAt'] as Timestamp?)?.toDate();
      return (tb ?? DateTime.now()).compareTo(ta ?? DateTime.now());
    });

    final limited = docs.take(60).toList();
    final people = await Future.wait<AppUser?>(
        limited.map((d) => _safeUser(d.data()['from'] as String)));
    final out = <LikeItem>[];
    for (var i = 0; i < limited.length; i++) {
      final u = people[i];
      if (u == null) continue;
      final m = limited[i].data();
      out.add(LikeItem(u, (m['spark'] ?? false) as bool,
          (m['createdAt'] as Timestamp?)?.toDate()));
    }
    return out;
  }

  // ---------------------------------------------------------- like / match

  /// Likes [other]. Returns the match id if it became a match, else null.
  /// Runs in a transaction so two people liking at once still match.
  static Future<String?> like(AppUser me, AppUser other,
      {bool spark = false}) async {
    if (spark && !me.canSpark) {
      throw Exception('You have already used this week\'s Spark.');
    }
    final myId = uid;
    try {
      return await _likeTx(myId, me, other, spark);
    } on FirebaseException catch (e) {
      // The database refuses likes to people who blocked you. Move on quietly.
      if (e.code == 'permission-denied') {
        try {
          await pass(other.uid);
        } catch (_) {}
        return null;
      }
      rethrow;
    }
  }

  static Future<String?> _likeTx(
      String myId, AppUser me, AppUser other, bool spark) {
    return db.runTransaction<String?>((tx) async {
      final theirs = await tx.get(likes.doc('${other.uid}_$myId'));
      tx.set(likes.doc('${myId}_${other.uid}'), {
        'from': myId,
        'to': other.uid,
        'spark': spark,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (spark) {
        tx.update(userRef(myId), {'lastSparkAt': FieldValue.serverTimestamp()});
      }
      if (!theirs.exists) return null;
      final id = matchIdFor(myId, other.uid);
      tx.set(matches.doc(id), {
        'users': [myId, other.uid],
        'info': {
          myId: {'name': me.name, 'photo': me.mainPhoto ?? ''},
          other.uid: {'name': other.name, 'photo': other.mainPhoto ?? ''},
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastSender': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      return id;
    });
  }

  static Future<void> pass(String otherId) => userRef(uid)
      .collection('passes')
      .doc(otherId)
      .set({'createdAt': FieldValue.serverTimestamp()});

  static Future<void> undoPass(String otherId) =>
      userRef(uid).collection('passes').doc(otherId).delete();

  // ------------------------------------------------------------------ chat

  static Stream<List<MatchItem>> watchMatches() {
    return matches.where('users', arrayContains: uid).snapshots().map((s) {
      final l = s.docs.map(MatchItem.fromDoc).toList();
      l.sort((a, b) =>
          (b.lastAt ?? DateTime.now()).compareTo(a.lastAt ?? DateTime.now()));
      return l;
    });
  }

  static Stream<List<ChatMsg>> watchMessages(String matchId) {
    return matches
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map(ChatMsg.fromDoc).toList());
  }

  static Future<void> sendMessage(String matchId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (t.length > 1000) throw Exception('Message is too long.');
    final mRef = matches.doc(matchId);
    final batch = db.batch();
    batch.set(mRef.collection('messages').doc(), {
      'sender': uid,
      'text': t,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(mRef, {
      'lastMessage': t.length > 80 ? t.substring(0, 80) : t,
      'lastSender': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> _deleteRefs(List<DocumentReference<Json>> refs,
      {int chunk = 400}) async {
    for (var i = 0; i < refs.length; i += chunk) {
      final batch = db.batch();
      for (final r in refs.skip(i).take(chunk)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  /// Deletes a match and its messages. Used for unmatch and block.
  static Future<void> removeMatch(String matchId) async {
    try {
      for (var round = 0; round < 25; round++) {
        final msgs =
            await matches.doc(matchId).collection('messages').limit(400).get();
        if (msgs.docs.isEmpty) break;
        // Small batches: each message delete runs a rules lookup, and a
        // batch may only do 20 lookups.
        await _deleteRefs(msgs.docs.map((d) => d.reference).toList(),
            chunk: 10);
      }
      await matches.doc(matchId).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- safety

  static Future<void> block(String otherId) async {
    await blocks.doc('${uid}_$otherId').set({
      'blocker': uid,
      'blocked': otherId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await removeMatch(matchIdFor(uid, otherId));
  }

  static Future<void> unblock(String otherId) =>
      blocks.doc('${uid}_$otherId').delete();

  static Future<List<BlockedUser>> blockedList() async {
    final s = await blocks.where('blocker', isEqualTo: uid).get();
    final ids = s.docs.map((d) => d.data()['blocked'] as String).toList();
    final people = await Future.wait<AppUser?>(ids.map(_safeUser));
    final out = <BlockedUser>[];
    for (var i = 0; i < ids.length; i++) {
      out.add(BlockedUser(ids[i], people[i]?.name ?? 'Rizz member'));
    }
    return out;
  }

  /// Files a report. If it came from a chat, the last messages are attached
  /// as evidence because the chat is deleted when the user is blocked.
  static Future<void> report(String otherId, String reason,
      {String? matchId}) async {
    final evidence = <Json>[];
    if (matchId != null) {
      try {
        final s = await matches
            .doc(matchId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
        for (final d in s.docs) {
          final m = d.data();
          evidence.add({'sender': m['sender'], 'text': m['text']});
        }
      } catch (_) {}
    }
    await db.collection('reports').add({
      'reporter': uid,
      'reported': otherId,
      'reason': reason,
      'matchId': matchId,
      'evidence': evidence,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------------------- account

  /// Permanently deletes the account and all of its data.
  static Future<void> deleteAccount(String password) async {
    final user = auth.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) throw Exception('Cannot verify this account.');
    await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password));

    deleting.value = true;
    try {
      final id = user.uid;

      final ms = await matches.where('users', arrayContains: id).get();
      for (final m in ms.docs) {
        await removeMatch(m.id);
      }

      final sent = await likes.where('from', isEqualTo: id).get();
      final recv = await likes.where('to', isEqualTo: id).get();
      await _deleteRefs([
        ...sent.docs.map((d) => d.reference),
        ...recv.docs.map((d) => d.reference),
      ]);

      final passes = await userRef(id).collection('passes').get();
      final tokens = await userRef(id).collection('tokens').get();
      final myBlocks = await blocks.where('blocker', isEqualTo: id).get();
      await _deleteRefs([
        ...passes.docs.map((d) => d.reference),
        ...tokens.docs.map((d) => d.reference),
        ...myBlocks.docs.map((d) => d.reference),
      ]);

      // Every uploaded photo, including ones removed from the profile earlier.
      try {
        final list = await storage.ref('photos/$id').listAll();
        for (final r in list.items) {
          try {
            await r.delete();
          } catch (_) {}
        }
      } catch (_) {}
      try {
        await storage.ref('verifications/$id/selfie.jpg').delete();
      } catch (_) {}

      await _deleteRefs([
        userRef(id).collection('private').doc('info'),
        userRef(id),
      ]);
      await user.delete();
    } finally {
      deleting.value = false;
    }
  }
}

/// Shared list of people to show in Discover and Sparks.
class PoolController extends ChangeNotifier {
  List<AppUser> pool = <AppUser>[];
  bool loading = true;
  String? error;
  AppUser? lastPassed;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(AppUser me) async {
    loading = true;
    error = null;
    _notify();
    try {
      pool = await Backend.candidates(me);
    } catch (e) {
      error = Backend.friendlyError(e);
    }
    loading = false;
    _notify();
  }

  void removeUser(String id) {
    pool = pool.where((u) => u.uid != id).toList();
    _notify();
  }

  void passed(AppUser u) {
    lastPassed = u;
    removeUser(u.uid);
  }

  AppUser? undoPass() {
    final u = lastPassed;
    if (u == null) return null;
    pool = [u, ...pool];
    lastPassed = null;
    _notify();
    return u;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
