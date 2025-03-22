import 'dart:convert' show json;

import '../interfaces/localstore.dart' show LocalSourceOfTruth;
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' show Client;
import 'package:stock/stock.dart';

import '../main.dart' show prefs;

enum MatchLevel {
  qualification(compLevel: "qm"),
  quarterfinals(compLevel: "qf"),
  semifinals(compLevel: "sf"),
  finals(compLevel: "f");

  final String compLevel;
  const MatchLevel({required this.compLevel});
  static fromCompLevel(String s) => MatchLevel.values.firstWhere((type) => type.compLevel == s);
}

class MatchInfo implements Comparable {
  static final _qualificationPattern = RegExp(r'^(?<level>qm)(?<index>\d+)$');
  static final _finalsPattern = RegExp(r'^(?<level>qf|sf|f)(?<finalnum>\d{1,2})m(?<index>\d+)$');

  final MatchLevel level;
  final int? finalnum;
  final int index;
  MatchInfo({required this.level, this.finalnum, required this.index});
  factory MatchInfo.fromString(String s) {
    RegExpMatch? match = _qualificationPattern.firstMatch(s) ?? _finalsPattern.firstMatch(s);
    if (match == null) throw Exception("Invalid Match String - Could not parse");
    return MatchInfo(
        level: MatchLevel.fromCompLevel(match.namedGroup("level")!),
        finalnum: match.groupNames.contains("finalnum")
            ? int.tryParse(match.namedGroup("finalnum") ?? "")
            : null,
        index: int.parse(match.namedGroup("index")!));
  }

  @override
  String toString() => "${level.compLevel}${finalnum != null ? '${finalnum}m' : ''}$index";

  @override
  int compareTo(b) => level != b.level
      ? b.level.index - level.index
      : finalnum != null && b.finalnum != null && finalnum != b.finalnum
          ? b.finalnum! - finalnum!
          : b.index - index;

  @override
  int get hashCode => Object.hash(level, finalnum, index);

  @override
  bool operator ==(Object other) =>
      other is MatchInfo &&
      other.level == level &&
      other.finalnum == finalnum &&
      other.index == index;
}

class TBAInfo {
  final int season;
  final String? event, match;
  TBAInfo({required this.season, this.event, this.match});

