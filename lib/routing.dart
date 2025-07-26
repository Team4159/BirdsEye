import 'dart:async' show FutureOr;

import 'interfaces/bluealliance.dart' show MatchInfo;
import 'pages/configuration.dart';
import 'pages/landing.dart';

import 'pages/legal.dart';
import 'pages/matchscouting/matchscout.dart';
import 'pages/pitscout.dart';
import 'pages/savedresponses.dart';
import 'pages/scoutingshell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/metadata.dart' show UserMetadata, MetadataPage;

part 'routing.g.dart';

final routerConfig = GoRouter(routes: $appRoutes);

@TypedGoRoute<LandingRoute>(path: '/', routes: [
  TypedShellRoute<LegalShellRoute>(routes: [
    TypedGoRoute<LegalPrivacyRoute>(path: '/legal/privacy'),
    TypedGoRoute<LegalTermsRoute>(path: '/legal/terms'),
    TypedGoRoute<LegalCookiesRoute>(path: '/legal/cookies')
  ]),
  TypedGoRoute<MetadataRoute>(path: '/metadata', caseSensitive: false),
  TypedGoRoute<ConfigurationRoute>(path: '/configuration', caseSensitive: false),
  TypedShellRoute<ScoutingShellRoute>(routes: [
    TypedGoRoute<PitScoutRoute>(path: '/pitscout', caseSensitive: false),
    TypedGoRoute<MatchScoutRoute>(path: '/matchscout', caseSensitive: false),
    TypedGoRoute<SavedResponsesRoute>(path: '/savedresponses', caseSensitive: false)
  ])
])
@immutable
class LandingRoute extends GoRouteData with _$LandingRoute {
  const LandingRoute();

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (UserMetadata.signedIn) {
      return const MetadataRoute(redir: true).location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => LandingPage();
}

@immutable
class LegalShellRoute extends ShellRouteData {
  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) =>
      LegalShell(navigator);
}

@immutable
class LegalPrivacyRoute extends GoRouteData with _$LegalPrivacyRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const MarkdownPage("privacy");
}

@immutable
class LegalTermsRoute extends GoRouteData with _$LegalTermsRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const MarkdownPage("tos");
}

@immutable
class LegalCookiesRoute extends GoRouteData with _$LegalCookiesRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const MarkdownPage("cookies");
}

@immutable
class MetadataRoute extends GoRouteData with _$MetadataRoute {
  /// whether or not to check if metadata is already available, and skip the metadata page if so
  final bool redir;
  const MetadataRoute({required this.redir});

  @override
  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    if (!UserMetadata.signedIn) {
      return const LandingRoute().location;
    }
    if (!redir) return null;
    if (await UserMetadata.isValid) {
      return const ConfigurationRoute().location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => MetadataPage();
}

@immutable
class ConfigurationRoute extends GoRouteData with _$ConfigurationRoute {
  const ConfigurationRoute();

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (!UserMetadata.signedIn) {
      return const LandingRoute().location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => ConfigurationPage();
}

final shellNavigatorKey = GlobalKey<NavigatorState>();

@immutable
class ScoutingShellRoute extends ShellRouteData {
  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) async {
    if (!UserMetadata.signedIn) {
      return const LandingRoute().location;
    }
    if (!await UserMetadata.isValid) {
      return const MetadataRoute(redir: false).location;
    }
    return null;
  }

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) =>
      ScaffoldShell(navigator);
}

@immutable
class PitScoutRoute extends GoRouteData with _$PitScoutRoute {
  final int season;
  final String event;
  const PitScoutRoute(this.season, this.event);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PitScoutPage(season: season, event: event);
}

final _matchCodeParamPattern =
    RegExp(r"^(?<season>\d{4})(?<event>[A-z\d]+)_(?<match>.+?)_(?<team>\d{1,5}[A-Z]?)$");

@immutable
class MatchScoutRoute extends GoRouteData with _$MatchScoutRoute {
  // This must be a string, because go_router_builder doesnt know what to do with a MatchInfo
  final String matchCode;
  const MatchScoutRoute({required this.matchCode});

  MatchScoutPage? fromCode(String matchCode) {
    var match = _matchCodeParamPattern.firstMatch(matchCode);
    if (match != null) {
      try {
        return MatchScoutPage((
          season: int.parse(match.namedGroup("season")!),
          event: match.namedGroup("event")!,
          match: MatchInfo.fromString(match.namedGroup("match")!),
          team: match.namedGroup("team")!
        ));
      } catch (_) {}
    }
    return null;
  }

  // BlueAlliance.validate(initial)

  @override
  Widget build(BuildContext context, GoRouterState state) => fromCode(matchCode)!;
}

@immutable
class SavedResponsesRoute extends GoRouteData with _$SavedResponsesRoute {
  const SavedResponsesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => SavedResponsesPage();
}

extension GoLater on GoRouteData {
  VoidCallback goLater(BuildContext context) {
    final router = GoRouter.of(context);
    return () => router.go(location);
  }
}
