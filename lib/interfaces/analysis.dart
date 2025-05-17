import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Analysis {
  static Future<Map<String, dynamic>> _getJson(String path) => Supabase.instance.client.functions
      .invoke("analysis/$path", method: HttpMethod.get)
      .then((resp) => resp.status < 400 ? Map.from(resp.data) : throw Exception(resp.data));

  static Future<Map<String, dynamic>> matchEPA(int season, String event, MatchInfo match) =>
      _getJson("season/$season/event/$event/match/$match/epa");
}

// typedef MatchEPA = ({AlliancePrediction red, AlliancePrediction blue, bool isMissingData});

// typedef AlliancePrediction = ({
//   double winChance,
//   double points,
//   Map<String, double> rp,
//   List<String> teams
// });

// const routes = {
//   true: {
//     "match": {
//       "*": "/matches",
//       true: "/match/$match/epa"
//     },
//     "robot": {
//       "matches": "/matches",
//       "epa": "/epa"
//     },
//     false: "/rankings"
//   },
//   false: {
//     "matches": "/matches",
//     "epa": "/epa"
//   }
// }