  @override
  String toString() =>
      season.toString() + (event != null ? event! : "") + (match != null ? "_${match!}" : "");
}

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

  static final stockSoT = LocalSourceOfTruth<TBAInfo>("tba");
  static final stock = Stock<TBAInfo, Map<String, String>>(
      sourceOfTruth: stockSoT.mapTo<Map<String, String>>(
          (p) => p.map((k, v) => MapEntry(k, v.toString())), (p) => p),
      fetcher: Fetcher.ofFuture((key) async {
        if (key.event == null) {
          // season -> {eventcode: event name}
          var data = List<Map<String, dynamic>>.from(await _getJson("events/${key.season}/simple"),
              growable: false);
          return Map.fromEntries(data.map((event) => MapEntry(event['event_code'], event['name'])));
        } else if (key.match == null) {
          // event -> {matchcode: full match name}
          var data = List<String>.from(
              await _getJson("event/${key.season}${key.event}/matches/keys"),
              growable: false);
          return Map.fromEntries(
              data.map((matchCode) => MapEntry(matchCode.split("_").last, matchCode)));
        } else if (key.match == "*") {
          // match* -> {teamcode: *}
          var data = List<String>.from(await _getJson("event/${key.season}${key.event}/teams/keys"),
              growable: false);
          return Map.fromEntries(data.map((teamCode) => MapEntry(teamCode.substring(3), "*")));
        } else {
          // match -> {teamcode: team position}
          var data = Map<String, dynamic>.from(
              await _getJson("match/${key.season}${key.event}_${key.match}/simple"));
          Map<String, String> o = {};
          for (MapEntry<String, dynamic> alliance
              in Map<String, dynamic>.from(data['alliances']).entries) {
            for (MapEntry<int, String> team
                in List<String>.from(alliance.value['team_keys'], growable: false)
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
    final data = List.from(await _getJson("event/$season$event/matches/simple"), growable: false);
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
      await stockSoT.write(TBAInfo(season: season, event: event, match: matchkey), o);
    }
    await stockSoT.write(TBAInfo(season: season, event: event), matches);
    await stockSoT.write(TBAInfo(season: season, event: event, match: "*"), pitTeams);
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
  if (!scoringpoints.containsKey(season)) {
    throw Exception("Can't total scores - Unrecognized Season");
  }
  return entries
      .where((e) => scoringpoints[season]!.containsKey(e.key) && e.value != 0)
      .map((e) => scoringpoints[season]![e.key]! * e.value)
      .fold(0, (v, e) => v + e);
}

Map<GamePeriod, int> scoreTotalByPeriod(Map<String, int> scorecounts, {required int season}) {
  if (!scoringpoints.containsKey(season)) {
    throw Exception("Can't total scores - Unrecognized Season");
  }
  final scores = scorecounts.entries
      .where((e) => scoringpoints[season]!.containsKey(e.key) && e.value != 0)
      .map((e) => MapEntry(e.key.split("_").first, scoringpoints[season]![e.key]! * e.value));
  Map<GamePeriod, int> out = {};
  for (final scoreentry in scores) {
    var period = GamePeriod.fromString(scoreentry.key);
    out[period] = (out[period] ?? 0) + scoreentry.value;
  }
  return out;
}

Map<String, ({int count, int score})> aggByType(Map<String, int> scorecounts,
    {required int season}) {
  if (!scoringpoints.containsKey(season)) {
    throw Exception("Can't total scores - Unrecognized Season");
  }
  scorecounts.removeWhere((k, v) => !scoringpoints[season]!.containsKey(k) || v == 0);
  var scores = switch (season) {
    2025 => scorecounts.entries
        .where((e) => (e.key.contains("coral") || e.key.contains("algae")))
        .map((e) => MapEntry(e.key.split("_")[1],
            (count: e.value, score: scoringpoints[season]![e.key]! * e.value))),
    2024 => scorecounts.entries
        .where((e) => (e.key.endsWith("amp") || e.key.endsWith("speaker")))
        .map((e) => MapEntry(e.key.split("_").last,
            (count: e.value, score: scoringpoints[season]![e.key]! * e.value))),
    2023 => scorecounts.entries
        .where((e) => (e.key.contains("cube") || e.key.contains("cone")))
        .map((e) => MapEntry(e.key.split("_")[1],
            (count: e.value, score: scoringpoints[season]![e.key]! * e.value))),
    _ => throw Exception("Can't total scores - Unimplemented Season")
  };
  Map<String, ({int count, int score})> out = {};
  for (final scoreentry in scores) {
    out[scoreentry.key] = (
      count: (out[scoreentry.key]?.count ?? 0) + scoreentry.value.count,
      score: (out[scoreentry.key]?.score ?? 0) + scoreentry.value.score
    );
  }
  return out;
}

Map<String, num> nonScoreFilter(Map<String, num> scorecounts, {required int season}) {
  if (!scoringpoints.containsKey(season)) {
    throw Exception("Can't total scores - Unrecognized Season");
  }
  return Map.from(scorecounts)..removeWhere((k, v) => scoringpoints[season]!.containsKey(k));
}

/// The number of digits in the longest FRC team number
const longestTeam = 5;

const scoringpoints = {
  2023: {
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
  },
  2024: {
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
  },
  2025: {
    "auto_coral_l1": 3,
    "auto_coral_l2": 4,
    "auto_coral_l3": 6,
    "auto_coral_l4": 7,
    "auto_algae_net": 4,
    "auto_algae_processor": 6,
    "teleop_coral_l1": 2,
    "teleop_coral_l2": 3,
    "teleop_coral_l3": 4,
    "teleop_coral_l4": 5,
    "teleop_algae_net": 4,
    "teleop_algae_processor": 6,
    "endgame_parked": 2,
    "endgame_shallow": 6,
    "endgame_deep": 12,
    "comments_fouls": -3, // average of -2 (normal) and -6 (major)
  }
};

const frcred = Color(0xffed1c24);
const frcblue = Color(0xff0066b3);
