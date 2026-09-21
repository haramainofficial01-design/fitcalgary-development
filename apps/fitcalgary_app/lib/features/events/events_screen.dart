import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'content_providers.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final search = TextEditingController();
  Timer? debounce;
  String section = 'ALL EVENTS';
  String query = '';
  int page = 1;

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void changeSection(String value) => setState(() {
    section = value;
    page = 1;
  });
  void changeQuery(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          query = value.trim();
          page = 1;
        });
      }
    });
  }

  String get parameters {
    final values = <String, String>{'page': '$page', 'pageSize': '12'};
    if (query.isNotEmpty) values['q'] = query;
    if (section == 'UPCOMING') values['phase'] = 'UPCOMING';
    if (section == 'OPEN ENTRY') values['open'] = 'true';
    return Uri(queryParameters: values).query;
  }

  @override
  Widget build(BuildContext context) {
    final content = section == 'CLUBS'
        ? ref.watch(clubDirectoryProvider(parameters))
        : ref.watch(eventDirectoryProvider(parameters));
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (section == 'CLUBS') {
                  ref.invalidate(clubDirectoryProvider(parameters));
                  await ref.read(clubDirectoryProvider(parameters).future);
                } else {
                  ref.invalidate(eventDirectoryProvider(parameters));
                  await ref.read(eventDirectoryProvider(parameters).future);
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 40),
                children: [
                  const Overline('Compete'),
                  const SizedBox(height: 15),
                  const Text(
                    'You can enter\nthese.',
                    style: TextStyle(
                      fontSize: 46,
                      height: .98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Published Calgary events and recreational clubs, backed by the FitCalgary directory.',
                    style: TextStyle(color: FitColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: search,
                    onChanged: changeQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: section == 'CLUBS'
                          ? 'Search clubs or sports'
                          : 'Search events or sports',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                search.clear();
                                changeQuery('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: ['UPCOMING', 'OPEN ENTRY', 'ALL EVENTS', 'CLUBS']
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value),
                            selected: section == value,
                            onSelected: (_) => changeSection(value),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 26),
                  content.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => ErrorPanel(
                      message: 'Published content could not be loaded.',
                      onRetry: () {
                        if (section == 'CLUBS') {
                          ref.invalidate(clubDirectoryProvider(parameters));
                        } else {
                          ref.invalidate(eventDirectoryProvider(parameters));
                        }
                      },
                    ),
                    data: (result) => _DirectoryResults(
                      section: section,
                      result: result,
                      page: page,
                      onPage: (value) => setState(() => page = value),
                    ),
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

class _DirectoryResults extends StatelessWidget {
  const _DirectoryResults({
    required this.section,
    required this.result,
    required this.page,
    required this.onPage,
  });
  final String section;
  final dynamic result;
  final int page;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = result.items;
    final int total = result.total;
    if (items.isEmpty) {
      return EmptyPanel(
        title: page > 1
            ? 'No more published results'
            : 'No matching published content',
        body: 'Try another search or section to find your next event.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$total PUBLISHED ${section == 'CLUBS' ? 'CLUBS' : 'EVENTS'}',
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
            color: FitColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => item is ClubListing
              ? _ClubCard(item)
              : _EventCard(item as EventListing),
        ),
        if (page > 1 || page * 12 < total)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: page > 1 ? () => onPage(page - 1) : null,
                    child: const Text('← PREVIOUS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: page * 12 < total
                        ? () => onPage(page + 1)
                        : null,
                    child: const Text('NEXT →'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.event);
  final EventListing event;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('event-${event.slug}'),
    onTap: () => context.go('/events/${event.slug}'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            color: const Color(0xFFFFE8E3),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: FitColors.coralDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  event.location ?? 'Calgary',
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (event.phase != null) _Label(event.phase!),
                    if (event.registrationStatus == 'OPEN')
                      const _Label('OPEN ENTRY'),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    ),
  );
}

class _ClubCard extends StatelessWidget {
  const _ClubCard(this.club);
  final ClubListing club;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('club-${club.slug}'),
    onTap: () => context.go('/clubs/${club.slug}'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            color: const Color(0xFFFFE8E3),
            child: const Icon(
              Icons.groups_outlined,
              color: FitColors.coralDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  [club.sport, club.city].whereType<String>().join(' · '),
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
                if (club.category != null) ...[
                  const SizedBox(height: 9),
                  _Label(club.category!.toUpperCase()),
                ],
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xFFFFE8E3)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 8,
          color: FitColors.coralDark,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    ),
  );
}
