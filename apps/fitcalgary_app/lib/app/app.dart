import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/home/home_screen.dart';
import '../features/gyms/gyms_screen.dart';
import '../features/leaderboards/leaderboards_screen.dart';
import '../features/events/events_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/submissions/submit_screen.dart';

final _router = GoRouter(
  routes: [
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
    GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/submit', builder: (_, _) => const SubmitScreen()),
  ],
);

class FitCalgaryApp extends StatelessWidget {
  const FitCalgaryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'FitCalgary Index',
    debugShowCheckedModeBanner: false,
    theme: fitTheme(),
    routerConfig: _router,
  );
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
