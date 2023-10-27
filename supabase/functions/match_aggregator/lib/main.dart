import 'dart:io' show HttpStatus;

import 'package:edge_http_client/edge_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_functions/supabase_functions.dart';

void main() {
  final supabase = SupabaseClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // Use service role key to bypass RLS
    httpClient: EdgeHttpClient(),
  );

  SupabaseFunctions(fetch: (request) async {
    // Request Argument Validation
    Map<String, String> params = request.url.queryParameters;
    if (!params.containsKey("season") || !params.containsKey("event")) {
      return Response(
          "Missing Required Parameters\nseason: valid frc season year (e.g. 2023)\nevent: valid tba event code (e.g. casf)",
          status: HttpStatus.badRequest);
    }
    // Database Fetching
    List<Map<String, dynamic>> data = await supabase
        .from("${params['season']}_match")
        .select<List<Map<String, dynamic>>>()
        .eq("event", params["event"]);
    if (data.isEmpty) {
      return Response("No Data Found for ${params['season']}${params['event']}",
          status: HttpStatus.notFound);
    }
    if (params.containsKey("type") && params["type"] == "text") {
      // Data Aggregation
      Map<int, Map<String, Map<String, String>>> agg = {}; // {team: {match: {question: value}}}
      for (Map<String, dynamic> scoutingEntry in data) {
        int team = int.parse(scoutingEntry["team"]);
        if (agg[team] == null) agg[team] = {};
        String match = scoutingEntry['match'];
        if (agg[team]![match] == null) agg[team]![match] = {};
        String? scouter = scoutingEntry["scouter"];
        scoutingEntry.removeWhere((key, _) => {"event", "match", "team", "scouter"}.contains(key));
        for (var MapEntry(:key, :value) in scoutingEntry.entries) {
          if (value is! String || value.isEmpty) continue;
          if (agg[team]![match]![key] == null) agg[team]![match]![key] = "";
          agg[team]![match]![key] = "${agg[team]![match]![key]!}\n$scouter: $value";
        }
      }
      // Return
      return Response.json(agg);
    } else {
      // Data Aggregation
      Map<String, Map<int, Map<String, Set<num>>>> agg = {}; // {match: {team: {scoretype: value}}}
      for (Map<String, dynamic> scoutingEntry in data) {
        String match = scoutingEntry['match'];
        if (agg[match] == null) agg[match] = {};
        int team = int.parse(scoutingEntry["team"]);
        if (agg[match]![team] == null) agg[match]![team] = {};
        scoutingEntry.removeWhere((key, _) => {"event", "match", "team", "scouter"}.contains(key));
        for (var MapEntry(:key, :value) in scoutingEntry.entries) {
          if (value is! num) continue;
          if (agg[match]![team]![key] == null) agg[match]![team]![key] = {};
          agg[match]![team]![key]!.add(value);
        }
      }
      // Data Aggregation 2: Electric Boogaloo
      bool isMedian = params.containsKey("mode") && params["mode"] == "median";
      Map<String, Map<int, Map<String, num>>> matches = agg.map((key, value) => MapEntry(
          key,
          value.map((key, value) => MapEntry(
              key,
              value.map((key, value) => MapEntry(
                  key,
                  isMedian
                      ? ((value.toList()..sort())[(value.length / 2).floor()])
                      : value.reduce((v, c) => v + c) / value.length))))));
      // Return
      return Response.json(matches);
    }
  });
}
