import 'dart:async';

import 'package:birdseye/routing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/supabase.dart' show SupabaseInterface;
import '../main.dart' show cardinalred;
import 'metadata.dart' show UserMetadata;

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: Drawer(
          // Legacy code. To be replaced once I can figure out how the hell to calculate the current page from GoRouter.
          width: 225,
          child: Column(children: [
            if (MediaQuery.of(context).size.height > 400)
              UserAccountsDrawerHeader(
                  decoration: Theme.of(context).brightness == Brightness.dark
                      ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)
                      : null,
                  currentAccountPicture: Icon(Icons.person,
                      size: 64,
                      color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white),
                  accountName:
                      Text(UserMetadata.name!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  accountEmail: Text("Team ${UserMetadata.team!}",
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
                                      final goLanding = const LandingRoute().goLater(context);
                                      await SupabaseInterface.clearSession();
                                      await UserMetadata.signOut();
                                      goLanding();
                                    },
                                    child: const Text("Confirm"))
                              ]))),
            _MetadataListTile(),
            ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text("Configuration"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => const ConfigurationRoute().go(context)),
            ListTile(
              leading: const Icon(Icons.assignment_rounded),
              title: const Text("Match Scouting"),
              dense: MediaQuery.of(context).size.height <= 400,
              // onTap: () => const MatchScoutRoute(matchCode: )
            ),
            ListTile(
                leading: const Icon(Icons.list_rounded),
                title: const Text("Pit Scouting"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)..pop()
                // ..goNamed(RoutePaths.pitscout.name)
                ),
            ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: const Text("Saved Responses"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)..pop()
                // ..goNamed(RoutePaths.savedresp.name)
                ),
            ListTile(
                leading: const Icon(Icons.emoji_events_rounded),
                title: const Text("Achievements"),
                dense: MediaQuery.of(context).size.height <= 400,
                onTap: () => GoRouter.of(context)..pop()
                // ..goNamed(RoutePaths.achievements.name)
                ),
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
          onTap: () => GoRouter.of(context)..pop()
          // ..goNamed(RoutePaths.metadata.name)
          ));
}
