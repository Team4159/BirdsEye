import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'interfaces/supabase.dart';
import 'pages/achievements.dart';
import 'pages/admin/admin.dart' show adminGoRoute;
import 'pages/configuration.dart';
import 'pages/landing.dart';
import 'pages/legal.dart';
import 'pages/matchscout.dart';
import 'pages/metadata.dart';
import 'pages/pitscout.dart';
import 'pages/savedresponses.dart';

const cardinalred = Color(0xffcf2e2e);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(
    debug: false,
    // authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    url: 'https://zcckkiwosxzupxblocff.supabase.co',
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY2traXdvc3h6dXB4YmxvY2ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODY4NDk3MzMsImV4cCI6MjAwMjQyNTczM30.IVIT9yIxQ9JiwbDB6v10ZI8eP7c1oQhwoWZejoODllQ",
  );
  UserMetadata.initialize();
  runApp(MaterialApp.router(
      routerConfig: router,
      title: "Bird's Eye",
      themeMode: ThemeMode.system,
      theme: ThemeData.from(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFFB91C21),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFFFDAD6),
            onPrimaryContainer: Color(0xFF410003),
            secondary: Color(0xFF5C53A7),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFE4DFFF),
            onSecondaryContainer: Color(0xFF170362),
            tertiary: Color(0xFF006C4E),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFF87F8C9),
            onTertiaryContainer: Color(0xFF002115),
            error: Color(0xFFBA1A1A),
            errorContainer: Color(0xFFFFDAD6),
            onError: Color(0xFFFFFFFF),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFFFFBFF),
            onSurface: Color(0xFF201A19),
            surfaceContainerHighest: Color(0xFFF5DDDB),
            onSurfaceVariant: Color(0xFF534342),
            outline: Color(0xFF857371),
            onInverseSurface: Color(0xFFFBEEEC),
            inverseSurface: Color(0xFF362F2E),
            inversePrimary: Color(0xFFFFB3AC),
            shadow: Color(0xFF000000),
            surfaceTint: Color(0xFFB91C21),
            outlineVariant: Color(0xFFD8C2BF),
            scrim: Color(0xFF000000),
          ),
          textTheme: Typography.englishLike2021.merge(Typography.blackHelsinki).copyWith(
              titleLarge: const TextStyle(
                  inherit: true, fontFamily: "Verdana", fontWeight: FontWeight.bold),
              headlineLarge: const TextStyle(
                  fontFamily: "VarelaRound", fontWeight: FontWeight.w500, letterSpacing: 4))),
      darkTheme: ThemeData.from(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFFFB3AC),
            onPrimary: Color(0xFF680008),
            primaryContainer: Color(0xFF930010),
            onPrimaryContainer: Color(0xFFFFDAD6),
            secondary: Color(0xFFC6BFFF),
            onSecondary: Color(0xFF2D2276),
            secondaryContainer: Color(0xFF443A8E),
            onSecondaryContainer: Color(0xFFE4DFFF),
            tertiary: Color(0xFF6ADBAE),
            onTertiary: Color(0xFF003827),
            tertiaryContainer: Color(0xFF00513A),
            onTertiaryContainer: Color(0xFF87F8C9),
            error: Color(0xFFFFB4AB),
            errorContainer: Color(0xFF93000A),
            onError: Color(0xFF690005),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF201A19),
            onSurface: Color(0xFFEDE0DE),
            surfaceContainerHighest: Color(0xFF534342),
            onSurfaceVariant: Color(0xFFD8C2BF),
            outline: Color(0xFFA08C8A),
            onInverseSurface: Color(0xFF201A19),
            inverseSurface: Color(0xFFEDE0DE),
            inversePrimary: Color(0xFFB91C21),
            shadow: Color(0xFF000000),
            surfaceTint: Color(0xFFFFB3AC),
            outlineVariant: Color(0xFF534342),
            scrim: Color(0xFF000000),
          ),
          textTheme: Typography.englishLike2021.merge(Typography.whiteHelsinki).copyWith(
              titleLarge: const TextStyle(
                  inherit: true, fontFamily: "Verdana", fontWeight: FontWeight.bold),
              headlineLarge: const TextStyle(
                  fontFamily: "VarelaRound", fontWeight: FontWeight.w500, letterSpacing: 4)))));
}

