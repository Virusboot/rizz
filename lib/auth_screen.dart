import 'package:flutter/material.dart';

import 'backend.dart';
import 'theme.dart';
import 'widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool login = true;
  bool busy = false;
  bool agree = false;
  bool hide = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final e = email.text.trim();
    final p = pass.text;
    if (!e.contains('@') || !e.contains('.')) {
      toast(context, 'Enter a valid email address.');
      return;
    }
    if (login ? p.isEmpty : p.length < 8) {
      toast(context, login
          ? 'Enter your password.'
          : 'Password must be at least 8 characters.');
      return;
    }
    if (!login && !agree) {
      toast(context, 'Please confirm you are 18 or older and accept the terms.');
      return;
    }
    setState(() => busy = true);
    try {
      if (login) {
        await Backend.signIn(e, p);
      } else {
        await Backend.signUp(e, p);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Center(child: RizzLogo(size: 52)),
                  const SizedBox(height: 10),
                  const Text('Real people. Honest intentions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted, fontSize: 16)),
                  const SizedBox(height: 32),
                  Text(login ? 'Welcome back' : 'Create your account',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: inputDeco('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: hide,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => busy ? null : _submit(),
                    decoration: inputDeco('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => hide = !hide),
                      ),
                    ),
                  ),
                  if (login)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _forgot,
                          child: const Text('Forgot password?')),
                    ),
                  if (!login)
                    CheckboxListTile(
                      value: agree,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => agree = v ?? false),
                      title: const Text(
                          'I am 18 or older and I agree to the Terms and Privacy Policy.',
                          style: TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrand,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(login ? 'Sign in' : 'Create account'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => login = !login),
                    child: Text(login
                        ? 'New here? Create an account'
                        : 'Already have an account? Sign in'),
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
