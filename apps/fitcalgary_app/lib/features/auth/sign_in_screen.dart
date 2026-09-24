import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../gyms/gym_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    this.nextLocation = '/profile',
    this.returnToOnboarding = false,
    this.onSignedIn,
    super.key,
  });

  final String nextLocation;
  final bool returnToOnboarding;
  final Future<void> Function()? onSignedIn;
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool busy = false;
  String? error;
  Future<void> signIn([AuthIdentityProvider? provider]) async {
    setState(() => busy = true);
    try {
      final auth = ref.read(authServiceProvider);
      switch (provider) {
        case AuthIdentityProvider.google:
          await auth.signInWithGoogle();
        case AuthIdentityProvider.apple:
          await auth.signInWithApple();
        case null:
          await auth.signIn();
      }
      ref.invalidate(savedGymsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(submissionsProvider);
      if (mounted) {
        await widget.onSignedIn?.call();
        if (mounted) context.go(widget.nextLocation);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Sign-in could not be completed. Please try again.',
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
              Text(
                'Sign in.',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Browsing is open to everyone. Sign in only to post marks, save gyms, and manage your profile.',
                style: TextStyle(
                  color: context.fitMuted,
                  height: 1.55,
                  fontSize: 16,
                ),
              ),
              if (widget.returnToOnboarding) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy ? null : () => context.go('/onboarding'),
                    child: const Text('← BACK TO INTRODUCTION'),
                  ),
                ),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: busy ? null : signIn,
                child: Text(busy ? 'CONNECTING…' : 'EMAIL OR PASSWORD →'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => signIn(AuthIdentityProvider.google),
                icon: const Icon(Icons.g_mobiledata, size: 25),
                label: const Text('CONTINUE WITH GOOGLE'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => signIn(AuthIdentityProvider.apple),
                icon: const Icon(Icons.apple),
                label: const Text('SIGN IN WITH APPLE'),
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
              Text(
                'Continue securely to your FitCalgary account. You can also reset your password from the sign-in page.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.fitMuted,
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
