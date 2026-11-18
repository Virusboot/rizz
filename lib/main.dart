import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'backend.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'notifications.dart';
import 'onboarding.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }
  runApp(RizzApp(initError: initError));
}

class RizzApp extends StatelessWidget {
  final Object? initError;
  const RizzApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hookin',
      debugShowCheckedModeBanner: false,
      navigatorKey: Notifications.navKey,
      scaffoldMessengerKey: Notifications.messengerKey,
      theme: buildTheme(),
      home: initError != null
          ? SetupNeededScreen(error: initError!)
          : const SplashScreen(),
    );
  }
}

/// Screen 1: Splash screen showing only the logo
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<void> _startTimer() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: RizzLogo(size: 64),
      ),
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBg,
      body: Center(child: RizzLogo(size: 64)),
    );
  }
}

class SetupNeededScreen extends StatelessWidget {
  final Object error;
  const SetupNeededScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RizzLogo(size: 44),
              const SizedBox(height: 24),
              const Text('Firebase is not set up yet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'Run "flutterfire configure" in the project folder, then restart the app. See README.md for the full steps.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 16),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decides what to show: sign in, onboarding, or the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Splash();
        }
        final user = snap.data;
        if (user == null) return const AuthScreen();
        return ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  final String uid;
  const ProfileGate({super.key, required this.uid});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Stream<DocumentSnapshot<Json>> stream =
      Backend.userRef(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Backend.deleting,
      builder: (context, deleting, _) {
        if (deleting) return const Splash();
        return StreamBuilder<DocumentSnapshot<Json>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Scaffold(
                body: EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Could not load your profile',
                  body: Backend.friendlyError(snap.error!),
                  cta: 'Sign out',
                  onCta: Backend.signOut,
                ),
              );
            }
            if (!snap.hasData) return const Splash();
            final doc = snap.data!;
            if (!doc.exists) return const OnboardingScreen();
            final me = AppUser.fromDoc(doc);
            if (!me.onboarded) return const OnboardingScreen();
            return Shell(me: me);
          },
        );
      },
    );
  }
}
