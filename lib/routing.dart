import 'dart:async' show FutureOr;

import 'package:birdseye/usermetadata.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'interfaces/bluealliance.dart' show BlueAlliance, MatchInfo;
import 'interfaces/sharedprefs.dart';
import 'pages/achievements.dart';
import 'pages/configuration.dart';
import 'pages/landing.dart';
import 'pages/legal.dart';
import 'pages/matchscouting/matchscout.dart';
import 'pages/metadata.dart';
import 'pages/pitscout.dart';
import 'pages/savedresponses.dart';
import 'pages/scoutingshell.dart';

part 'routing.g.dart';

final appRouter = GoRouter(routes: $appRoutes, initialLocation: '/');

@TypedGoRoute<LandingRoute>(path: '/')
@immutable
class LandingRoute extends GoRouteData with _$LandingRoute {
  const LandingRoute();

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (state.uri.path == location && (UserMetadata.read(context)?.isSignedIn ?? false)) {
      return const MetadataRoute(redir: true).location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => const LandingPage();
}

@TypedShellRoute<LegalShellRoute>(
  routes: [
    TypedGoRoute<LegalPrivacyRoute>(path: '/legal/privacy'),
    TypedGoRoute<LegalTermsRoute>(path: '/legal/terms'),
    TypedGoRoute<LegalCookiesRoute>(path: '/legal/cookies'),
  ],
)
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

@TypedGoRoute<MetadataRoute>(path: '/metadata', caseSensitive: false)
@immutable
class MetadataRoute extends GoRouteData with _$MetadataRoute implements Navigable {
  /// whether or not to check if metadata is already available, and skip the metadata page if so
  final bool redir;
  const MetadataRoute({this.redir = false});

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.app_registration_outlined),
    label: Text("Metadata"),
  );

  @override
  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final userMeta = UserMetadata.of(context);
    if (!userMeta.isSignedIn) {
      return const LandingRoute().location;
    }
    if (!redir) return null;
    if (userMeta.hasMeta && await BlueAlliance.isKeyValid(SharedPreferencesInterface.tbakey)) {
      return const ConfigurationRoute().location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => MetadataPage();
}

final shellNavigatorKey = GlobalKey<NavigatorState>();

@TypedShellRoute<ScoutingShellRoute>(
  routes: [
    TypedGoRoute<ConfigurationRoute>(path: '/configuration', caseSensitive: false),
    TypedGoRoute<PitScoutRoute>(path: '/pitscout', caseSensitive: false),
    TypedGoRoute<MatchScoutRoute>(path: '/matchscout', caseSensitive: false),
    TypedGoRoute<SavedResponsesRoute>(path: '/savedresponses', caseSensitive: false),
    TypedGoRoute<AchievementsRoute>(path: '/achievements', caseSensitive: false),
  ],
)
@immutable
class ScoutingShellRoute extends ShellRouteData {
  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) async {
    var userMeta = UserMetadata.of(context);
    if (!userMeta.isSignedIn) {
      return const LandingRoute().location;
    }
    if (!userMeta.hasMeta || !await BlueAlliance.isKeyValid(SharedPreferencesInterface.tbakey)) {
      return const MetadataRoute(redir: false).location;
    }
    return null;
  }

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) =>
      ScaffoldShell(navigator);
}

@immutable
class ConfigurationRoute extends GoRouteData with _$ConfigurationRoute implements Navigable {
  const ConfigurationRoute();

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.settings_rounded),
    label: Text("Configuration"),
  );

  @override
  Widget build(BuildContext context, GoRouterState state) => ConfigurationPage();
}

@immutable
class PitScoutRoute extends GoRouteData with _$PitScoutRoute implements Navigable {
  final int? season;
  final String? event;
  PitScoutRoute({this.season, this.event});

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.list_rounded),
    label: Text("Pit Scouting"),
  );

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (SharedPreferencesInterface.event == null) return const ConfigurationRoute().location;
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => PitScoutPage(
    season: season ?? SharedPreferencesInterface.season,
    event: event ?? SharedPreferencesInterface.event!,
  );
}

final _matchCodeParamPattern = RegExp(
  r"^(?<season>\d{4})(?<event>[A-z\d]+)_(?<match>.+?)_(?<team>\d{1,5}[A-Z]?)$",
);

@immutable
class MatchScoutRoute extends GoRouteData with _$MatchScoutRoute implements Navigable {
  final String? matchCode;
  const MatchScoutRoute({this.matchCode});

  MatchScoutPage fromCode(String? matchCode) {
    if (matchCode != null) {
      var match = _matchCodeParamPattern.firstMatch(matchCode);
      if (match != null) {
        try {
          // lowpriority Validate BlueAlliance.validate(initial)
          return MatchScoutPage((
            season: int.parse(match.namedGroup("season")!),
            event: match.namedGroup("event")!,
            match: MatchInfo.fromString(match.namedGroup("match")!),
            team: match.namedGroup("team")!,
          ));
        } catch (_) {}
      }
    }
    return MatchScoutPage((
      season: SharedPreferencesInterface.season,
      event: SharedPreferencesInterface.event!,
      match: null,
      team: null,
    ));
  }

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.assignment_rounded),
    label: Text("Match Scouting"),
  );

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (SharedPreferencesInterface.event == null) return const ConfigurationRoute().location;
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => fromCode(matchCode);
}

@immutable
class SavedResponsesRoute extends GoRouteData with _$SavedResponsesRoute implements Navigable {
  const SavedResponsesRoute();

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.download_for_offline_rounded),
    label: Text("Saved Responses"),
  );

  @override
  Widget build(BuildContext context, GoRouterState state) => const SavedResponsesPage();
}

@immutable
class AchievementsRoute extends GoRouteData with _$AchievementsRoute implements Navigable {
  final int season;
  final String? event;
  AchievementsRoute()
    : season = SharedPreferencesInterface.season,
      event = SharedPreferencesInterface.event;

  @override
  get destination => const NavigationDrawerDestination(
    icon: Icon(Icons.emoji_events_rounded),
    label: Text("Achievements"),
  );

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (event == null) return const ConfigurationRoute().location;
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AchievementsPage(season: season, event: event!);
}

abstract class Navigable extends GoRouteData {
  NavigationDrawerDestination get destination;
}
