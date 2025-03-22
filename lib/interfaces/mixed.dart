import 'dart:collection' show LinkedHashMap;

import '../interfaces/bluealliance.dart' show BlueAlliance, MatchInfo, TBAInfo;
import '../interfaces/localstore.dart';
import '../interfaces/supabase.dart';
import '../types.dart';
import 'package:stock/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MixedInterfaces {
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
              .map((evententry) =>
                  Map<String, dynamic>.from(evententry.value) // match: {scoretype: aggregate_value}
                      .map((matchstring, matchscores) => MapEntry(
                          (event: evententry.key, match: MatchInfo.fromString(matchstring)),
                          Map<String, num>.from(matchscores) // scoretype: aggregate_value
                          )))
              .expand((e) => e.entries));
          // (String event, MatchInfo info): {scoretype: aggregate_value}
        }
        throw UnimplementedError("No aggregate for that combination");
      }));

  static Future<void> submitMatchResponse(MatchScoutInfoSerialized info, Map<String, dynamic> data,
          [Function(Exception)? onError]) =>
      Supabase.instance.client
          .from("match_scouting")
          .insert(
              {"season": info.season, "event": info.event, "match": info.match, "team": info.team})
          .select("id")
          .single()
          .then((r) => Supabase.instance.client
              .from("match_data_${info.season}")
              .insert(data..["id"] = r["id"]))
          .catchError((e) => LocalStoreInterface.addMatch(info, data).then((_) => Future.error(e)));

  static Future<List<int>> getPitUnscoutedTeams(int season, String event) => BlueAlliance.stock
          .get(TBAInfo(season: season, event: event, match: "*"))
          .then((data) => Set<int>.of(data.keys.map(int.parse)))
          .then((teams) async {
        Set<int> filledteams = await Supabase.instance.client
            .from("pit_scouting")
            .select("team")
            .eq("season", season)
            .eq("event", event)
            .withConverter((value) => value.map<int>((e) => e['team']).toSet())
            .catchError((_) => <int>{});
        return teams.difference(filledteams).toList()..sort();
      });

  static Future<void> submitPitResponse(PitScoutInfoSerialized info, Map<String, dynamic> data) =>
      PitInterface.pitResponseUpsert(info, data)
          .catchError((e) => LocalStoreInterface.addPit(info, data).then((_) => Future.error(e)));
}
