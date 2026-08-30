import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

class GymsScreen extends ConsumerStatefulWidget {
  const GymsScreen({super.key});
  @override
  ConsumerState<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends ConsumerState<GymsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final gyms = ref.watch(gymsProvider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(gymsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
                children: [
                  const Overline('The gym index'),
                  const SizedBox(height: 16),
                  const Text(
                    'Every major gym\nin Calgary.',
                    style: TextStyle(
                      fontSize: 43,
                      height: .98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Advertised rates and normalized all-in monthly cost, side by side.',
                    style: TextStyle(color: FitColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    onChanged: (value) =>
                        setState(() => query = value.toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search gyms, operators, areas',
                    ),
                  ),
                  const SizedBox(height: 18),
                  gyms.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => ErrorPanel(
                      message: 'The gym index could not be reached. Check your connection and try again.',
                      onRetry: () => ref.invalidate(gymsProvider),
                    ),
                    data: (items) {
                      final visible = items
                          .where(
                            (item) =>
                                query.isEmpty ||
                                '${item.name} ${item.operatorName} ${item.area ?? ''}'
                                    .toLowerCase()
                                    .contains(query),
                          )
                          .toList();
                      if (visible.isEmpty) {
                        return const EmptyPanel(
                          title: 'No gyms found',
                          body: 'Try another search. Production listings are published through the FitCalgary admin system.',
                        );
                      }
                      return Column(
                        children: visible.map((item) => _GymRow(item)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GymRow extends ConsumerStatefulWidget {
  const _GymRow(this.gym);
  final Gym gym;

  @override
  ConsumerState<_GymRow> createState() => _GymRowState();
}

class _GymRowState extends ConsumerState<_GymRow> {
  late bool saved = widget.gym.saved;
  bool busy = false;

  Future<void> toggleSaved() async {
    setState(() => busy = true);
    try {
      if (saved) {
        await ref
            .read(apiProvider)
            .dio
            .delete<void>('/saved-gyms/${widget.gym.id}');
      } else {
        await ref
            .read(apiProvider)
            .dio
            .put<void>('/saved-gyms/${widget.gym.id}');
      }
      if (mounted) setState(() => saved = !saved);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && mounted) {
        context.push('/signin');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved gyms could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = widget.gym;
    final cents = gym.lowestOngoingMonthlyCents;
    final name = gym.name;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            color: const Color(0xFFDDDAD2),
            alignment: Alignment.center,
            child: Text(
              name
                  .split(' ')
                  .take(2)
                  .map((word) => word.isEmpty ? '' : word[0])
                  .join(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.operatorName,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: FitColors.coralDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  gym.area ?? gym.city,
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cents == null
                    ? 'Pricing\nincomplete'
                    : '\$${(cents / 100).toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: cents == null ? 11 : 21,
                  fontWeight: FontWeight.w900,
                  color: cents == null ? FitColors.muted : FitColors.ink,
                ),
              ),
              if (cents != null)
                const Text(
                  'ALL-IN / MO',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.2,
                    color: FitColors.muted,
                  ),
                ),
              const SizedBox(height: 8),
              IconButton(
                tooltip: saved ? 'Remove saved gym' : 'Save gym privately',
                onPressed: busy ? null : toggleSaved,
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
