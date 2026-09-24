import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../core/theme.dart';
import 'gym_providers.dart';

class SaveGymButton extends ConsumerStatefulWidget {
  const SaveGymButton({required this.gym, super.key});
  final Gym gym;
  @override
  ConsumerState<SaveGymButton> createState() => _SaveGymButtonState();
}

class _SaveGymButtonState extends ConsumerState<SaveGymButton> {
  bool busy = false;
  Future<void> toggle(bool saved) async {
    setState(() => busy = true);
    try {
      if (await ref.read(authServiceProvider).current() == null) {
        if (mounted) {
          context.push(
            Uri(
              path: '/signin',
              queryParameters: {'next': '/gyms/${widget.gym.slug}'},
            ).toString(),
          );
        }
        return;
      }
      final dio = ref.read(apiProvider).dio;
      if (saved) {
        await dio.delete<void>('/saved-gyms/${widget.gym.id}');
      } else {
        await dio.put<void>('/saved-gyms/${widget.gym.id}');
      }
      ref.invalidate(savedGymsProvider);
      await ref.read(savedGymsProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved gyms could not be updated. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedGymsProvider);
    final saved =
        state.asData?.value.any((g) => g.id == widget.gym.id) ?? false;
    return IconButton(
      key: ValueKey('save-${widget.gym.slug}'),
      tooltip: state.hasError
          ? 'Retry saved gyms'
          : saved
          ? 'Remove saved gym'
          : 'Save gym privately',
      onPressed: busy || state.isLoading
          ? null
          : state.hasError
          ? () => ref.invalidate(savedGymsProvider)
          : () => toggle(saved),
      icon: Icon(
        state.hasError
            ? Icons.refresh
            : saved
            ? Icons.bookmark
            : Icons.bookmark_border,
      ),
    );
  }
}

class PricingPlans extends StatelessWidget {
  const PricingPlans({required this.plans, super.key});
  final List<dynamic> plans;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (plans.isEmpty) const Text('Pricing has not been supplied.'),
      for (final plan in plans)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['plan_name']?.toString() ?? 'Membership',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (plan['pricing_complete'] != true)
                  const Text(
                    'Pricing incomplete — no all-in estimate',
                    style: TextStyle(color: FitColors.coralDark),
                  )
                else ...[
                  Text(
                    '${money(plan['ongoing_monthly_cents'])} / month all-in',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${money(plan['first_year_monthly_cents'])} / month in year one',
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Advertised: ${plan['pricing_complete'] == true ? money(plan['recurring_cents']) : 'Unconfirmed'} / ${plan['billing_frequency']?.toString().toLowerCase() ?? 'period'}',
                ),
                Text(
                  'Mandatory recurring fee: ${money(plan['mandatory_recurring_fee_cents'])}',
                ),
                Text(
                  'Annual fee: ${money(plan['mandatory_annual_fee_cents'])}',
                ),
                Text('Joining fee: ${money(plan['initiation_fee_cents'])}'),
                if (plan['membership_type'] != null)
                  Text('Membership: ${plan['membership_type']}'),
                Text(
                  'Contract: ${plan['contract_months'] == null ? 'Not supplied' : '${plan['contract_months']} months'}',
                ),
                if (plan['eligibility'] != null)
                  Text('Eligibility: ${plan['eligibility']}'),
                if (plan['drop_in_cents'] != null)
                  Text('Drop-in: ${money(plan['drop_in_cents'])}'),
                if (plan['trial_details'] != null)
                  Text('Trial: ${plan['trial_details']}'),
                if (plan['notes'] != null) Text(plan['notes'].toString()),
                const SizedBox(height: 8),
                Text(
                  'Last checked: ${plan['last_verified_at'] ?? 'Not supplied'}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (plan['source_url'] != null)
                  SelectableText(
                    'Source: ${plan['source_url']}',
                    style: TextStyle(fontSize: 11, color: context.fitMuted),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
