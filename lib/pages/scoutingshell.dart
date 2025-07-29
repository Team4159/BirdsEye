import 'package:birdseye/routing.dart';
import 'package:birdseye/usermetadata.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldShell extends StatelessWidget {
  final Widget child;
  const ScaffoldShell(this.child, {super.key});

  static final _destinations = <Navigable>[
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
        return _destinations.indexWhere((d) => here == d.location.split("?").first);
      }(),
      onDestinationSelected: (i) {
        /// hide the drawer
        context.pop();

        /// go to the place
        _destinations[i].go(context);
      },
      children: [
        UserMetadataHeader(),
        ..._destinations.whereType<Navigable>().map((d) => d.destination),
      ],
    ),
  );
}

class UserMetadataHeader extends StatelessWidget {
  const UserMetadataHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final userMeta = UserMetadata.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return UserAccountsDrawerHeader(
      decoration: isDark
          ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)
          : null,
      currentAccountPicture: Icon(Icons.person, size: 64, color: isDark ? null : Colors.white),
      accountName: Text(userMeta.name!, style: const TextStyle(fontWeight: FontWeight.w600)),
      accountEmail: Text(
        "Team ${userMeta.team!}",
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
            OutlinedButton(onPressed: context.pop, child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                await userMeta.signOut();
                // ignore: use_build_context_synchronously
                const LandingRoute().go(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }
}
