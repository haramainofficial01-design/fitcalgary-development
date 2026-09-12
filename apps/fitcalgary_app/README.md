# FitCalgary mobile application

This package contains the Flutter application shared by the FitCalgary iOS and Android products. It provides onboarding, authentication, gym discovery and comparison, clubs and events, athlete profiles, leaderboards, result submission, review feedback, saved gyms, and notifications through the versioned Go API.

## Configuration

Runtime endpoints and identity settings are supplied through Dart defines rather than committed credentials. Use the repository `.env.example` and `docs/DEVELOPMENT.md` as configuration references. Local integration runs can use `--dart-define-from-file` with an untracked configuration file.

## Developer commands

From this directory:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The checked-in `ios` and `android` projects contain the platform build configuration. Production signing, provider credentials, and service endpoints must be supplied through the appropriate platform and deployment environments.
