import 'package:birdseye/pages/configuration.dart';
import 'package:birdseye/pages/metadata.dart';
import 'package:birdseye/pages/landing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: 'https://zcckkiwosxzupxblocff.supabase.co',
    anonKey: const String.fromEnvironment('SUPABASE_KEY',
        defaultValue:
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY2traXdvc3h6dXB4YmxvY2ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODY4NDk3MzMsImV4cCI6MjAwMjQyNTczM30.IVIT9yIxQ9JiwbDB6v10ZI8eP7c1oQhwoWZejoODllQ"),
  );
  UserMetadata.initialize();
  runApp(MaterialApp.router(
      routerConfig: router,
      title: "Bird's Eye",
      themeMode: ThemeMode.system,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.localize(
          ThemeData.dark(useMaterial3: true),
          Typography.material2021(colorScheme: const ColorScheme.dark())
              .geometryThemeFor(ScriptCategory.englishLike))));
}

late final SharedPreferences prefs;

final _shellNavigatorKey = GlobalKey<NavigatorState>();

enum RoutePaths { landing, metadata, config, matchscout, pitscout }

final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RoutePaths.landing.name,
        pageBuilder: (context, state) =>
            const MaterialPage(child: LandingPage(), name: "Sign In"),
        redirect: (_, state) => !UserMetadata.isAuthenticated
            ? null
            : state.namedLocation(RoutePaths.metadata.name),
      ),
      GoRoute(
          path: '/account/data',
          name: RoutePaths.metadata.name,
          pageBuilder: (context, state) => MaterialPage(
              child: Scaffold(body: SafeArea(child: MetadataPage())),
              name: "Metadata")),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        pageBuilder: (context, state, child) =>
            NoTransitionPage(child: ScaffoldShell(child)),
        routes: [
          GoRoute(
              parentNavigatorKey: _shellNavigatorKey,
              path: '/config',
              name: RoutePaths.config.name,
              pageBuilder: (context, state) => const MaterialPage(
                  child: ConfigurationPage(), name: "Configuration")),
          GoRoute(
              parentNavigatorKey: _shellNavigatorKey,
              path: '/scouting/match',
              name: RoutePaths.matchscout.name,
              pageBuilder: (context, state) => const MaterialPage(
                  child: Center(child: Text("TODO")), name: "Match Scouting")),
          GoRoute(
              parentNavigatorKey: _shellNavigatorKey,
              path: '/scouting/pit',
              name: RoutePaths.pitscout.name,
              pageBuilder: (context, state) => const MaterialPage(
                  child: Center(child: Text("TODO")), name: "Pit Scouting"))
        ],
      ),
    ],
    redirect: (context, state) => UserMetadata.isAuthenticated
        ? null
        : state.namedLocation(RoutePaths.landing.name));

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: SafeArea(child: child));
}
