import 'dart:collection';

import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/configuration.dart';
import '../pages/matchscout.dart' hide MatchScoutPage;
import 'bluealliance.dart' show MatchInfo;

typedef AggInfo = ({int season, String? event, String? team});

// "Aren't supabase functions all over the code?" Yes, but here are the ones that require big think (and big caching)
class SupabaseInterface {
  static Future<bool> get canConnect => Supabase.instance.client
      .rpc('ping')
      .timeout(const Duration(seconds: 5))
      .then((_) => true)
      .catchError((_) => false);

  static List<int>? _availableSeasons;
  static Future<List<int>> getAvailableSeasons() => _availableSeasons != null
      ? Future.value(_availableSeasons)
      : Supabase.instance.client
          .rpc("getavailableseasons")
          .then((resp) => _availableSeasons = List<int>.from(resp, growable: false));

  static Future<void> setSession({String? match, String? team}) =>
      Supabase.instance.client.from("sessions").upsert({
        "season": Configuration.instance.season,
        "event": Configuration.event,
        "match": match,
        "team": team
      }).then((_) {});

  static Future<void> clearSession() => Supabase.instance.client.from("sessions").delete();

  static Future<Map<String, int>> getSessions({required String match}) => Supabase.instance.client
          .from("sessions")
          .select("team")
          .eq("season", Configuration.instance.season)
          .eq("event", Configuration.event!)
          .eq("match", match)
          .neq("scouter", Supabase.instance.client.auth.currentUser!.id)
          .gte('updated', DateTime.now().subtract(const Duration(minutes: 5)))
          .withConverter((resp) {
        var sessions = resp.map((e) => e['team']);
        return Map.fromEntries(sessions
            .toSet()
            .map((team) => MapEntry(team, sessions.where((t) => t == team).length)));
      });

  static final matchscoutStock = Stock<int, MatchScoutQuestionSchema>(
      fetcher: Fetcher.ofFuture((season) => Supabase.instance.client
              .rpc('gettableschema', params: {"tablename": "match_data_$season"}).then((resp) {
            var schema = (Map<String, dynamic>.from(resp)..remove("id"))
                .map((key, value) => MapEntry(key, value["type"]!));
            MatchScoutQuestionSchema matchSchema = LinkedHashMap();
            for (var MapEntry(key: columnname, value: sqltype) in schema.entries) {
              List<String> components = columnname.split('_');
              if (matchSchema[components.first] == null) {
                // ignore: prefer_collection_literals
                matchSchema[components.first] = LinkedHashMap<String, MatchScoutQuestionTypes>();
              }
              matchSchema[components.first]![components.sublist(1).join("_")] =
                  MatchScoutQuestionTypes.fromSQLType(sqltype);
            }
            return matchSchema;
          })),
      sourceOfTruth: CachedSourceOfTruth());

  static Future<MatchScoutQuestionSchema> get matchSchema async => await canConnect
      ? matchscoutStock.fresh(Configuration.instance.season)
      : matchscoutStock.get(Configuration.instance.season);

  static final pitscoutStock = Stock<int, Map<String, String>>(
    fetcher: Fetcher.ofFuture((season) => Supabase.instance.client
        .from("pit_scouting_season_questions")
        .select('pit_scouting_questions.q_id, pit_scouting_questions.question')
        .innerJoin('pit_scouting_questions', 'pit_scouting_season_questions.q_id = pit_scouting_questions.q_id')
        .eq('season', season)
        .then((resp) => Map.fromIterable(
              resp,
              key: (entry) => entry["q_id"].toString(),
              value: (entry) => entry["question"] as String,
            ))),
    sourceOfTruth: CachedSourceOfTruth(),
  );



  static Future<Map<String, String>> get pitSchema async => await canConnect
      ? pitscoutStock.fresh(Configuration.instance.season)
      : pitscoutStock.get(Configuration.instance.season);

  static Set<Achievement>? _achievements;
  static Future<Set<Achievement>?> get achievements async =>
      (_achievements == null && await canConnect)
          ? Supabase.instance.client
              .from("achievements")
              .select("*")
              .withConverter((resp) => resp
                  .map((record) => (
                        id: record["id"] as int,
                        name: record["name"] as String,
                        description: record["description"] as String,
                        requirements: record["requirements"] as String,
                        points: record["points"] as int,
                        season: record["season"] as int?,
                        event: record["event"] as String?
                      ))
                  .toSet())
              .then((data) => _achievements = data)
          : Future.value(_achievements);
  static void clearAchievements() => _achievements = null;

