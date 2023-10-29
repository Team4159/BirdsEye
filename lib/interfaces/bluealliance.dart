import 'dart:convert' show json;
import 'dart:ui';

import 'package:http/http.dart' show Client;
import 'package:stock/stock.dart';

import '../main.dart' show prefs;
import 'localstore.dart';

final qualificationMatchInfoPattern = RegExp(r'^(?<level>qm)(?<index>\d+)$');
final finalsMatchInfoPattern = RegExp(r'^(?<level>qf|sf|f)(?<finalnum>\d{1,2})m(?<index>\d+)$');

enum MatchLevel {
  qualification(compLevel: "qm"),
  quarterfinals(compLevel: "qf"),
  semifinals(compLevel: "sf"),
  finals(compLevel: "f");

  final String compLevel;
  const MatchLevel({required this.compLevel});
  static fromCompLevel(String s) => MatchLevel.values.firstWhere((type) => type.compLevel == s);
}

typedef MatchInfo = ({MatchLevel level, int? finalnum, int index});
MatchInfo? parseMatchInfo(String? s) {
  if (s == null || s.isEmpty) return null;
  RegExpMatch? match =
      qualificationMatchInfoPattern.firstMatch(s) ?? finalsMatchInfoPattern.firstMatch(s);
  if (match == null) return null;
  return (
    level: MatchLevel.fromCompLevel(match.namedGroup("level")!),
    finalnum: match.groupNames.contains("finalnum")
        ? int.tryParse(match.namedGroup("finalnum") ?? "")
        : null,
    index: int.parse(match.namedGroup("index")!)
  );
}

String stringifyMatchInfo(MatchInfo m) =>
    "${m.level.compLevel}${m.finalnum != null ? '${m.finalnum}m' : ''}${m.index}";

int hashMatchInfo(MatchInfo m) {
  if ((m.finalnum != null && m.finalnum! > 16) || m.index > 256) {
    throw Exception("MatchInfo not hashable - Values too large");
  }
  int out = m.level.index;
  out <<= 4; // finalnum can't be more than 16
  out += m.finalnum ?? 0;
  out <<= 8; // index can't be more than 256
  out += m.index;
  return out; // 00000000 index, 0000 finalnum, 00... level
}

MatchInfo unhashMatchInfo(int h) {
  int index = h & ((1 << 8) - 1);
  h >>= 8;
  int? fnum = h & ((1 << 4) - 1);
  if (fnum == 0) fnum = null;
  h >>= 4;
  int lvl = h;
  if (MatchLevel.values.length <= lvl) throw Exception("MatchInfo not unhashable - Hash too large");
  return (index: index, finalnum: fnum, level: MatchLevel.values[lvl]);
}

int compareMatchInfo(MatchInfo a, MatchInfo b) => a.level != b.level
    ? b.level.index - a.level.index
    : a.finalnum != null && b.finalnum != null && a.finalnum != b.finalnum
        ? b.finalnum! - a.finalnum!
        : b.index - a.index;

enum GamePeriod {
  auto(Color.fromARGB(128, 200, 50, 50)),
  teleop(Color.fromARGB(128, 50, 200, 50)),
  endgame(Color.fromARGB(128, 50, 50, 200)),
  others(Color.fromARGB(128, 50, 50, 50));

  final Color graphColor;
  const GamePeriod(this.graphColor);
}

int scoreTotal(Map<String, int> scores, {required int season, GamePeriod? period}) {
  var entries = scores.entries;
  if (period != null) {
    if (period == GamePeriod.others) {
      for (GamePeriod p in GamePeriod.values) {
        entries = entries.where((e) => !e.key.startsWith("${p.name}_"));
      }
    } else {
      entries = entries.where((e) => e.key.startsWith("${period.name}_"));
    }
  }
  if (entries.isEmpty) return 0;
  return switch (season) {
    2023 => entries
        .where((e) => scoringpoints2023.containsKey(e.key) && e.value != 0)
        .map((e) => scoringpoints2023[e.key]! * e.value)
        .followedBy([0]).reduce((v, e) => v + e),
    _ => throw Exception("Can't total scores - Unrecognized Season")
  };
}

typedef TBAInfo = ({int season, String? event, String? match});
String stringifyTBAInfo(TBAInfo t) =>
    t.season.toString() +
    (t.event != null ? t.event! : "") +
    (t.match != null ? "_${t.match!}" : "");

