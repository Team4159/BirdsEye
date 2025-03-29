import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../pages/admin/matchinsight.dart';
import '../../pages/admin/pitsummary.dart';
import '../../pages/metadata.dart';
import 'achievementqueue.dart';
import 'statgraph.dart';

enum AdminRoutePaths {
  statgraphs(Icons.auto_graph_rounded, "Stat Graphs"),
  achiqueue(Icons.queue_rounded, "Achievement Queue"),
  pitresp(Icons.textsms_outlined, "Pit Responses"),
  nextmatch(Icons.visibility, "Match Insight");

  final IconData icon;
  final String title;
  const AdminRoutePaths(this.icon, this.title);
}

final _accessPerms = {
  AdminRoutePaths.achiqueue: (
    perms: () => UserMetadata.instance.cachedPermissions.value.achievementApprover,
    page: () => AchievementQueuePage()
  ),
  AdminRoutePaths.nextmatch: (
    perms: () => UserMetadata.instance.cachedPermissions.value.graphViewer,
    page: () => MatchInsightPage()
  ),
  AdminRoutePaths.pitresp: (
    perms: () => UserMetadata.instance.cachedPermissions.value.pitViewer,
    page: () => PitSummary()
  ),
  AdminRoutePaths.statgraphs: (
    perms: () => UserMetadata.instance.cachedPermissions.value.graphViewer,
    page: () => StatGraphPage()
  )
};

final adminGoRoute = GoRoute(
    path: '/admin',
    redirect: (context, state) => UserMetadata.instance.hasAnyAdminPerms
        ? state.fullPath?.endsWith('/admin') ?? true
            ? state.namedLocation(RoutePaths.adminportal.name)
            : null
        : state.namedLocation(RoutePaths.configuration.name),
    routes: [
      StatefulShellRoute.indexedStack(
          pageBuilder: (context, state, shell) =>
              NoTransitionPage(child: AdminScaffoldShell(shell)),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: 'home',
                  name: RoutePaths.adminportal.name,
                  pageBuilder: (context, state) => const MaterialPage(child: DrawerButton()))
            ]),
            ..._accessPerms.entries.map((route) {
              final GlobalKey<NavigatorState> key = GlobalKey();
              return StatefulShellBranch(navigatorKey: key, routes: [
                GoRoute(
                    parentNavigatorKey: key,
                    path: route.key.name,
                    name: route.key.name,
                    redirect: (context, state) => route.value.perms()
                        ? null
                        : state.namedLocation(RoutePaths.adminportal.name),
                    builder: (context, state) => route.value.page())
              ]);
            })
          ])
    ]);

class AdminScaffoldShell extends StatelessWidget {
  const AdminScaffoldShell(this.navigationShell, {super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          if (index == 0) {
            GoRouter.of(context).replaceNamed(RoutePaths.configuration.name);
          } else {
            GoRouter.of(context).pop();
            navigationShell.goBranch(index);
          }
        },
        children: [
          const NavigationDrawerDestination(
              icon: Icon(Icons.chevron_left_rounded), label: Text("Back")),
          const Divider(),
          for (final route in _accessPerms.entries)
            NavigationDrawerDestination(
                icon: Icon(route.key.icon),
                label: Text(route.key.title),
                enabled: route.value.perms())
        ],
      ),
      body: navigationShell);
}
