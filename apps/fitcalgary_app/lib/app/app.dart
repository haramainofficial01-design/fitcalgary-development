import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/onboarding_store.dart';
import '../core/theme.dart';
import '../core/layer_surface.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/events/events_screen.dart';
import '../features/events/content_detail_screen.dart';
import '../features/gyms/gyms_screen.dart';
import '../features/gyms/gym_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboards/leaderboards_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/notifications_screen.dart';
import '../features/submissions/submit_screen.dart';
import '../features/submissions/review_screen.dart';

class FitCalgaryApp extends StatefulWidget {
  const FitCalgaryApp({this.onboardingStore, super.key});

  final OnboardingStore? onboardingStore;

  @override
  State<FitCalgaryApp> createState() => _FitCalgaryAppState();
}

class _FitCalgaryAppState extends State<FitCalgaryApp> {
  GoRouter? router;
  OnboardingController? onboarding;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    final store = widget.onboardingStore ?? SharedPreferencesOnboardingStore();
    final controller = OnboardingController(
      store,
      complete: await store.isComplete(),
    );
    if (!mounted) return;

    final configuredRouter = GoRouter(
      initialLocation: controller.complete ? '/' : '/onboarding',
      refreshListenable: controller,
      redirect: (context, state) {
        final onIntroduction = state.uri.path == '/onboarding';
        final signingIn = state.uri.path == '/signin';
        if (!controller.complete && !onIntroduction && !signingIn) {
          return '/onboarding';
        }
        if (controller.complete && onIntroduction) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => OnboardingScreen(
            onExplore: () async {
              await controller.finish();
              if (context.mounted) context.go('/');
            },
            onAccount: () => context.go('/signin?next=/profile'),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/gyms', builder: (_, _) => const GymsScreen()),
            GoRoute(
              path: '/gyms/compare',
              builder: (_, state) => GymComparisonScreen(
                slugs: (state.uri.queryParameters['slugs'] ?? '')
                    .split(',')
                    .where((v) => v.isNotEmpty)
                    .toSet()
                    .toList(),
              ),
            ),
            GoRoute(
              path: '/gyms/:slug',
              builder: (_, state) =>
                  GymDetailScreen(slug: state.pathParameters['slug']!),
            ),
            GoRoute(
              path: '/saved-gyms',
              builder: (_, _) => const SavedGymsScreen(),
            ),
            GoRoute(
              path: '/leaderboards',
              builder: (_, _) => const LeaderboardsScreen(),
            ),
            GoRoute(
              path: '/leaderboards/:id',
              builder: (_, state) =>
                  LeaderboardsScreen(boardId: state.pathParameters['id']!),
            ),
            GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
            GoRoute(
              path: '/events/:slug',
              builder: (_, state) => ContentDetailScreen(
                slug: state.pathParameters['slug']!,
                club: false,
              ),
            ),
            GoRoute(
              path: '/clubs/:slug',
              builder: (_, state) => ContentDetailScreen(
                slug: state.pathParameters['slug']!,
                club: true,
              ),
            ),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
        GoRoute(
          path: '/signin',
          builder: (context, state) {
            final requested = state.uri.queryParameters['next'];
            final next = requested != null && requested.startsWith('/')
                ? requested
                : '/profile';
            return SignInScreen(
              nextLocation: next,
              returnToOnboarding: !controller.complete,
              onSignedIn: controller.finish,
            );
          },
        ),
        GoRoute(
          path: '/submit',
          builder: (_, state) => SubmitScreen(
            parentId: state.uri.queryParameters['parent'],
            draftId: state.uri.queryParameters['draft'],
          ),
        ),
        GoRoute(
          path: '/submissions/:id',
          builder: (_, state) =>
              SubmissionDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(path: '/judge', builder: (_, _) => const JudgeQueueScreen()),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );

    setState(() {
      onboarding = controller;
      router = configuredRouter;
    });
  }

  @override
  void dispose() {
    router?.dispose();
    onboarding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configuredRouter = router;
    if (configuredRouter == null) {
      return MaterialApp(
        title: 'FitCalgary Index',
        debugShowCheckedModeBanner: false,
        theme: fitTheme(),
        home: const Scaffold(
          backgroundColor: FitColors.ink,
          body: Center(
            child: CircularProgressIndicator(color: FitColors.coral),
          ),
        ),
      );
    }
    return MaterialApp.router(
      title: 'FitCalgary Index',
      debugShowCheckedModeBanner: false,
      theme: fitTheme(),
      routerConfig: configuredRouter,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const paths = ['/', '/gyms', '/leaderboards', '/events', '/profile'];
    final index = location.startsWith('/gyms/') || location == '/saved-gyms'
        ? 1
        : location.startsWith('/events/') || location.startsWith('/clubs/')
        ? 3
        : location.startsWith('/leaderboards/')
        ? 2
        : paths.indexOf(location);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: FitLayerSurface(
              floating: true,
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 68,
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                indicatorColor: FitColors.coral.withValues(alpha: .14),
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: (value) {
                  if (value == index) return;
                  if (!MediaQuery.disableAnimationsOf(context)) {
                    HapticFeedback.selectionClick();
                  }
                  context.go(paths[value]);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    label: 'Gyms',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    label: 'Board',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    label: 'Compete',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Me',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