class BlueAlliance {
  static final _client = Client();

  static DateTime? _lastChecked;
  static bool _dirtyConnected = false;
  static set dirtyConnected(bool d) {
    _dirtyConnected = d;
    _lastChecked = DateTime.now();
  }

  static bool get dirtyConnected {
    if (_lastChecked != null &&
        _lastChecked!.difference(DateTime.now()) < const Duration(seconds: 10)) {
      return _dirtyConnected;
    }
    if (_dirtyConnected) {
      isKeyValid(null);
      return true;
    }
    return false;
  }

  static Future _getJson(String path, {String? key}) => _client
          .get(Uri.https("www.thebluealliance.com", "/api/v3/$path",
              {"X-TBA-Auth-Key": key ?? prefs.getString('tbaKey')}))
          .then(
              (resp) => resp.statusCode < 400 ? json.decode(resp.body) : throw Exception(resp.body))
          .then((n) {
        dirtyConnected = true;
        return n;
      }).catchError((n) {
        dirtyConnected = false;
        throw n;
      });

  static final Set<String> _keyCache = {};
  static Future<bool> isKeyValid(String? key) {
    if (key?.isEmpty ?? true) return Future.value(false);
    if (_keyCache.contains(key)) return Future.value(true);
    return _getJson("status", key: key).then((_) {
      _keyCache.add(key!);
      return true;
    }).catchError((_) => false);
  }

  static final stockSoT = LocalSourceOfTruth("tba");
  static final stock = Stock<TBAInfo, Map<String, String>>(
      sourceOfTruth: stockSoT.mapTo<Map<String, String>>(
          (p) => p.map((k, v) => MapEntry(k, v.toString())), (p) => p),
      fetcher: Fetcher.ofFuture((key) async {
        if (key.event == null) {
          // season
          var data = List<Map<String, dynamic>>.from(await _getJson("events/${key.season}/simple"));
          return Map.fromEntries(data.map((event) => MapEntry(event['event_code'], event['name'])));
        } else if (key.match == null) {
          // event
          var data =
              List<String>.from(await _getJson("event/${key.season}${key.event}/matches/keys"));
          return Map.fromEntries(
              data.map((matchCode) => MapEntry(matchCode.split("_").last, matchCode)));
        } else if (key.match == "*") {
          // match*
          var data =
              List<String>.from(await _getJson("event/${key.season}${key.event}/teams/keys"));
          return Map.fromEntries(data.map((teamCode) => MapEntry(teamCode.substring(3), "*")));
        } else {
          // match
          var data = Map<String, dynamic>.from(
              await _getJson("match/${key.season}${key.event}_${key.match}/simple"));
          Map<String, String> o = {};
          for (MapEntry<String, dynamic> alliance
              in Map<String, dynamic>.from(data['alliances']).entries) {
            for (MapEntry<int, String> team
                in List<String>.from(alliance.value['team_keys']).asMap().entries) {
              if (team.value.substring(3) != "0") {
                o[team.value.substring(3)] = "${alliance.key}${team.key + 1}";
              }
            }
          }
          return o;
        }
      }));

  static Future<void> batchFetch(int season, String event) async {
    var data = List<dynamic>.from(await _getJson("event/$season$event/matches/simple"));
    Map<String, String> matches = {};
    Map<String, String> pitTeams = {};
    for (dynamic matchdata in data) {
      Map<String, String> o = {};
      for (MapEntry<String, dynamic> alliance
          in Map<String, dynamic>.from(matchdata['alliances']).entries) {
        for (MapEntry<int, String> team
            in List<String>.from(alliance.value['team_keys']).asMap().entries) {
          String teamkey = team.value.substring(3);
          if (teamkey != "0") {
            o[teamkey] = "${alliance.key}${team.key + 1}";
            pitTeams[teamkey] = "*";
          }
        }
      }
      String matchkey = (matchdata['key'] as String).split("_").last;
      matches[matchkey] = matchdata['key'];
      await stockSoT.write((season: season, event: event, match: matchkey), o);
    }
    await stockSoT.write((season: season, event: event, match: null), matches);
    await stockSoT.write((season: season, event: event, match: "*"), pitTeams);
  }
}

const scoringpoints2023 = {
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
