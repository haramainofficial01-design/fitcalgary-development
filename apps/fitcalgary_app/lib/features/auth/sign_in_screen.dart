import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool busy = false;
  String? error;
  Future<void> signIn() async {
    setState(() => busy = true);
    try {
      await ref.read(authServiceProvider).signIn();
      if (mounted) {
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Sign-in could not be completed. Check the identity service and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const BrandHeader(showActions: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 30),
            children: [
              const Overline('Account'),
              const SizedBox(height: 18),
              const Text(
                'Sign in.',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Browsing is open to everyone. Sign in only to post marks, save gyms, and manage your profile.',
                style: TextStyle(
                  color: FitColors.muted,
                  height: 1.55,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: busy ? null : signIn,
                child: Text(busy ? 'CONNECTING…' : 'CONTINUE SECURELY →'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    error!,
                    style: const TextStyle(color: FitColors.coralDark),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Email/password, Google, and Apple are handled by the FitCalgary Keycloak identity service using OIDC Authorization Code + PKCE.',
                style: TextStyle(
                  fontSize: 11,
                  color: FitColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
