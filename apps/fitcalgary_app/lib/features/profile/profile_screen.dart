import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../gyms/gym_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: FutureBuilder(
            future: ref.read(authServiceProvider).current(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data == null) return const _SignedOutProfile();
              return const _SignedInProfile();
            },
          ),
        ),
      ],
    ),
  );
}

class _SignedOutProfile extends StatelessWidget {
  const _SignedOutProfile();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Overline('Athlete profile'),
      const SizedBox(height: 18),
      const Text(
        'Your fitness\nidentity.',
        style: TextStyle(
          fontSize: 46,
          height: .98,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.5,
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Sign in to see verified results, leaderboard positions, saved gyms, submissions, and notification preferences.',
        style: TextStyle(color: FitColors.muted, height: 1.55),
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => context.push('/signin'),
        child: const Text('SIGN IN →'),
      ),
      const SizedBox(height: 28),
      const _AccountFeature(
        icon: Icons.verified_outlined,
        title: 'VERIFIED RESULTS',
        body: 'Your reviewed marks and leaderboard positions.',
      ),
      const _AccountFeature(
        icon: Icons.bookmark_border,
        title: 'SAVED GYMS',
        body: 'Keep a private shortlist from the Calgary index.',
      ),
      const _AccountFeature(
        icon: Icons.notifications_none,
        title: 'NOTIFICATIONS',
        body: 'Review, ranking and event updates under your control.',
      ),
    ],
  );
}

class _AccountFeature extends StatelessWidget {
  const _AccountFeature({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: FitColors.line)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 25),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 11,
                  color: FitColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SignedInProfile extends ConsumerWidget {
  const _SignedInProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final submissions = ref.watch(submissionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(submissionsProvider);
        await Future.wait([
          ref.read(profileProvider.future),
          ref.read(submissionsProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        children: [
          const Overline('Athlete profile'),
          profile.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => ErrorPanel(
              message: 'Your profile could not be synchronized.',
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (value) => _ProfileIdentity(profile: value),
          ),
          const SizedBox(height: 34),
          OutlinedButton(
            onPressed: () => context.push('/saved-gyms'),
            child: const Text('SAVED GYMS'),
          ),
          const Divider(color: FitColors.ink),
          const SizedBox(height: 22),
          const Overline('Submissions'),
          submissions.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => ErrorPanel(
              message: 'Submission history could not be loaded.',
              onRetry: () => ref.invalidate(submissionsProvider),
            ),
            data: (items) => items.isEmpty
                ? const EmptyPanel(
                    title: 'No submissions yet',
                    body: 'Post a result with private evidence to begin your verified history.',
                  )
                : Column(
                    children: items
                        .map((item) => _SubmissionRow(submission: item))
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(profileProvider);
              ref.invalidate(savedGymsProvider);
              ref.invalidate(submissionsProvider);
              if (context.mounted) context.go('/');
            },
            child: const Text('SIGN OUT'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _confirmDeletion(context, ref),
            child: const Text('DELETE ACCOUNT'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes private account data. Public verified records are retained only in anonymized form where integrity or legal requirements apply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiProvider).dio.delete<void>('/profile');
      await ref.read(authServiceProvider).signOut();
      ref.invalidate(savedGymsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(submissionsProvider);
      if (context.mounted) context.go('/');
    } on DioException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deletion could not be completed. Please retry or contact support.',
            ),
          ),
        );
      }
    }
  }
}

class _ProfileIdentity extends ConsumerWidget {
  const _ProfileIdentity({required this.profile});

  final AthleteProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(
        profile.displayName,
        style: const TextStyle(
          fontSize: 42,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.2,
        ),
      ),
      if (profile.gymName != null) ...[
        const SizedBox(height: 12),
        Text(profile.gymName!, style: const TextStyle(color: FitColors.muted)),
      ],
      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(profile.bio!, style: const TextStyle(height: 1.5)),
      ],
      if (profile.roles.contains('PERSONAL_TRAINER')) ...[
        const SizedBox(height: 18),
        const Chip(label: Text('VERIFIED TRAINER PROFILE')),
      ],
      const SizedBox(height: 22),
      OutlinedButton(
        onPressed: () async {
          final changed = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EditProfileSheet(profile: profile),
          );
          if (changed == true) ref.invalidate(profileProvider);
        },
        child: const Text('EDIT PROFILE'),
      ),
    ],
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final AthleteProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController name = TextEditingController(
    text: widget.profile.displayName,
  );
  late final TextEditingController bio = TextEditingController(
    text: widget.profile.bio,
  );
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().length < 2 || bio.text.length > 280) {
      setState(
        () => error =
            'Use a name of at least 2 characters and a bio no longer than 280.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .dio
          .patch<void>(
            '/profile',
            data: {'displayName': name.text.trim(), 'bio': bio.text.trim()},
          );
      if (mounted) Navigator.pop(context, true);
    } on DioException {
      if (mounted) {
        setState(() => error = 'Profile changes could not be saved.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(labelText: 'DISPLAY NAME'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bio,
            maxLength: 280,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'BIO'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: FitColors.coralDark)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'SAVING…' : 'SAVE CHANGES'),
          ),
        ],
      ),
    ),
  );
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.submission});

  final SubmissionRecord submission;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: FitColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                submission.discipline,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Claimed mark ${submission.claimedMetric}',
                style: const TextStyle(fontSize: 11, color: FitColors.muted),
              ),
              if (submission.reviewComment != null) ...[
                const SizedBox(height: 7),
                Text(
                  submission.reviewComment!,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        Chip(label: Text(submission.status.replaceAll('_', ' '))),
      ],
    ),
  );
}
