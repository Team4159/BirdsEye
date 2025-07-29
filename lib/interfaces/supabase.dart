import 'dart:collection';

import 'package:birdseye/interfaces/bluealliance.dart' show MatchInfo;
import 'package:birdseye/interfaces/localstore.dart'
    show PitScoutIdentifier, LocalStoreInterface, MatchScoutIdentifier;
import 'package:birdseye/pages/achievements.dart' show Achievement;
import 'package:birdseye/pages/matchscouting/form.dart'
    show MatchScoutQuestionTypes, MatchScoutQuestionSchema;
import 'package:http/http.dart';
import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A container for complex and/or cached database interactions
class SupabaseInterface {
  /// Checks if the database is accessible.
  static Future<bool> get canConnect => Supabase.instance.client
      .rpc('ping')
      .timeout(const Duration(seconds: 5))
      .then((_) => true)
      .onError((_, _) => false);

  static List<int>? _availableSeasons;

  /// Fetches a list of all seasons with available tables.
  static Future<List<int>> getAvailableSeasons() => _availableSeasons != null
      ? Future.value(_availableSeasons)
      : Supabase.instance.client
            .rpc("getavailableseasons")
            .then((resp) => _availableSeasons = List<int>.from(resp, growable: false));

  /// Sets the current activity the user is doing.
  static Future<void> setSession(
    ({int season, String event, MatchInfo? match, String? team}) identifier,
  ) => Supabase.instance.client
      .from("sessions")
      .upsert({
        "season": identifier.season,
        "event": identifier.event,
        "match": identifier.match?.toString(),
        "team": identifier.team,
      })
      .then((_) {})
      .catchError((_) {});

  /// Clears the current activity the user is doing.
  static Future<void> clearSession() => Supabase.instance.client.from("sessions").delete();

  /// Fetches the current activities of other users.
  static Future<Map<String, int>> getSessions({
    required int season,
    required String event,
    required String match,
  }) => Supabase.instance.client
      .from("sessions")
      .select("team")
      .eq("season", season)
      .eq("event", event)
      .eq("match", match)
      .neq("scouter", Supabase.instance.client.auth.currentUser!.id)
      .gte('updated', DateTime.now().subtract(const Duration(minutes: 5)))
      .withConverter((resp) {
        var sessions = resp.map((e) => e['team']);
        return Map.fromEntries(
          sessions.toSet().map((team) => MapEntry(team, sessions.where((t) => t == team).length)),
        );
      });

  static final matchSchemaStock = Stock<int, MatchScoutQuestionSchema>(
    fetcher: Fetcher.ofFuture(
      (season) => Supabase.instance.client
          .rpc('gettableschema', params: {"tablename": "match_data_$season"})
          .then((resp) {
            var schema = (Map<String, dynamic>.from(
              resp,
            )..remove("id")).map((key, value) => MapEntry(key, value["type"]!));
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
          }),
    ),
    sourceOfTruth: CachedSourceOfTruth(),
  );

  static Future<void> matchResponseSubmit(
    MatchScoutIdentifier info,
    Map<String, dynamic> data, [
    Function(Exception)? onError,
  ]) => Supabase.instance.client
      .from("match_scouting")
      .insert({
        "season": info.season,
        "event": info.event,
        "match": info.match.toString(),
        "team": info.team,
      })
      .select("id")
      .single()
      .then(
        (r) => Supabase.instance.client
            .from("match_data_${info.season}")
            .insert(data..["id"] = r["id"]),
      )
      .onError<Object>((e, _) async {
        await LocalStoreInterface.addMatch(info, data);
        throw e;
      })
      .onError<ClientException>((_, _) => throw "Offline!");

  static Set<Achievement>? _achievements;
  static Future<Set<Achievement>?> get achievements async =>
      (_achievements == null && await canConnect)
      ? Supabase.instance.client
            .from("achievements")
            .select("*")
            .withConverter(
              (resp) => resp
                  .map(
                    (record) => (
                      id: record["id"] as int,
                      name: record["name"] as String,
                      description: record["description"] as String,
                      requirements: record["requirements"] as String,
                      points: record["points"] as int,
                      season: record["season"] as int?,
                      event: record["event"] as String?,
                    ),
                  )
                  .toSet(),
            )
            .then((data) => _achievements = data)
      : Future.value(_achievements);
}

/// A container for all pit-scouting related database interactions
class PitInterface {
  static final pitSchemaStock = Stock<int, Map<String, String>>(
    fetcher: Fetcher.ofFuture(
      (season) async => LinkedHashMap<String, String>.from(
        await Supabase.instance.client.rpc('getpitschema', params: {"pitseason": season}),
      ),
    ),
    sourceOfTruth: CachedSourceOfTruth(),
  );

  static Future<List<Map<String, String>>> pitResponseFetch(
    PitScoutIdentifier info, [
    String? scouter,
  ]) {
    var request = Supabase.instance.client
        .from("pit_scouting")
        .select("data")
        .eq("season", info.season)
        .eq("event", info.event)
        .eq("team", info.team);
    if (scouter != null) request = request.eq("scouter", scouter);
    return request.withConverter(
      (resp) => resp.map((row) => Map<String, String>.from(row["data"])).toList(growable: false),
    );
  }

  static Future<void> pitResponseSubmit(PitScoutIdentifier info, Map<String, dynamic> data) =>
      Supabase.instance.client
          .from("pit_scouting")
          .upsert({"season": info.season, "event": info.event, "team": info.team, "data": data})
          .onError<Object>((e, _) async {
            await LocalStoreInterface.addPit(info, data);
            throw e;
          })
          .onError<ClientException>((_, _) => throw "Offline!");

  static Future<Set<int>> getPitScoutedTeams(int season, String event) => Supabase.instance.client
      .from("pit_scouting")
      .select("team")
      .eq("season", season)
      .eq("event", event)
      .withConverter((value) => value.map<int>((e) => e['team']).toSet())
      .onError((_, _) => <int>{});
}

enum EventAggregateMethod { defense }
