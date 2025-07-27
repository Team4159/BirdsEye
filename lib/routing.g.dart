// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$landingRoute];

RouteBase get $landingRoute => GoRouteData.$route(
  path: '/',

  factory: _$LandingRoute._fromState,
  routes: [
    ShellRouteData.$route(
      factory: $LegalShellRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'legal/privacy',

          factory: _$LegalPrivacyRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'legal/terms',

          factory: _$LegalTermsRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'legal/cookies',

          factory: _$LegalCookiesRoute._fromState,
        ),
      ],
    ),
    GoRouteData.$route(
      path: 'metadata',

      caseSensitive: false,

      factory: _$MetadataRoute._fromState,
    ),
    ShellRouteData.$route(
      navigatorKey: ScoutingShellRoute.$navigatorKey,
      factory: $ScoutingShellRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'configuration',

          caseSensitive: false,

          factory: _$ConfigurationRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'pitscout',

          caseSensitive: false,

          factory: _$PitScoutRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'matchscout',

          caseSensitive: false,

          factory: _$MatchScoutRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'savedresponses',

          caseSensitive: false,

          factory: _$SavedResponsesRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'achievements',

          caseSensitive: false,

          factory: _$AchievementsRoute._fromState,
        ),
      ],
    ),
  ],
);

mixin _$LandingRoute on GoRouteData {
  static LandingRoute _fromState(GoRouterState state) => const LandingRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

extension $LegalShellRouteExtension on LegalShellRoute {
  static LegalShellRoute _fromState(GoRouterState state) => LegalShellRoute();
}

mixin _$LegalPrivacyRoute on GoRouteData {
  static LegalPrivacyRoute _fromState(GoRouterState state) =>
      LegalPrivacyRoute();

  @override
  String get location => GoRouteData.$location('/legal/privacy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$LegalTermsRoute on GoRouteData {
  static LegalTermsRoute _fromState(GoRouterState state) => LegalTermsRoute();

  @override
  String get location => GoRouteData.$location('/legal/terms');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$LegalCookiesRoute on GoRouteData {
  static LegalCookiesRoute _fromState(GoRouterState state) =>
      LegalCookiesRoute();

  @override
  String get location => GoRouteData.$location('/legal/cookies');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$MetadataRoute on GoRouteData {
  static MetadataRoute _fromState(GoRouterState state) => MetadataRoute(
    redir: _$boolConverter(state.uri.queryParameters['redir']!)!,
  );

  MetadataRoute get _self => this as MetadataRoute;

  @override
  String get location => GoRouteData.$location(
    '/metadata',
    queryParams: {'redir': _self.redir.toString()},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

extension $ScoutingShellRouteExtension on ScoutingShellRoute {
  static ScoutingShellRoute _fromState(GoRouterState state) =>
      ScoutingShellRoute();
}

mixin _$ConfigurationRoute on GoRouteData {
  static ConfigurationRoute _fromState(GoRouterState state) =>
      const ConfigurationRoute();

  @override
  String get location => GoRouteData.$location('/configuration');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$PitScoutRoute on GoRouteData {
  static PitScoutRoute _fromState(GoRouterState state) => PitScoutRoute(
    season: _$convertMapValue(
      'season',
      state.uri.queryParameters,
      int.tryParse,
    ),
    event: state.uri.queryParameters['event'],
  );

  PitScoutRoute get _self => this as PitScoutRoute;

  @override
  String get location => GoRouteData.$location(
    '/pitscout',
    queryParams: {
      if (_self.season != null) 'season': _self.season.toString(),
      if (_self.event != null) 'event': _self.event,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$MatchScoutRoute on GoRouteData {
  static MatchScoutRoute _fromState(GoRouterState state) =>
      MatchScoutRoute(matchCode: state.uri.queryParameters['match-code']);

  MatchScoutRoute get _self => this as MatchScoutRoute;

  @override
  String get location => GoRouteData.$location(
    '/matchscout',
    queryParams: {if (_self.matchCode != null) 'match-code': _self.matchCode},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$SavedResponsesRoute on GoRouteData {
  static SavedResponsesRoute _fromState(GoRouterState state) =>
      const SavedResponsesRoute();

  @override
  String get location => GoRouteData.$location('/savedresponses');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$AchievementsRoute on GoRouteData {
  static AchievementsRoute _fromState(GoRouterState state) =>
      AchievementsRoute();

  @override
  String get location => GoRouteData.$location('/achievements');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}
