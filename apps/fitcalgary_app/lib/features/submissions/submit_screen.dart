import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/evidence_uploader.dart';
import '../../core/evidence_picker.dart';
import '../../core/theme.dart';
import '../leaderboards/competition_providers.dart';
import 'submission_feedback.dart';

class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({this.parentId, this.draftId, super.key});
  final String? parentId;
  final String? draftId;
  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  String? discipline, division, city, submissionId, message;
  String kind = 'OFFICIAL';
  final metric = TextEditingController();
  final checks = <String, bool>{};
  bool busy = false;
  double progress = 0;
  picker.PlatformFile? evidence;
  CancelToken? cancellation;
  @override
  void initState() {
    super.initState();
    if (widget.parentId != null || widget.draftId != null) loadParent();
  }

  Future<void> loadParent() async {
    try {
      final parent = await ref.read(
        submissionDetailProvider(widget.parentId ?? widget.draftId!).future,
      );
      final profile = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>('/profile');
      if (mounted) {
        setState(() {
          city = profile.data?['city_id'] as String?;
          if (widget.draftId != null) {
            submissionId = widget.draftId;
            checks.addAll(
              (parent['checklist_acceptance'] as Map).cast<String, bool>(),
            );
          }
          discipline = parent['discipline_id'] as String;
          division = parent['division_id'] as String?;
          kind = parent['board_type'] as String;
          metric.text = parent['claimed_metric'].toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = workflowError(e));
    }
  }

  @override
  void dispose() {
    cancellation?.cancel();
    metric.dispose();
    super.dispose();
  }

  double? valueFor(Map<String, dynamic> d) {
    final raw = metric.text.trim();
    if (d['metric_type'] == 'TIME' && raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      final minutes = int.tryParse(parts[0]), seconds = int.tryParse(parts[1]);
      if (minutes == null ||
          seconds == null ||
          minutes < 0 ||
          seconds < 0 ||
          seconds >= 60) {
        return null;
      }
      return (minutes * 60 + seconds).toDouble();
    }
    return double.tryParse(raw);
  }

  Future<void> send(Map<String, dynamic> d) async {
    final value = valueFor(d);
    final rules = (d['verification_checklist'] as List)
        .cast<Map<String, dynamic>>();
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        (d['metric_type'] == 'REPETITIONS' &&
            value.truncateToDouble() != value)) {
      setState(
        () => message = 'Enter a positive result in the displayed units. Repetitions must be whole numbers.',
      );
      return;
    }
    if (city == null) {
      setState(() => message = 'Select the city you represent.');
      return;
    }
    if (kind == 'OFFICIAL' &&
        (evidence == null || rules.any((r) => checks[r['key']] != true))) {
      setState(
        () => message =
            'Select private evidence and confirm every published check.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    cancellation = CancelToken();
    try {
      final api = ref.read(apiProvider);
      await api.dio.patch('/profile', data: {'cityId': city});
      ref.invalidate(profileProvider);
      if (kind == 'COMMUNITY') {
        final response = await api.dio.post<Map<String, dynamic>>(
          '/results/community',
          data: {
            'disciplineId': d['id'],
            'divisionId': division,
            'metric': value,
          },
        );
        ref.invalidate(performanceProvider);
        ref.invalidate(boardsProvider);
        ref.invalidate(boardProvider);
        if (mounted) {
          context.go('/leaderboards/${response.data!['leaderboard_id']}');
        }
        return;
      }
      if (submissionId == null) {
        final response = await api.dio.post<Map<String, dynamic>>(
          '/submissions',
          data: {
            'disciplineId': d['id'],
            'divisionId': division,
            'claimedMetric': value,
            'boardType': kind,
            'evidenceType': d['evidence_type'] == 'VIDEO'
                ? 'VIDEO'
                : 'ACTIVITY_FILE',
            'checklistAcceptance': checks,
            'parentSubmissionId': widget.parentId,
          },
        );
        submissionId = response.data!['id'] as String;
      }
      final file = evidence!;
      final size = await file.length();
      final ext = file.extension?.toLowerCase();
      final mime = ext == 'gpx'
          ? 'application/gpx+xml'
          : ext == 'mov'
          ? 'video/quicktime'
          : 'video/mp4';
      await EvidenceUploader(api).upload(
        submissionId: submissionId!,
        file: file,
        sizeBytes: size,
        contentType: mime,
        cancelToken: cancellation,
        onProgress: (sent, total) {
          if (mounted) setState(() => progress = sent / total);
        },
      );
      ref.invalidate(submissionsProvider);
      ref.invalidate(submissionDetailProvider);
      if (mounted) context.go('/submissions/$submissionId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && mounted) {
        context.push('/signin?next=/submit');
      }
      if (mounted) setState(() => message = workflowError(e));
    } catch (e) {
      if (mounted) setState(() => message = workflowError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(competitionCatalogProvider);
    final locked = busy || submissionId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Post a result')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Overline('Your next personal best'),
          const SizedBox(height: 16),
          const Text(
            'Put a number\non it.',
            style: TextStyle(
              fontSize: 44,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get a performance verified with private evidence, or record an unverified community claim. Final eligibility follows the published discipline and division rules.',
          ),
          const SizedBox(height: 22),
          if (widget.parentId == null)
            Wrap(
              spacing: 8,
              children: [
                for (final type in ['OFFICIAL', 'COMMUNITY'])
                  ChoiceChip(
                    label: Text(
                      type == 'OFFICIAL'
                          ? 'Request verification'
                          : 'Community claim',
                    ),
                    selected: kind == type,
                    onSelected: locked
                        ? null
                        : (_) => setState(() {
                            kind = type;
                            discipline = null;
                            checks.clear();
                          }),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          catalog.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => ErrorPanel(
              message: 'Competition rules could not be loaded.',
              onRetry: () => ref.invalidate(competitionCatalogProvider),
            ),
            data: (data) {
              final ds = data['disciplines']!
                  .where(
                    (d) =>
                        d[kind == 'OFFICIAL'
                            ? 'official_eligible'
                            : 'community_eligible'] ==
                        true,
                  )
                  .toList();
              if (ds.isEmpty) {
                return const EmptyPanel(
                  title: 'No eligible disciplines',
                  body: 'Check back when the competition rules have been published.',
                );
              }
              final d = ds.firstWhere(
                (d) => d['id'] == discipline,
                orElse: () => ds.first,
              );
              final rules = (d['verification_checklist'] as List)
                  .cast<Map<String, dynamic>>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('discipline-${d['id']}'),
                    initialValue: d['id'] as String,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Discipline'),
                    items: ds
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['id'] as String,
                            child: Text(d['display_name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: locked || widget.parentId != null
                        ? null
                        : (v) => setState(() {
                            discipline = v;
                            checks.clear();
                            evidence = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: city,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'City represented',
                    ),
                    items: data['cities']!
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: locked ? null : (v) => setState(() => city = v),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('division-$division'),
                    initialValue: division,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Division (default: Open)',
                    ),
                    items: data['divisions']!
                        .map(
                          (v) => DropdownMenuItem(
                            value: v['id'] as String,
                            child: Text(v['display_label'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (v) => setState(() => division = v),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : () => context.push('/profile'),
                    child: const Text('EDIT AGE / CATEGORY ELIGIBILITY'),
                  ),
                  TextField(
                    controller: metric,
                    enabled: !locked,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: d['metric_type'] == 'TIME'
                          ? 'Time (mm:ss or seconds)'
                          : 'Result (${d['unit']})',
                    ),
                  ),
                  if (kind == 'OFFICIAL') ...[
                    const SizedBox(height: 14),
                    Text(
                      "Verification rules · version ${d['rules_version']}",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final rule in rules)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(rule['label'] as String),
                        value: checks[rule['key']] == true,
                        onChanged: locked
                            ? null
                            : (v) => setState(
                                () =>
                                    checks[rule['key'] as String] = v ?? false,
                              ),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final file = await ref.read(
                                evidencePickerProvider,
                              )(d['evidence_type'] == 'VIDEO');
                              if (file == null || !mounted) return;
                              final size = await file.length();
                              if (!mounted) return;
                              if (size <= 0 || size > 4 * 1024 * 1024 * 1024) {
                                setState(
                                  () => message = 'Choose an evidence file between 1 byte and 4 GB.',
                                );
                                return;
                              }
                              setState(() {
                                evidence = file;
                                message = null;
                              });
                            },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        evidence?.name ??
                            (d['evidence_type'] == 'VIDEO'
                                ? 'SELECT PRIVATE VIDEO'
                                : 'SELECT PRIVATE GPX FILE'),
                      ),
                    ),
                    Text(
                      'Evidence is private, limited to authorized reviewers, and removed under the retention policy.',
                      style: TextStyle(fontSize: 12, color: context.fitMuted),
                    ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(message!, semanticsLabel: message),
                    ),
                  if (busy) ...[
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                    ),
                    TextButton(
                      onPressed: () => cancellation?.cancel(),
                      child: const Text('PAUSE UPLOAD'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : () => send(d),
                    child: Text(
                      busy
                          ? 'SAVING…'
                          : submissionId != null
                          ? 'RETRY EVIDENCE UPLOAD'
                          : kind == 'OFFICIAL'
                          ? 'SUBMIT FOR REVIEW'
                          : 'POST UNVERIFIED CLAIM',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