  static final matchAggregateStock = Stock<AggInfo, LinkedHashMap<dynamic, Map<String, num>>>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) async {
        assert(key.event != null || key.team != null);
        var response = LinkedHashMap<String, dynamic>.from(await Supabase.instance.client.functions
                .invoke("match_aggregator_js", body: {
                  "season": key.season,
                  if (key.event != null) "event": key.event,
                  if (key.team != null) "team": key.team
                })
                .then((resp) =>
                    resp.status >= 400 ? throw Exception("HTTP Error ${resp.status}") : resp.data)
                .catchError((e) => e is FunctionException && e.status == 404 ? {} : throw e))
            .map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
        if (key.event != null && key.team != null) {
          return LinkedHashMap<MatchInfo, Map<String, num>>.of(
              response.map((k, v) => MapEntry(MatchInfo.fromString(k), Map.from(v[key.team]))));
          // match: {scoretype: aggregated_count}
        }
        if (key.team != null) {
          return LinkedHashMap.fromEntries(response.entries
              .map((evententry) => Map<String, dynamic>.from(evententry.value).map(
                  (matchstring, matchscores) => MapEntry(
                      (event: evententry.key, match: MatchInfo.fromString(matchstring)),
                      Map<String, num>.from(matchscores))))
              .expand((e) => e.entries));
        }
        throw UnimplementedError("No aggregate for that combination");
      }));

  static final pitAggregateStock =
      Stock<({int season, String event, int team}), LinkedHashMap<String, String>>(
          sourceOfTruth: CachedSourceOfTruth(),
          fetcher: Fetcher.ofFuture((key) => Supabase.instance.client
                  .from("pit_data_${key.season}")
                  .select("*")
                  .eq("event", key.event)
                  .eq("team", key.team)
                  .then((resp) => resp.map((e) =>(e
                    ..removeWhere((key, value) =>
                        {"event", "match", "team", "scouter"}.contains(key) || value is! String))
                    .map<String, String>((key, value) => MapEntry(key, value as String))))
                  .then((map) => map.isEmpty
                      ? LinkedHashMap<String, String>()
                      : LinkedHashMap.of(map.reduce(
                          (c, v) => c.map((key, value) => MapEntry(key, "$value\n${v[key]}")))))));

  static final eventAggregateStock = Stock<
          ({int season, String event, EventAggregateMethod method}), LinkedHashMap<String, double>>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client.functions
              .invoke("event_aggregator", body: {
            "season": key.season,
            "event": key.event,
            "method": key.method.name
          }).then((resp) => resp.status >= 400
                  ? throw Exception("HTTP Error ${resp.status}")
                  : LinkedHashMap.fromEntries((Map<String, double?>.from(resp.data)
                        ..removeWhere((key, value) => value == null))
                      .cast<String, double>()
                      .entries
                      .toList()
                    ..sort((a, b) => a.value == b.value
                        ? 0
                        : a.value > b.value
                            ? -1
                            : 1)))));

  static final distinctStock = Stock<
          AggInfo,
          ({
            Set<String> scouters,
            Set<String> eventmatches,
            Set<String> events,
            Set<String> matches,
            Set<String> teams
          })>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) {
        var q =
            Supabase.instance.client.from("match_scouting").select("*").eq("season", key.season);
        if (key.event != null) q = q.eq("event", key.event!);
        if (key.team != null) q = q.eq("team", key.team!);
        return q.withConverter((data) => (
              scouters: data.map<String>((e) => e["scouter"]).toSet(),
              eventmatches: data.map<String>((e) => e["event"] + e["match"]).toSet(),
              events: data.map<String>((e) => e["event"]).toSet(),
              matches: data.map<String>((e) => e["match"]).toSet(),
              teams: data.map<String>((e) => e["team"]).toSet()
            ));
      }));
}

enum EventAggregateMethod { defense, accuracy }

typedef Achievement = ({
  int id,
  String name,
  String description,
  String requirements,
  int points,
  int? season,
  String? event
});
