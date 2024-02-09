import 'dart:collection';

import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/configuration.dart';
import '../pages/matchscout.dart' hide MatchScoutPage;

// "Aren't supabase functions all over the code?" Yes, but here are the ones that require big think
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
          .then((resp) => _availableSeasons = List<int>.from(resp));

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
      .then((resp) => resp.map((e) => e['team']).toList())
      .then((sessions) => Map.fromEntries(
          sessions.toSet().map((team) => MapEntry(team, sessions.where((t) => t == team).length))));

  static final matchscoutStock = Stock<int, MatchScoutQuestionSchema>(
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client
              .rpc('gettableschema', params: {"tablename": "${key}_match"}).then((resp) {
            var schema = (Map<String, dynamic>.from(resp)
                  ..removeWhere((key, _) => {"event", "match", "team", "scouter"}.contains(key)))
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
          .rpc('gettableschema', params: {"tablename": "${season}_pit"}).then((resp) =>
              (LinkedHashMap<String, dynamic>.from(resp)
                    ..removeWhere((key, value) =>
                        {"event", "match", "team", "scouter"}.contains(key) ||
                        value["description"] == null))
                  .map((key, value) => MapEntry(key, value["description"]!)))),
      sourceOfTruth: CachedSourceOfTruth());

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
}

typedef Achievement = ({
  int id,
  String name,
  String description,
  String requirements,
  int points,
  int? season,
  String? event
});