late final SharedPreferences prefs;

final _shellNavigatorKey = GlobalKey<NavigatorState>();

enum RoutePaths {
  landing,
  metadata("Metadata"),
  configuration("Configuration"),
  achievements,
  scouting,
  matchscout("Match Scouting"),
  pitscout("Pit Scouting"),
  savedresp("Saved Responses"),
  adminportal;

  final String? label;
  const RoutePaths([this.label]);
}

final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
          path: '/',
          name: RoutePaths.landing.name,
          pageBuilder: (context, state) =>
              const MaterialPage(child: LandingPage(), name: "Sign In"),
          redirect: (_, state) => UserMetadata.isAuthenticated
              ? state.namedLocation(RoutePaths.metadata.name, queryParameters: {"redirect": "true"})
              : null),
      GoRoute(
          path: '/accountdata',
          name: RoutePaths.metadata.name,
          pageBuilder: (context, state) => MaterialPage(
              child: Scaffold(body: SafeArea(child: MetadataPage())),
              name: RoutePaths.metadata.label),
          redirect: (_, state) async {
            if (!UserMetadata.isAuthenticated) {
              return state.namedLocation(RoutePaths.landing.name, queryParameters: {});
            }
            if (state.uri.queryParameters["redirect"] != "true") return null;
            if (await UserMetadata.instance.isValid) {
              return state.namedLocation(RoutePaths.configuration.name);
            }
            return null;
          }),
      GoRoute(
          path: '/scouting',
          redirect: (context, state) => UserMetadata.isAuthenticated
              ? state.fullPath?.endsWith('/scouting') ?? true
                  ? state.namedLocation(RoutePaths.configuration.name)
                  : null
              : state.namedLocation(RoutePaths.landing.name),
          routes: [
            ShellRoute(
                navigatorKey: _shellNavigatorKey,
                pageBuilder: (context, state, child) =>
                    NoTransitionPage(child: ScaffoldShell(child)),
                routes: [
                  GoRoute(
                      parentNavigatorKey: _shellNavigatorKey,
                      path: 'configuration',
                      name: RoutePaths.configuration.name,
                      pageBuilder: (context, state) => MaterialPage(
                          child: ConfigurationPage(), name: RoutePaths.configuration.label)),
                  GoRoute(
                      parentNavigatorKey: _shellNavigatorKey,
                      path: 'match',
                      name: RoutePaths.matchscout.name,
                      pageBuilder: (context, state) => MaterialPage(
                          child: state.uri.queryParameters.containsKey("matchCode")
                              ? MatchScoutPage.fromCode(state.uri.queryParameters["matchCode"]!)
                              : MatchScoutPage(),
                          name: RoutePaths.matchscout.label),
                      redirect: (context, state) async => await Configuration.instance.isValid
                          ? null
                          : state.namedLocation(RoutePaths.configuration.name)),
                  GoRoute(
                      parentNavigatorKey: _shellNavigatorKey,
                      path: 'pit',
                      name: RoutePaths.pitscout.name,
                      pageBuilder: (context, state) =>
                          MaterialPage(child: PitScoutPage(), name: RoutePaths.pitscout.label),
                      redirect: (context, state) async => await Configuration.instance.isValid
                          ? null
                          : state.namedLocation(RoutePaths.configuration.name)),
                  GoRoute(
                      parentNavigatorKey: _shellNavigatorKey,
                      path: 'saved',
                      name: RoutePaths.savedresp.name,
                      pageBuilder: (context, state) => MaterialPage(
                          child: SavedResponsesPage(), name: RoutePaths.savedresp.label),
                      redirect: (context, state) async => await Configuration.instance.isValid
                          ? null
                          : state.namedLocation(RoutePaths.configuration.name)),
                  GoRoute(
                      parentNavigatorKey: _shellNavigatorKey,
                      path: 'achievements',
                      name: RoutePaths.achievements.name,
                      pageBuilder: (context, state) => MaterialPage(
                          child: AchievementsPage(
                              season: Configuration.instance.season, event: Configuration.event),
                          name: RoutePaths.achievements.label),
                      redirect: (context, state) async => await Configuration.instance.isValid
                          ? null
                          : state.namedLocation(RoutePaths.configuration.name)),
                ])
          ]),
      adminGoRoute,
      ShellRoute(
          pageBuilder: (context, state, child) => MaterialPage(child: LegalShell(child)),
          routes: [
            GoRoute(path: '/legal/privacy', builder: (_, __) => const MarkdownWidget("privacy")),
            GoRoute(path: '/legal/terms', builder: (_, __) => const MarkdownWidget("tos")),
            GoRoute(path: '/legal/cookies', builder: (_, __) => const MarkdownWidget("cookies"))
          ])
    ],
    refreshListenable: UserMetadata.instance,
    onException: (_, state, router) => router.goNamed(RoutePaths.landing.name));

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      drawer: Drawer(
          // Legacy code. To be replaced once I can figure out how the hell to calculate the current page from GoRouter.
          width: 225,
          child: Column(children: [
            if (MediaQuery.of(context).size.height > 400)
              ListenableBuilder(
                  listenable: UserMetadata.instance,
                  builder: (context, child) => UserAccountsDrawerHeader(
                      decoration: Theme.of(context).brightness == Brightness.dark
                          ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)
                          : null,
                      currentAccountPicture: Icon(
                          UserMetadata.isAuthenticated ? Icons.person : Icons.person_off_outlined,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? null
                              : Colors.white),
                      accountName: Text(UserMetadata.instance.name ?? "User",
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      accountEmail: Text(
                          UserMetadata.instance.team != null
                              ? "Team ${UserMetadata.instance.team}"
                              : "No Team",
                          style: const TextStyle(fontWeight: FontWeight.w300)),
                      arrowColor: Colors.transparent,
                      onDetailsPressed: () => showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                                  title: const Text("Sign Out"),
                                  content: const Text("Are you sure you want to sign out?"),
                                  actions: [
                                    OutlinedButton(
                                        onPressed: () => GoRouter.of(context).pop(),
                                        child: const Text("Cancel")),
                                    FilledButton(
                                        onPressed: () async {
                                          final router = GoRouter.of(context);
                                          await Supabase.instance.client.auth.signOut();
                                          router.goNamed(RoutePaths.landing.name);
                                        },
                                        child: const Text("Confirm"))
                                  ])))),
            _MetadataListTile(),
            ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text("Configuration"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.configuration.name)),
            ListTile(
                leading: const Icon(Icons.assignment_rounded),
                title: const Text("Match Scouting"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.matchscout.name)),
            ListTile(
                leading: const Icon(Icons.list_rounded),
                title: const Text("Pit Scouting"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.pitscout.name)),
            ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: const Text("Saved Responses"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.savedresp.name)),
            ListTile(
                leading: const Icon(Icons.emoji_events_rounded),
                title: const Text("Achievements"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)
                  ..pop()
                  ..goNamed(RoutePaths.achievements.name)),
            ListenableBuilder(
                listenable: UserMetadata.instance.cachedPermissions,
                builder: (context, _) => UserMetadata.instance.hasAnyAdminPerms
                    ? ListTile(
                        leading: const Icon(Icons.bar_chart_rounded),
                        title: const Text("Admin Tools"),
                        dense: MediaQuery.of(context).size.height <= 400,
                        onTap: () => GoRouter.of(context)
                          ..pop()
                          ..goNamed(RoutePaths.adminportal.name))
                    : const SizedBox()),
            const Expanded(
                child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                        height: 65,
                        child: DrawerHeader(
                            margin: EdgeInsets.zero,
                            child: Text(
                              "Bird's Eye",
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: "HemiHead", fontSize: 32, color: cardinalred),
                            )))))
          ])),
      body: child);
}

class _MetadataListTile extends StatefulWidget {
  const _MetadataListTile();

  @override
  State<_MetadataListTile> createState() => __MetadataListTileState();
}

class __MetadataListTileState extends State<_MetadataListTile> {
  late Future<bool> canConnect;

  @override
  void initState() {
    canConnect = SupabaseInterface.canConnect;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: canConnect,
      builder: (context, snapshot) => ListTile(
          leading: const Icon(Icons.app_registration_outlined),
          title: const Text("Metadata"),
          dense: MediaQuery.of(context).size.height <= 400,
          enabled: snapshot.hasData && snapshot.data!,
          onTap: () => GoRouter.of(context)
            ..pop()
            ..goNamed(RoutePaths.metadata.name)));
}
