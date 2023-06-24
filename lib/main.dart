import 'package:birdseye/pages/matchscout.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './pages/configuration.dart';
import './pages/landing.dart';
import './pages/metadata.dart';
import './pages/pitscout.dart';

const cardinalred = Color(0xffcf2e2e);
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
          // FIXME garbage coloring smh
          ThemeData.dark(useMaterial3: true),
          Typography.material2021(colorScheme: const ColorScheme.dark())
              .geometryThemeFor(ScriptCategory.englishLike))));
}

late final SharedPreferences prefs;

final _shellNavigatorKey = GlobalKey<NavigatorState>();

enum RoutePaths { landing, metadata, configuration, matchscout, pitscout }

final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RoutePaths.landing.name,
        pageBuilder: (context, state) =>
            const MaterialPage(child: LandingPage(), name: "Sign In"),
        redirect: (_, state) async => !UserMetadata.isAuthenticated
            ? null
            : state.namedLocation(await UserMetadata.instance.isValid
                ? RoutePaths.configuration.name
                : RoutePaths.metadata.name),
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
                path: '/configuration',
                name: RoutePaths.configuration.name,
                pageBuilder: (context, state) => const MaterialPage(
                    child: ConfigurationPage(), name: "Configuration")),
            GoRoute(
                parentNavigatorKey: _shellNavigatorKey,
                path: '/scouting/match',
                name: RoutePaths.matchscout.name,
                pageBuilder: (context, state) => const MaterialPage(
                    child: MatchScoutPage(), name: "Match Scouting")),
            GoRoute(
                parentNavigatorKey: _shellNavigatorKey,
                path: '/scouting/pit',
                name: RoutePaths.pitscout.name,
                pageBuilder: (context, state) => const MaterialPage(
                    child: PitScoutPage(), name: "Pit Scouting"))
          ])
    ],
    redirect: (context, state) => UserMetadata.isAuthenticated
        ? null
        : state.namedLocation(RoutePaths.landing.name));

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  // static TextStyle _onPrimaryStyle(BuildContext context) =>
  //     TextStyle(color: Theme.of(context).colorScheme.onPrimary); FIXME text contrast on Drawer Header is totally broken

  @override
  Widget build(BuildContext context) => Scaffold(
      drawer: Drawer(
          width: 200,
          child: Column(children: [
            ListenableBuilder(
                listenable: UserMetadata.instance,
                builder: (context, child) => UserAccountsDrawerHeader(
                    currentAccountPicture: Icon(
                        UserMetadata.isAuthenticated
                            ? Icons.person
                            : Icons.person_off_outlined,
                        size: 64),
                    accountName: Text(UserMetadata.instance.name ?? "User"),
                    accountEmail: Text(UserMetadata.instance.team != null
                        ? "Team ${UserMetadata.instance.team}"
                        : "No Team"))),
            ListTile(
                leading: const Icon(Icons.app_registration_outlined),
                title: const Text("Metadata"),
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.metadata.name)),
            ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text("Configuration"),
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.configuration.name)),
            ListTile(
                leading: const Icon(Icons.assignment_rounded),
                title: const Text("Match Scouting"),
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.matchscout.name)),
            ListTile(
                leading: const Icon(Icons.list_rounded),
                title: const Text("Pit Scouting"),
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.pitscout.name)),
            const Expanded(
                child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                        height: 70,
                        child: DrawerHeader(
                            margin: EdgeInsets.zero,
                            child: Text(
                              "Bird's Eye",
                              style: TextStyle(
                                  fontFamily: "HemiHead",
                                  fontSize: 32,
                                  color: cardinalred),
                            )))))
          ])),
      body: SafeArea(child: child));
}