import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../leaderboards/competition_providers.dart';
import 'submission_feedback.dart';

class JudgeQueueScreen extends ConsumerWidget {
  const JudgeQueueScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Judge review queue')),
    body: RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(judgeQueueProvider);
        await ref.read(judgeQueueProvider.future);
      },
      child: ref
          .watch(judgeQueueProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ErrorPanel(
                  message: workflowError(e),
                  onRetry: () => ref.invalidate(judgeQueueProvider),
                ),
              ],
            ),
            data: (rows) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Oldest evidence expires first. Open a performance to check the evidence against the published rules.',
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const EmptyPanel(
                    title: 'Queue is clear',
                    body: 'There are no pending submissions available for your role.',
                  ),
                for (final row in rows)
                  Card(
                    child: ListTile(
                      title: Text(
                        "${row['discipline']} · ${row['claimed_metric']} ${row['unit']}",
                      ),
                      subtitle: Text(
                        "${row['athlete']}\n${row['board_type']} · ${row['resubmission'] == true ? 'Correction' : 'New submission'}",
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push("/submissions/${row['id']}"),
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  const SubmissionDetailScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<SubmissionDetailScreen> createState() =>
      _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState
    extends ConsumerState<SubmissionDetailScreen> {
  final comments = TextEditingController();
  final checks = <String, bool>{};
  bool busy = false;
  String? error;
  @override
  void dispose() {
    comments.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = workflowError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decide(String decision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'APPROVED' ? 'Approve this result?' : 'Save this review?',
        ),
        content: const Text(
          'This decision and your comments will be recorded in the review history. Approval publishes the eligible result.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BACK'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await action(() async {
      await ref
          .read(apiProvider)
          .dio
          .post(
            '/judge/submissions/${widget.id}/decision',
            data: {
              'decision': decision,
              'checklistResponses': checks,
              'comments': comments.text.trim(),
            },
          );
      ref.invalidate(submissionDetailProvider(widget.id));
      ref.invalidate(judgeQueueProvider);
      ref.invalidate(submissionsProvider);
      ref.invalidate(performanceProvider);
      ref.invalidate(boardsProvider);
      ref.invalidate(boardProvider);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Result & review'),
      leading: IconButton(
        tooltip: 'Back to your profile',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh submission',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(submissionDetailProvider(widget.id));
            ref.invalidate(profileProvider);
          },
        ),
      ],
    ),
    body: ref
        .watch(submissionDetailProvider(widget.id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorPanel(
              message: workflowError(e),
              onRetry: () =>
                  ref.invalidate(submissionDetailProvider(widget.id)),
            ),
          ),
          data: (s) {
            final profile = ref.watch(profileProvider).valueOrNull;
            final owner = profile?.id == s['profile_id'];
            final judge =
                profile != null &&
                !owner &&
                (profile.roles.contains('JUDGE') ||
                    profile.roles.contains('ADMIN'));
            final rules = (s['verification_checklist'] as List)
                .cast<Map<String, dynamic>>();
            final reviews = (s['reviews'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  s['discipline'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${s['claimed_metric']} ${s['unit']} · ${s['board_type']}",
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text((s['status'] as String).replaceAll('_', ' ')),
                  ),
                ),
                if (s['result'] is Map)
                  FilledButton.icon(
                    icon: const Icon(Icons.leaderboard),
                    label: const Text('VIEW PUBLISHED BOARD'),
                    onPressed: () => context.push(
                      "/leaderboards/${s['result']['leaderboardId']}",
                    ),
                  ),
                if (s['parent_submission_id'] != null)
                  TextButton(
                    onPressed: () => context.push(
                      "/submissions/${s['parent_submission_id']}",
                    ),
                    child: const Text('VIEW PREVIOUS ATTEMPT'),
                  ),
                for (final review in reviews)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (review['decision'] as String).replaceAll('_', ' '),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (review['comments'] != null)
                            Text(review['comments'] as String),
                        ],
                      ),
                    ),
                  ),
                if (owner &&
                    ['REJECTED', 'CHANGES_REQUESTED'].contains(s['status']) &&
                    s['correction_id'] == null)
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/submit?parent=${widget.id}'),
                    child: const Text('CORRECT & RESUBMIT'),
                  ),
                if (owner && ['DRAFT', 'UPLOADING'].contains(s['status']))
                  OutlinedButton(
                    onPressed: () => context.push('/submit?draft=${widget.id}'),
                    child: const Text('CONTINUE EVIDENCE UPLOAD'),
                  ),
                if (s['correction_id'] != null)
                  TextButton(
                    onPressed: () =>
                        context.push("/submissions/${s['correction_id']}"),
                    child: const Text('VIEW CORRECTED ATTEMPT'),
                  ),
                if (owner &&
                    [
                      'DRAFT',
                      'UPLOADING',
                      'PENDING_REVIEW',
                    ].contains(s['status']))
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await ref
                                .read(apiProvider)
                                .dio
                                .post('/submissions/${widget.id}/cancel');
                            ref.invalidate(submissionDetailProvider(widget.id));
                            ref.invalidate(submissionsProvider);
                          }),
                    child: const Text('WITHDRAW SUBMISSION'),
                  ),
                if (judge && s['status'] == 'PENDING_REVIEW') ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Judge review',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('OPEN PRIVATE EVIDENCE'),
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            final response = await ref
                                .read(apiProvider)
                                .dio
                                .get<Map<String, dynamic>>(
                                  '/judge/submissions/${widget.id}/evidence',
                                );
                            final uri = Uri.parse(
                              response.data!['url'] as String,
                            );
                            if (!await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw StateError('Evidence viewer unavailable');
                            }
                          }),
                  ),
                  const Text(
                    'Evidence links expire shortly and viewing is audited. Review the actual evidence before approving.',
                  ),
                  for (final rule in rules)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checks[rule['key']] == true,
                      title: Text(rule['label'] as String),
                      onChanged: busy
                          ? null
                          : (v) => setState(
                              () => checks[rule['key'] as String] = v ?? false,
                            ),
                    ),
                  TextField(
                    controller: comments,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Feedback (required for changes or rejection)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        busy || rules.any((r) => checks[r['key']] != true)
                        ? null
                        : () => decide('APPROVED'),
                    child: const Text('APPROVE & PUBLISH'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => decide('RESUBMISSION_REQUESTED'),
                    child: const Text('REQUEST CORRECTION'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => decide('REJECTED'),
                    child: const Text('REJECT RESULT'),
                  ),
                ],
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(error!),
              ],
            );
          },
        ),
  );
}
