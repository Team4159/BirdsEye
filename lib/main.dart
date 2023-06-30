import 'package:birdseye/pages/matchscout.dart';
import 'package:birdseye/pages/savedresponses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './pages/configuration.dart';
import './pages/landing.dart';
import './pages/metadata.dart';
import './pages/pitscout.dart';

const cardinalred = Color(0xffcf2e2e);
final MaterialColor cardinalredmaterial =
    MaterialColor(cardinalred.value, const {
  50: Color(0xFFF9E6E6),
  100: Color(0xFFF1C0C0),
  200: Color(0xFFE79797),
  300: Color(0xFFDD6D6D),
  400: Color(0xFFD64D4D),
  500: cardinalred,
  600: Color(0xFFCA2929),
  700: Color(0xFFC32323),
  800: Color(0xFFBD1D1D),
  900: Color(0xFFB21212),
});
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(
    debug: false,
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
      theme: ThemeData.from(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: cardinalred),
          textTheme:
              Typography.englishLike2021.merge(Typography.blackHelsinki)),
      darkTheme: ThemeData.from(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: cardinalred, brightness: Brightness.dark),
          textTheme: Typography.englishLike2021
              .merge(Typography.whiteHelsinki)
              .copyWith(
                  titleLarge: const TextStyle(
                      inherit: true,
                      fontFamily: "Verdana",
                      fontWeight: FontWeight.bold),
                  headlineLarge: const TextStyle(
                      fontFamily: "VarelaRound",
                      fontWeight: FontWeight.w500,
                      letterSpacing: 4)))));
}

late final SharedPreferences prefs;

final _shellNavigatorKey = GlobalKey<NavigatorState>();

enum RoutePaths {
  landing,
  metadata,
  configuration,
  scouting,
  matchscout,
  pitscout,
  savedresp
}

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
                  : RoutePaths.metadata.name)),
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
                    child: MatchScoutPage(), name: "Match Scouting"),
                redirect: (context, state) async =>
                    await Configuration.instance.isValid
                        ? null
                        : state.namedLocation(RoutePaths.configuration.name)),
            GoRoute(
                parentNavigatorKey: _shellNavigatorKey,
                path: '/scouting/pit',
                name: RoutePaths.pitscout.name,
                pageBuilder: (context, state) => const MaterialPage(
                    child: PitScoutPage(), name: "Pit Scouting"),
                redirect: (context, state) async =>
                    await Configuration.instance.isValid
                        ? null
                        : state.namedLocation(RoutePaths.configuration.name)),
            GoRoute(
                parentNavigatorKey: _shellNavigatorKey,
                path: '/scouting/saved',
                name: RoutePaths.savedresp.name,
                pageBuilder: (context, state) => MaterialPage(
                    child: SavedResponsesPage(), name: "Saved Responses"),
                redirect: (context, state) async =>
                    await Configuration.instance.isValid
                        ? null
                        : state.namedLocation(RoutePaths.configuration.name))
          ])
    ],
    redirect: (context, state) => UserMetadata.isAuthenticated
        ? null
        : state.namedLocation(RoutePaths.landing.name));

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      drawer: Drawer(
          width: 250,
          child: Column(children: [
            ListenableBuilder(
                listenable: UserMetadata.instance,
                builder: (context, child) => UserAccountsDrawerHeader(
                    // FIXME horrible text contrast & overall bad theming
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
            ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: const Text("Saved Responses"),
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.savedresp.name)),
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
