import 'dart:convert' show json;

import 'package:flutter/material.dart';
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

int compareMatchInfo(MatchInfo a, MatchInfo b) => a.level != b.level
    ? b.level.index - a.level.index
    : a.finalnum != null && b.finalnum != null && a.finalnum != b.finalnum
        ? b.finalnum! - a.finalnum!
        : b.index - a.index;

bool stringMatchIsLevel(String s, MatchLevel l) => s.startsWith(l.compLevel);

typedef TBAInfo = ({int season, String? event, String? match});
String stringifyTBAInfo(TBAInfo t) =>
    t.season.toString() +
    (t.event != null ? t.event! : "") +
    (t.match != null ? "_${t.match!}" : "");

typedef OPRData = ({double? opr, double? dpr, double? ccwms});

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
      // warning: you can get marked disconnected after reconnect because this doesnt recheck
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
          // season -> {eventcode: event name}
          var data = List<Map<String, dynamic>>.from(await _getJson("events/${key.season}/simple"));
          return Map.fromEntries(data.map((event) => MapEntry(event['event_code'], event['name'])));
        } else if (key.match == null) {
          // event -> {matchcode: full match name}
          var data =
              List<String>.from(await _getJson("event/${key.season}${key.event}/matches/keys"));
          return Map.fromEntries(
              data.map((matchCode) => MapEntry(matchCode.split("_").last, matchCode)));
        } else if (key.match == "*") {
          // match* -> {teamcode: *}
          var data =
              List<String>.from(await _getJson("event/${key.season}${key.event}/teams/keys"));
          return Map.fromEntries(data.map((teamCode) => MapEntry(teamCode.substring(3), "*")));
        } else {
          // match -> {teamcode: team position}
          var data = Map<String, dynamic>.from(
              await _getJson("match/${key.season}${key.event}_${key.match}/simple"));
          Map<String, String> o = {};
          for (MapEntry<String, dynamic> alliance
              in Map<String, dynamic>.from(data['alliances']).entries) {
            for (MapEntry<int, String> team in List<String>.from(alliance.value['team_keys'])
                .followedBy(List<String>.from(alliance.value['surrogate_team_keys']))
                .toList(growable: false)
                .asMap()
                .entries) {
              if (team.value.substring(3) != "0") {
                o[team.value.substring(3)] = "${alliance.key}${team.key + 1}";
              }
            }
          }
          assert(o.length == 6, "Incorrect Team Count for ${key.season}${key.event}_${key.match}");
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

  static final _oprStockSoT =
      CachedSourceOfTruth<({int season, String event}), Map<String, OPRData>>();
  static final _oprStock = Stock<({int season, String event}), Map<String, OPRData>>(
      sourceOfTruth: _oprStockSoT,
      fetcher: Fetcher.ofFuture((key) async {
        Map<String, Map<String, double>> data = {};
        Set<String> teams = {};
        for (MapEntry<String, dynamic> methodInfo
            in Map<String, dynamic>.from(await _getJson("event/${key.season}${key.event}/oprs"))
                .entries) {
          var values = Map<String, double>.from(methodInfo.value)
              .map((key, value) => MapEntry(key.substring(3), value));
          data[methodInfo.key] = values;
          teams.addAll(values.keys);
        }
        return Map.fromEntries(teams.map((team) => MapEntry(team,
            (opr: data["oprs"]?[team], dpr: data["dprs"]?[team], ccwms: data["ccwms"]?[team]))));
      }));
  static void refreshOPRs(({int season, String event})? key) =>
      key == null ? _oprStockSoT.deleteAll() : _oprStockSoT.delete(key);
  static Future<OPRData?> getOPR(int season, String event, String team) =>
      _oprStock.get((season: season, event: event)).then((data) => data[team]);
}

enum GamePeriod {
  auto(Color.fromARGB(128, 200, 50, 50)),
  teleop(Color.fromARGB(128, 50, 200, 50)),
  endgame(Color.fromARGB(128, 50, 50, 200)),
  others(Color.fromARGB(128, 50, 50, 50));

  final Color graphColor;
  const GamePeriod(this.graphColor);
  static GamePeriod fromString(String key) =>
      GamePeriod.values.asNameMap()[key] ?? GamePeriod.others;
}

num scoreTotal(Map<String, num> scores, {required int season, GamePeriod? period}) {
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
    2024 => entries
        .where((e) => scoringpoints2024.containsKey(e.key) && e.value != 0)
        .map((e) => scoringpoints2024[e.key]! * e.value)
        .followedBy([0]).reduce((v, e) => v + e),
    2023 => entries
        .where((e) => scoringpoints2023.containsKey(e.key) && e.value != 0)
        .map((e) => scoringpoints2023[e.key]! * e.value)
        .followedBy([0]).reduce((v, e) => v + e),
    _ => throw Exception("Can't total scores - Unrecognized Season")
  };
}

Map<GamePeriod, num> scoreTotalByPeriod(Map<String, num> scorecounts, {required int season}) {
  var scores = switch (season) {
    2024 => scorecounts.entries
        .where((e) => scoringpoints2024.containsKey(e.key) && e.value != 0)
        .map((e) => MapEntry(e.key.split("_").first, scoringpoints2024[e.key]! * e.value)),
    2023 => scorecounts.entries
        .where((e) => scoringpoints2023.containsKey(e.key) && e.value != 0)
        .map((e) => MapEntry(e.key.split("_").first, scoringpoints2023[e.key]! * e.value)),
    _ => throw Exception("Can't total scores - Unrecognized Season")
  };
  Map<GamePeriod, num> out = {};
  for (MapEntry<String, num> scoreentry in scores) {
    var period = GamePeriod.fromString(scoreentry.key);
    out[period] = (out[period] ?? 0) + scoreentry.value;
  }
  return out;
}

Map<String, num> scoreTotalByType(Map<String, num> scorecounts, {required int season}) {
  var scores = switch (season) {
    2024 => scorecounts.entries
        .where((e) =>
            scoringpoints2024.containsKey(e.key) &&
            e.value != 0 &&
            (e.key.endsWith("amp") || e.key.endsWith("speaker")))
        .map((e) => MapEntry(e.key.split("_").last, e.value)),
    2023 => scorecounts.entries
        .where((e) =>
            scoringpoints2023.containsKey(e.key) &&
            e.value != 0 &&
            (e.key.contains("cube") || e.key.contains("cone")))
        .map((e) => MapEntry(e.key.split("_")[1], e.value)),
    _ => throw Exception("Can't total scores - Unrecognized Season")
  };
  Map<String, num> out = {};
  for (MapEntry<String, num> scoreentry in scores) {
    out[scoreentry.key] = (out[scoreentry.key] ?? 0) + scoreentry.value;
  }
  return out;
}

Map<String, num> nonScoreFilter(Map<String, num> scorecounts, {required int season}) {
  scorecounts = Map.from(scorecounts);
  return switch (season) {
    2024 => scorecounts..removeWhere((k, v) => scoringpoints2024.containsKey(k)),
    2023 => scorecounts..removeWhere((k, v) => scoringpoints2023.containsKey(k)),
    _ => throw Exception("Can't total scores - Unrecognized Season")
  };
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

const scoringpoints2024 = {
  "auto_amp": 5,
  "auto_speaker": 5,
  "teleop_amp": 1,
  "teleop_speaker": 2,
  "teleop_loudspeaker": 5,
  "endgame_trap": 5,
  "endgame_parked": 1,
  "endgame_onstage": 3,
  "endgame_spotlit": 4,
  "comments_fouls": -2
};

const frcred = Color(0xffed1c24);
const frcblue = Color(0xff0066b3);
