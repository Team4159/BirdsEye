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

  static Future<void> setSession({String? match, int? team}) =>
      Supabase.instance.client.from("sessions").upsert({
        "season": Configuration.instance.season,
        "event": Configuration.event,
        "match": match,
        "team": team
      }).then((_) {});

  static Future<void> clearSession() => Supabase.instance.client.from("sessions").delete();

  static Future<Map<int, int>> getSessions({required String match}) => Supabase.instance.client
      .from("sessions")
      .select<List<Map<String, dynamic>>>("team")
      .eq("season", Configuration.instance.season)
      .eq("event", Configuration.event)
      .eq("match", match)
      .neq("scouter", Supabase.instance.client.auth.currentUser!.id)
      .then((resp) => resp.map((e) => e['team'] as int).toList())
      .then((sessions) => Map.fromEntries(
          sessions.toSet().map((team) => MapEntry(team, sessions.where((t) => t == team).length))));

  static final matchscoutStock = Stock<int, MatchScoutQuestionSchema>(
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client
              .rpc('gettableschema', params: {"tablename": "${key}_match"}).then((resp) {
            Map<String, String> raw = Map.from(resp);
            raw.removeWhere((key, value) => {"event", "match", "team", "scouter"}.contains(key));
            MatchScoutQuestionSchema matchSchema = {};
            for (var MapEntry(key: columnname, value: sqltype) in raw.entries) {
              List<String> components = columnname.split('_');
              if (matchSchema[components.first] == null) {
                matchSchema[components.first] = {};
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
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client
              .rpc('gettableschema', params: {"tablename": "${key}_pit"}).then((resp) async {
            Iterable<String> raw = Map<String, String>.from(resp)
                .keys
                .where((key) => !{"event", "match", "team", "scouter"}.contains(key));
            Map<String, String> questions = await pitscoutquestionStock.get(null);
            if (raw.any((e) => !questions.containsKey(e))) {
              questions = await pitscoutquestionStock.fresh(null);
            }
            return Map.fromEntries(raw.map((e) => MapEntry(e, questions[e] ?? e)));
          })),
      sourceOfTruth: CachedSourceOfTruth());

  static final pitscoutquestionStock = Stock<void, Map<String, String>>(
      fetcher: Fetcher.ofFuture((_) => Supabase.instance.client
          .from("pit_questions")
          .select<List<Map<String, dynamic>>>()
          .then((resp) =>
              Map.fromEntries(resp.map((e) => MapEntry(e["columnname"], e["question"]))))));

  static Future<Map<String, String>> get pitSchema async => await canConnect
      ? pitscoutStock.fresh(Configuration.instance.season)
      : pitscoutStock.get(Configuration.instance.season);
}
