import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/onboarding_store.dart';
import '../core/theme.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/events/events_screen.dart';
import '../features/gyms/gyms_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboards/leaderboards_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/submissions/submit_screen.dart';

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
              path: '/leaderboards',
              builder: (_, _) => const LeaderboardsScreen(),
            ),
            GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
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
        GoRoute(path: '/submit', builder: (_, _) => const SubmitScreen()),
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
    final index = paths.indexOf(location);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: const Color(0xFFFFE8E3),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (value) => context.go(paths[value]),
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
    );
  }
}
