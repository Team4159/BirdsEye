import '../routing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'metadata.dart' show UserMetadata;

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  static final _destinations = <Navigable?>[
    const MetadataRoute(redir: false),
    const ConfigurationRoute(),
    MatchScoutRoute(),
    PitScoutRoute(),
    const SavedResponsesRoute(),
    AchievementsRoute(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    resizeToAvoidBottomInset: false,
    drawer: NavigationDrawer(
      selectedIndex: () {
        final here = GoRouter.of(context).state.uri.path;
        return _destinations.indexWhere((d) => here == d?.location.split("?").first);
      }(),
      onDestinationSelected: (i) {
        context.pop(); // hide the drawer
        _destinations[i]?.go(context); // go to the place
      },
      children: [
        UserAccountsDrawerHeader(
          decoration: Theme.of(context).brightness == Brightness.dark
              ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)
              : null,
          currentAccountPicture: Icon(
            Icons.person,
            size: 64,
            color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
          ),
          accountName: Text(
            UserMetadata.name!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          accountEmail: Text(
            "Team ${UserMetadata.team!}",
            style: const TextStyle(fontWeight: FontWeight.w300),
          ),
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
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () async {
                    await UserMetadata.signOut();
                    appRouter.go(const LandingRoute().location);
                  },
                  child: const Text("Confirm"),
                ),
              ],
            ),
          ),
        ),
        ..._destinations.whereType<Navigable>().map((d) => d.destination),
      ],
    ),
  );
}
