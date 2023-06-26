import 'package:birdseye/pages/configuration.dart';
import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/matchscout.dart' hide MatchScoutPage;

class SupabaseInterface {
  static Future<bool> get canConnect => Supabase.instance.client
      .rpc('ping')
      .then((value) => value is DateTime)
      .catchError((_) => false);

  static final Stock<int, MatchScoutQuestionSchema> matchscoutStock =
      Stock<int, MatchScoutQuestionSchema>(
          fetcher: Fetcher.ofFuture((key) => Supabase.instance.client.rpc(
                  'gettableschema',
                  params: {"tablename": "${key}_match"}).then((resp) {
                Map<String, String> raw = Map.castFrom(resp);
                raw.removeWhere((key, value) =>
                    {"event", "match", "team", "scouter"}.contains(key));
                MatchScoutQuestionSchema matchSchema = {};
                for (var MapEntry(key: columnname, value: sqltype)
                    in raw.entries) {
                  List<String> components = columnname.split('_');
                  if (matchSchema[components.first] == null) {
                    matchSchema[components.first] = {};
                  }
                  matchSchema[components.first]![components
                          .sublist(1)
                          .map((s) => s[0].toUpperCase() + s.substring(1))
                          .join(" ")] =
                      MatchScoutQuestionTypes.fromSQLType(sqltype);
                }
                return matchSchema;
              })),
          sourceOfTruth: CachedSourceOfTruth());

  static Future<MatchScoutQuestionSchema> get matchSchema async =>
      await canConnect
          ? matchscoutStock.fresh(Configuration.instance.season)
          : matchscoutStock.get(Configuration.instance.season);
}
