import 'dart:io' show HttpStatus;

import 'package:edge_http_client/edge_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_functions/supabase_functions.dart';

final Map<String, int> pointvalues = {
  // 2023 Charged Up
  "auto_cone_low": 3,
  "auto_cone_mid": 4,
  "auto_cone_high": 6,
  "auto_cube_low": 3,
  "auto_cube_mid": 4,
  "auto_cube_high": 6,
  "auto_mobility": 3,
  "auto_docked": 8,
  "auto_engaged": 4,
  "teleop_cone_low": 2,
  "teleop_cone_mid": 3,
  "teleop_cone_high": 5,
  "teleop_cube_low": 2,
  "teleop_cube_mid": 3,
  "teleop_cube_high": 5,
  "endgame_parked": 2,
  "endgame_docked": 6,
  "endgame_engaged": 4,
  "comments_fouls": -5
};
void main() {
  final supabase = SupabaseClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get(
        'SUPABASE_SERVICE_ROLE_KEY')!, // Use service role key to bypass RLS
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
    // Data Aggregation
    Map<String, Map<String, Set<num>>> agg = {}; // {match: {scoretype: value}}
    for (Map<String, dynamic> scoutingEntry in data) {
      String match = scoutingEntry['match'];
      if (agg[match] == null) agg[match] = {};
      scoutingEntry.removeWhere(
          (key, _) => {"event", "match", "team", "scouter"}.contains(key));
      for (var MapEntry(:key, :value) in scoutingEntry.entries) {
        if (value is! int && value is! double) continue;
        if (agg[match]![key] == null) agg[match]![key] = {};
        agg[match]![key]!.add(value);
      }
    }
    // Data Aggregation 2: Electric Boogaloo
    bool isMedian = params.containsKey("mode") && params["mode"] == "median";
    Map<String, Map<String, num>> matches = agg.map((key, value) => MapEntry(
        key,
        value.map((key, value) => MapEntry(
            key,
            isMedian
                ? ((value.toList()..sort())[(value.length / 2).floor()])
                : value.reduce((v, c) => v + c) / value.length))));
    // Return
    return Response.json(matches);
  });
}
