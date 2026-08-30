import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../core/evidence_uploader.dart';

class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key});
  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  String? discipline;
  final metric = TextEditingController();
  bool clear = false, visible = false, busy = false;
  picker.PlatformFile? evidence;
  int? evidenceSize;
  double progress = 0;
  String? message;
  @override
  void dispose() {
    metric.dispose();
    super.dispose();
  }

  Future<void> selectEvidence() async {
    final file = await picker.FilePicker.pickFile(
      type: picker.FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v'],
    );
    if (!mounted || file == null) return;
    if (file.path == null) {
      setState(() => message = 'The selected evidence file is unavailable.');
      return;
    }
    final size = await file.length();
    if (!mounted) return;
    if (size > 4 * 1024 * 1024 * 1024) {
      setState(() => message = 'Evidence must be 4 GB or smaller.');
      return;
    }
    setState(() {
      evidence = file;
      evidenceSize = size;
      message = null;
    });
  }

  Future<void> submit() async {
    if (discipline == null ||
        double.tryParse(metric.text) == null ||
        !clear ||
        !visible ||
        evidence?.path == null) {
      setState(
        () => message = 'Choose a discipline and evidence file, enter a valid mark, and accept every required check.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      final created = await ref
          .read(apiProvider)
          .dio
          .post<Map<String, dynamic>>(
            '/submissions',
            data: {
              'disciplineId': discipline,
              'claimedMetric': double.parse(metric.text),
              'evidenceType': 'VIDEO',
              'checklistAcceptance': {'clear': clear, 'visible': visible},
            },
          );
      final submissionId = created.data?['id']?.toString();
      if (submissionId == null) {
        throw StateError('Submission identifier missing');
      }
      final file = evidence!;
      await EvidenceUploader(ref.read(apiProvider)).upload(
        submissionId: submissionId,
        filePath: file.path!,
        sizeBytes: evidenceSize!,
        contentType: lookupMimeType(file.path!) ?? 'video/mp4',
        onProgress: (sent, total) {
          if (mounted) setState(() => progress = sent / total);
        },
      );
      if (mounted) {
        setState(
          () => message = 'Evidence uploaded privately. Your result is now pending an authorized judge review.',
        );
        ref.invalidate(submissionsProvider);
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && mounted) {
        context.push('/signin');
      } else if (mounted) {
        setState(
          () => message = 'The submission could not be created. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disciplines = ref.watch(disciplinesProvider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(showActions: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              children: [
                const Overline('Community result'),
                const SizedBox(height: 16),
                const Text(
                  'Put a number\non it.',
                  style: TextStyle(
                    fontSize: 46,
                    height: .98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'One submission, one private evidence upload, one accountable review.',
                  style: TextStyle(color: FitColors.muted, height: 1.5),
                ),
                const SizedBox(height: 28),
                disciplines.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const Text('Disciplines unavailable'),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: discipline,
                    decoration: const InputDecoration(labelText: 'DISCIPLINE'),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => discipline = value),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: metric,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'CLAIMED MARK'),
                ),
                const SizedBox(height: 18),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: clear,
                  onChanged: (value) => setState(() => clear = value ?? false),
                  title: const Text(
                    'My evidence is clear enough to review.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: visible,
                  onChanged: (value) =>
                      setState(() => visible = value ?? false),
                  title: const Text(
                    'The athlete and full performance are visible.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: busy ? null : selectEvidence,
                  icon: const Icon(Icons.video_file_outlined),
                  label: Text(
                    evidence == null
                        ? 'SELECT PRIVATE VIDEO EVIDENCE'
                        : '${evidence!.name} · ${(evidenceSize! / 1024 / 1024).toStringAsFixed(1)} MB',
                  ),
                ),
                if (busy) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress == 0
                        ? 'Preparing secure upload…'
                        : '${(progress * 100).toStringAsFixed(0)}% uploaded',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FitColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy ? 'UPLOADING SECURELY…' : 'SUBMIT FOR REVIEW →',
                  ),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      message!,
                      style: const TextStyle(
                        color: FitColors.coralDark,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
