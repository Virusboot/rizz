import 'package:flutter/material.dart';

import 'backend.dart';
import 'theme.dart';
import 'widgets.dart';

// Alias for backwards compatibility
typedef AuthScreen = LoginScreen;

/// Screen 2: Login screen without logo
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool hide = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final e = email.text.trim();
    final p = pass.text;
    if (!e.contains('@') || !e.contains('.')) {
      toast(context, 'Enter a valid email address.');
      return;
    }
    if (p.isEmpty) {
      toast(context, 'Enter your password.');
      return;
    }
    setState(() => busy = true);
    try {
      await Backend.signIn(e, p);
    } catch (err) {
      if (mounted) toast(context, Backend.friendlyError(err));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _forgot() async {
    final e = email.text.trim();
    if (!e.contains('@')) {
      toast(context, 'Type your email above first.');
      return;
    }
    try {
      await Backend.resetPassword(e);
      if (mounted) toast(context, 'Password reset link sent. Check your email.');
    } catch (err) {
      if (mounted) toast(context, Backend.friendlyError(err));
    }
  }

  void _openSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue connecting with people.',
                    style: TextStyle(color: kMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: inputDeco('Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pass,
                    obscureText: hide,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => busy ? null : _signIn(),
                    decoration: inputDeco('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => hide = !hide),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgot,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrand,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: busy ? null : _signIn,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Sign in',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: busy ? null : _openSignUp,
                    child: const Text(
                      'New here? Create an account',
                      style: TextStyle(
                        color: kBrand,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 3: Create account screen
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool agree = false;
  bool hide = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final e = email.text.trim();
    final p = pass.text;
    if (!e.contains('@') || !e.contains('.')) {
      toast(context, 'Enter a valid email address.');
      return;
    }
    if (p.length < 8) {
      toast(context, 'Password must be at least 8 characters.');
      return;
    }
    if (!agree) {
      toast(context, 'Please confirm you are 18 or older and accept the terms.');
      return;
    }
    setState(() => busy = true);
    try {
      await Backend.signUp(e, p);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) toast(context, Backend.friendlyError(err));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Real people. Honest intentions.',
                    style: TextStyle(color: kMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: inputDeco('Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pass,
                    obscureText: hide,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => busy ? null : _signUp(),
                    decoration: inputDeco('Password (min 8 characters)').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => hide = !hide),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: agree,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => agree = v ?? false),
                    title: const Text(
                      'I am 18 or older and I agree to the Terms and Privacy Policy.',
                      style: TextStyle(fontSize: 13, color: kInk),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrand,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: busy ? null : _signUp,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Already have an account? Sign in',
                      style: TextStyle(
                        color: kBrand,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
