import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'backend.dart';
import 'likes_matches.dart';
import 'models.dart';

/// Push notifications. The phone side registers a token and reacts to taps.
/// The messages themselves are sent by Cloud Functions (see /functions).
class Notifications {
  Notifications._();

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Set to a tab index to ask the app shell to switch tabs (2 = Likes You).
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static bool _listening = false;

  /// Call after the user is signed in and has a profile. Safe to call again.
  static Future<void> start() async {
    try {
      final fm = FirebaseMessaging.instance;
      final settings =
          await fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _saveToken(await fm.getToken());

      if (_listening) return;
      _listening = true;
      fm.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);

      // The app was closed and the user opened it by tapping a notification.
      final initial = await fm.getInitialMessage();
      if (initial != null) await _open(initial);
    } catch (_) {
      // No Google Play services, or the user is offline. The app still works.
    }
  }

  static Future<void> _saveToken(String? token) async {
    final user = Backend.auth.currentUser;
    if (token == null || user == null) return;
    try {
      await Backend.userRef(user.uid).collection('tokens').doc(token).set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// A notification arrived while the app is open: show a small banner.
  static void _onForeground(RemoteMessage m) {
    final data = m.data;
    if (data['type'] == 'message' && data['matchId'] == Backend.openChatId) {
      return; // Already looking at this chat.
    }
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    final title = m.notification?.title ?? 'Rizz';
    final body = m.notification?.body ?? '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty)
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          action: SnackBarAction(label: 'Open', onPressed: () => _open(m)),
        ),
      );
  }

  /// The user tapped a notification.
  static Future<void> _open(RemoteMessage m) async {
    final type = m.data['type'];
    if (type == 'like') {
      requestedTab.value = 2;
      return;
    }
    final matchId = m.data['matchId'];
    final user = Backend.auth.currentUser;
    final nav = navKey.currentState;
    if (matchId is! String || user == null || nav == null) return;
    if (Backend.openChatId == matchId) return;
    try {
      final doc = await Backend.matches.doc(matchId).get();
      if (!doc.exists) return;
      final item = MatchItem.fromDoc(doc);
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            matchId: matchId,
            otherId: item.otherId(user.uid),
            otherName: item.otherName(user.uid),
            otherPhoto: item.otherPhoto(user.uid),
          ),
        ),
      );
    } catch (_) {}
  }
}
