import 'package:birdseye/pages/configuration.dart';
import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/matchscout.dart' hide MatchScoutPage;

// "Aren't supabase functions all over the code?" Yes, but here are the ones that require big think
class SupabaseInterface {
  static Future<bool> get canConnect => Supabase.instance.client
      .rpc('ping')
      .then((value) => value is DateTime)
      .catchError((_) => false);

  static final matchscoutStock = Stock<int, MatchScoutQuestionSchema>(
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client.rpc(
              'gettableschema',
              params: {"tablename": "${key}_match"}).then((resp) {
            Map<String, String> raw = Map.from(resp);
            raw.removeWhere((key, value) =>
                {"event", "match", "team", "scouter"}.contains(key));
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

  static Future<MatchScoutQuestionSchema> get matchSchema async =>
      await canConnect
          ? matchscoutStock.fresh(Configuration.instance.season)
          : matchscoutStock.get(Configuration.instance.season);

  static final pitscoutStock = Stock<int, Map<String, String>>(
      fetcher: Fetcher.ofFuture((key) => Supabase.instance.client.rpc(
              'gettableschema',
              params: {"tablename": "${key}_pit"}).then((resp) async {
            Iterable<String> raw = Map<String, String>.from(resp).keys.where(
                (key) => !{"event", "match", "team", "scouter"}.contains(key));
            Map<String, String> questions =
                await pitscoutquestionStock.get(null);
            if (raw.any((e) => !questions.containsKey(e))) {
              questions = await pitscoutquestionStock.fresh(null);
            }
            return Map.fromEntries(
                raw.map((e) => MapEntry(e, questions[e] ?? e)));
          })),
      sourceOfTruth: CachedSourceOfTruth());

  static final pitscoutquestionStock = Stock<void, Map<String, String>>(
      fetcher: Fetcher.ofFuture((_) => Supabase.instance.client
          .from("pit_questions")
          .select<List<Map<String, dynamic>>>()
          .then((resp) => Map.fromEntries(
              resp.map((e) => MapEntry(e["columnname"], e["question"]))))));

  static Future<Map<String, String>> get pitSchema async => await canConnect
      ? pitscoutStock.fresh(Configuration.instance.season)
      : pitscoutStock.get(Configuration.instance.season);
}
