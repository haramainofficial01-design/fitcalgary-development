import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../submissions/submission_feedback.dart';

final notificationsProvider = FutureProvider.autoDispose(
  (ref) => ref.read(apiProvider).list('/notifications'),
);

final notificationPreferencesProvider = FutureProvider.autoDispose((ref) async {
  final response = await ref
      .read(apiProvider)
      .dio
      .get<Map<String, dynamic>>('/profile');
  return (response.data?['notification_preferences'] as Map? ?? const {})
      .cast<String, bool>();
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Notification preferences',
          icon: const Icon(Icons.tune),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const NotificationPreferencesDialog(),
          ),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsProvider);
        await ref.read(notificationsProvider.future);
      },
      child: ref
          .watch(notificationsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ErrorPanel(
                  message: workflowError(e),
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
              ],
            ),
            data: (rows) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null) Text(error!),
                if (rows.isEmpty)
                  const EmptyPanel(
                    title: 'You’re all caught up',
                    body: 'Review decisions and ranking updates will appear here.',
                  ),
                for (final row in rows)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        row['opened_at'] == null
                            ? Icons.mark_email_unread_outlined
                            : Icons.drafts_outlined,
                      ),
                      title: Text(row['title'] as String),
                      subtitle: Text(row['body'] as String),
                      onTap: () async {
                        try {
                          await ref
                              .read(apiProvider)
                              .dio
                              .put("/notifications/${row['id']}/opened");
                          ref.invalidate(notificationsProvider);
                          final uri = Uri.tryParse(row['deep_link'] as String);
                          final path = uri?.scheme == 'fitcalgary'
                              ? '/${uri!.host}${uri.path}'
                              : uri?.path;
                          if (context.mounted &&
                              path != null &&
                              RegExp(
                                r'^/(submissions|leaderboards|events)/[a-zA-Z0-9-]+$',
                              ).hasMatch(path)) {
                            context.push(path);
                          }
                        } catch (e) {
                          if (mounted) setState(() => error = workflowError(e));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}

class NotificationPreferencesDialog extends ConsumerStatefulWidget {
  const NotificationPreferencesDialog({super.key});
  @override
  ConsumerState<NotificationPreferencesDialog> createState() =>
      _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState
    extends ConsumerState<NotificationPreferencesDialog> {
  final changes = <String, bool>{};
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Notification preferences'),
    content: SizedBox(
      width: 420,
      child: ref
          .watch(notificationPreferencesProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorPanel(
              message: workflowError(e),
              onRetry: () => ref.invalidate(notificationPreferencesProvider),
            ),
            data: (current) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in const {
                    'eventUpdates': 'Event updates',
                    'announcements': 'FitCalgary announcements',
                  }.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.value),
                      value: changes[option.key] ?? current[option.key] ?? true,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => changes[option.key] = value),
                    ),
                  const Text(
                    'Submission decisions and ranking updates remain in your inbox. Device notification permissions are managed in system settings.',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        onPressed: saving || changes.isEmpty
            ? null
            : () async {
                setState(() {
                  saving = true;
                  error = null;
                });
                try {
                  await ref
                      .read(apiProvider)
                      .dio
                      .patch(
                        '/profile',
                        data: {'notificationPreferences': changes},
                      );
                  ref.invalidate(notificationPreferencesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      saving = false;
                      error = workflowError(e);
                    });
                  }
                }
              },
        child: Text(saving ? 'SAVING…' : 'SAVE'),
      ),
    ],
  );
}
