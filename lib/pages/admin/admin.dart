import 'package:birdseye/pages/admin/matchinsight.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../pages/metadata.dart';
import 'achievementqueue.dart';
import 'statgraph.dart';

final _adminNavigatorKey = GlobalKey<NavigatorState>();

enum AdminRoutePaths { statgraphs, achiqueue, qualanaly, nextmatch }

final adminGoRoute = GoRoute(
    path: '/admin',
    redirect: (context, state) => UserMetadata.instance.hasAnyAdminPerms
        ? state.fullPath?.endsWith('/admin') ?? true
            ? state.namedLocation(RoutePaths.adminportal.name)
            : null
        : state.namedLocation(RoutePaths.configuration.name),
    routes: [
      ShellRoute(
          navigatorKey: _adminNavigatorKey,
          pageBuilder: (context, state, child) =>
              NoTransitionPage(child: AdminScaffoldShell(child)),
          routes: [
            GoRoute(
                parentNavigatorKey: _adminNavigatorKey,
                path: 'home',
                name: RoutePaths.adminportal.name,
                pageBuilder: (context, state) => const MaterialPage(child: DrawerButton())),
            GoRoute(
                parentNavigatorKey: _adminNavigatorKey,
                path: AdminRoutePaths.achiqueue.name,
                name: AdminRoutePaths.achiqueue.name,
                pageBuilder: (context, state) =>
                    MaterialPage(child: AchievementQueuePage(), name: "Achievement Queue"),
                redirect: (context, state) =>
                    UserMetadata.instance.cachedPermissions.value.achievementApprover
                        ? null
                        : state.namedLocation(RoutePaths.adminportal.name)),
            GoRoute(
                parentNavigatorKey: _adminNavigatorKey,
                path: AdminRoutePaths.nextmatch.name,
                name: AdminRoutePaths.nextmatch.name,
                pageBuilder: (context, state) =>
                    MaterialPage(child: MatchInsightPage(), name: "Match Insight"),
                redirect: (context, state) =>
                    UserMetadata.instance.cachedPermissions.value.graphViewer
                        ? null
                        : state.namedLocation(RoutePaths.adminportal.name))
          ]),
      GoRoute(
          path: AdminRoutePaths.statgraphs.name,
          name: AdminRoutePaths.statgraphs.name,
          pageBuilder: (context, state) =>
              MaterialPage(child: StatGraphPage(), name: "Stat Graphs"),
          redirect: (context, state) => UserMetadata.instance.cachedPermissions.value.graphViewer
              ? null
              : state.namedLocation(RoutePaths.adminportal.name)),
    ]);

class AdminScaffoldShell extends StatelessWidget {
  final Widget child;
  const AdminScaffoldShell(this.child, {super.key});

  static Drawer drawer() => Drawer(
      width: 250,
      child: ListenableBuilder(
          listenable: UserMetadata.instance.cachedPermissions,
          builder: (context, _) => Column(children: [
                ListTile(
                    leading: const Icon(Icons.chevron_left_rounded),
                    title: const Text("Back"),
                    onTap: () => GoRouter.of(context)
                      ..pop()
                      ..goNamed(RoutePaths.configuration.name)),
                const Divider(),
                ListTile(
                    leading: const Icon(Icons.auto_graph_rounded),
                    title: const Text("Stat Graphs"),
                    enabled: UserMetadata.instance.cachedPermissions.value.graphViewer,
                    onTap: () => GoRouter.of(context)
                      ..pop()
                      ..goNamed(AdminRoutePaths.statgraphs.name)),
                ListTile(
                    leading: const Icon(Icons.queue_rounded),
                    title: const Text("Achievement Queue"),
                    enabled: UserMetadata.instance.cachedPermissions.value.achievementApprover,
                    onTap: () => GoRouter.of(context)
                      ..pop()
                      ..goNamed(AdminRoutePaths.achiqueue.name)),
                ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text("Match Insight"),
                    enabled: UserMetadata.instance.cachedPermissions.value.graphViewer,
                    onTap: () => GoRouter.of(context)
                      ..pop()
                      ..goNamed(AdminRoutePaths.nextmatch.name)),
              ])));

  @override
  Widget build(BuildContext context) => Scaffold(drawer: drawer(), body: child);
}
