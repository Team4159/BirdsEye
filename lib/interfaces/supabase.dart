import 'dart:collection';

import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../types.dart';

/// A container for complex and/or cached database interactions
class SupabaseInterface {
  /// Checks if the database is accessible.
  static Future<bool> get canConnect => Supabase.instance.client
      .rpc('ping')
      .timeout(const Duration(seconds: 5))
      .then((_) => true)
      .catchError((_) => false);

  static List<int>? _availableSeasons;

  /// Fetches a list of all seasons with available tables.
  static Future<List<int>> getAvailableSeasons() => _availableSeasons != null
      ? Future.value(_availableSeasons)
      : Supabase.instance.client
          .rpc("getavailableseasons")
          .then((resp) => _availableSeasons = List<int>.from(resp, growable: false));

  /// Sets the current activity the user is doing.
  static Future<void> setSession(MatchScoutIdentifierPartial identifier) =>
      Supabase.instance.client.from("sessions").upsert({
        "season": identifier.season,
        "event": identifier.event,
        "match": identifier.match?.toString(),
        "team": identifier.team
      }).then((_) {});

  /// Clears the current activity the user is doing.
  static Future<void> clearSession() => Supabase.instance.client.from("sessions").delete();

  /// Fetches the current activities of other users.
  static Future<Map<String, int>> getSessions(
          {required int season, required String event, required String match}) =>
      Supabase.instance.client
          .from("sessions")
          .select("team")
          .eq("season", season)
          .eq("event", event)
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

  /// Clears the in-memory achievement cache, forcing a fresh fetch next time
  static void clearAchievements() => _achievements = null;

  static final eventAggregateStock = Stock<
          ({int season, String event, EventAggregateMethod method}), LinkedHashMap<String, double>>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client.functions
              .invoke("event_aggregator", body: {
            "season": key.season,
            "event": key.event,
            "mode": key.method.name
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

/// A container for all pit-scouting related database interactions
class PitInterface {
  static final pitscoutStock = Stock<int, Map<String, String>>(
      fetcher: Fetcher.ofFuture((season) async => LinkedHashMap<String, String>.from(
          await Supabase.instance.client.rpc('getpitschema', params: {"pitseason": season}))),
      sourceOfTruth: CachedSourceOfTruth());

  static Future<List<Map<String, String>>> pitResponseFetch(PitScoutIdentifier info,
      [String? scouter]) {
    var request = Supabase.instance.client
        .from("pit_scouting")
        .select("data")
        .eq("season", info.season)
        .eq("event", info.event)
        .eq("team", info.team);
    if (scouter != null) request = request.eq("scouter", scouter);
    return request
        .withConverter((resp) => resp.map((row) => Map<String, String>.from(row["data"])).toList());
  }

  static Future<void> pitResponseUpsert(PitScoutIdentifier info, Map<String, dynamic> data) =>
      Supabase.instance.client
          .from("pit_scouting")
          .upsert({"season": info.season, "event": info.event, "team": info.team, "data": data});

  static final pitAggregateStock = Stock<PitScoutIdentifier, LinkedHashMap<String, String>>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) => pitResponseFetch(key).then((map) => map.isEmpty
          ? LinkedHashMap<String, String>()
          : LinkedHashMap<String, String>.of(
              map.reduce((c, v) => c.map((key, value) => MapEntry(key, "$value\n${v[key]}")))))));
}

enum EventAggregateMethod { defense }
