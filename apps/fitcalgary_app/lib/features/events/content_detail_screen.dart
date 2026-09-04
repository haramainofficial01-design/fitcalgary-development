import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'content_providers.dart';

class ContentDetailScreen extends ConsumerWidget {
  const ContentDetailScreen({
    required this.slug,
    required this.club,
    super.key,
  });
  final String slug;
  final bool club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = club
        ? ref.watch(clubDetailProvider(slug))
        : ref.watch(eventDetailProvider(slug));
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: detail.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorPanel(
                      message:
                          '${club ? 'Club' : 'Event'} details could not be loaded.',
                      onRetry: () => club
                          ? ref.invalidate(clubDetailProvider(slug))
                          : ref.invalidate(eventDetailProvider(slug)),
                    ),
                  ),
                ],
              ),
              data: (value) => value is ClubListing
                  ? _ClubDetail(value)
                  : _EventDetail(value as EventListing),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail(this.event);
  final EventListing event;
  @override
  Widget build(BuildContext context) {
    final date = event.startAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      children: [
        const Overline('Event details'),
        const SizedBox(height: 14),
        Text(
          event.name,
          style: const TextStyle(
            fontSize: 38,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.7,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            if (event.phase != null) Chip(label: Text(event.phase!)),
            if (event.registrationStatus != null)
              Chip(label: Text('REGISTRATION ${event.registrationStatus}')),
            if (event.sport != null) Chip(label: Text(event.sport!)),
          ],
        ),
        const SizedBox(height: 24),
        _Facts(
          children: [
            if (date != null)
              _Fact(
                Icons.calendar_today_outlined,
                DateFormat('EEEE, MMMM d, y · h:mm a').format(date.toLocal()),
              ),
            if (event.endAt != null)
              _Fact(
                Icons.schedule,
                'Ends ${DateFormat('MMMM d · h:mm a').format(event.endAt!.toLocal())}',
              ),
            _Fact(
              Icons.location_on_outlined,
              event.location ?? 'Location to be confirmed',
            ),
            if (event.organizer != null)
              _Fact(Icons.groups_outlined, 'Organized by ${event.organizer}'),
            if (event.registrationDeadline != null)
              _Fact(
                Icons.event_busy_outlined,
                'Register by ${DateFormat('MMMM d · h:mm a').format(event.registrationDeadline!.toLocal())}',
              ),
          ],
        ),
        if (event.description != null) ...[
          const SizedBox(height: 28),
          const Overline('About'),
          const SizedBox(height: 10),
          Text(event.description!, style: const TextStyle(height: 1.55)),
        ],
        if (event.entryRequirements != null) ...[
          const SizedBox(height: 24),
          const Overline('Entry requirements'),
          const SizedBox(height: 10),
          Text(event.entryRequirements!, style: const TextStyle(height: 1.55)),
        ],
        const SizedBox(height: 28),
        _ExternalButton(url: event.registrationUrl, label: 'OPEN REGISTRATION'),
      ],
    );
  }
}

class _ClubDetail extends StatelessWidget {
  const _ClubDetail(this.club);
  final ClubListing club;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
    children: [
      const Overline('Club details'),
      const SizedBox(height: 14),
      Text(
        club.name,
        style: const TextStyle(
          fontSize: 38,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.7,
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          Chip(label: Text(club.sport)),
          if (club.category != null) Chip(label: Text(club.category!)),
          ...club.tags
              .where((tag) => tag != 'DEVELOPMENT_FIXTURE')
              .take(4)
              .map((tag) => Chip(label: Text(tag))),
        ],
      ),
      const SizedBox(height: 24),
      _Facts(
        children: [
          _Fact(
            Icons.location_on_outlined,
            [club.address, club.city].whereType<String>().join(' · ').isEmpty
                ? 'Calgary'
                : [club.address, club.city].whereType<String>().join(' · '),
          ),
          if (club.seasonInformation != null)
            _Fact(Icons.calendar_month_outlined, club.seasonInformation!),
          if (club.eligibility != null)
            _Fact(Icons.how_to_reg_outlined, club.eligibility!),
        ],
      ),
      if (club.description != null) ...[
        const SizedBox(height: 28),
        const Overline('About'),
        const SizedBox(height: 10),
        Text(club.description!, style: const TextStyle(height: 1.55)),
      ],
      const SizedBox(height: 28),
      _ExternalButton(
        url: club.registrationUrl ?? club.websiteUrl,
        label: club.registrationUrl == null
            ? 'VISIT CLUB WEBSITE'
            : 'OPEN REGISTRATION',
      ),
    ],
  );
}

class _Facts extends StatelessWidget {
  const _Facts({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FitColors.paper,
      border: Border.all(color: FitColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: FitColors.coralDark),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class _ExternalButton extends StatelessWidget {
  const _ExternalButton({required this.url, required this.label});
  final String? url;
  final String label;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: url == null
        ? null
        : () async {
            final target = Uri.tryParse(url!);
            if (target == null ||
                !await launchUrl(
                  target,
                  mode: LaunchMode.externalApplication,
                )) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('The external link could not be opened.'),
                  ),
                );
              }
            }
          },
    icon: const Icon(Icons.open_in_new),
    label: Text(url == null ? 'LINK NOT YET SUPPLIED' : label),
  );
}
