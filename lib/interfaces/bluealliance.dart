import 'dart:convert' show json;

import 'package:birdseye/interfaces/localstore.dart' show LocalSourceOfTruth;
import 'package:birdseye/interfaces/sharedprefs.dart';

import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' show Client, ClientException;
import 'package:stock/stock.dart';

enum MatchLevel {
  qualification(compLevel: "qm"),
  quarterfinals(compLevel: "qf"),
  semifinals(compLevel: "sf"),
  finals(compLevel: "f");

  final String compLevel;
  const MatchLevel({required this.compLevel});
  static MatchLevel fromCompLevel(String s) =>
      MatchLevel.values.firstWhere((type) => type.compLevel == s);
}

class MatchInfo implements Comparable {
  static final _qualificationPattern = RegExp(r'^(?<level>qm)(?<index>\d+)$');
  static final _finalsPattern = RegExp(r'^(?<level>qf|sf|f)(?<setnum>\d{1,2})m(?<index>\d)$');
  static final highestSemi = 12;

  final MatchLevel level;
  final int? setnum;
  final int index;
  const MatchInfo({required this.level, this.setnum, required this.index})
    : /// It must be a qualification XOR (or but not and) not have a setnum
      assert((level == MatchLevel.qualification) ^ (setnum != null));

  factory MatchInfo.fromString(String s) {
    RegExpMatch? match = _qualificationPattern.firstMatch(s) ?? _finalsPattern.firstMatch(s);
    if (match == null) throw FormatException("Malformed Match String '$s'");
    return MatchInfo(
      level: MatchLevel.fromCompLevel(match.namedGroup("level")!),
      setnum: match.groupNames.contains("setnum")
          ? int.tryParse(match.namedGroup("setnum") ?? "")
          : null,
      index: int.parse(match.namedGroup("index")!),
    );
  }

  static bool looksLikeFinals(String test) => _finalsPattern.hasMatch(test);

  MatchInfo increment({required int highestQual}) {
    int index = this.index;
    int? setnum = this.setnum;
    MatchLevel level = this.level;
    switch (level) {
      case MatchLevel.qualification:
        if (index < highestQual) {
          index++;
        } else {
          level = MatchLevel.semifinals;
          index = 1;
          setnum = 1;
        }
      case MatchLevel.semifinals:
        assert(setnum != null);
        if (index < highestSemi) {
          index++;
        } else {
          level = MatchLevel.finals;
          index = 1;
          setnum = 1;
        }
      case MatchLevel.finals:
        assert(setnum != null);
        if (setnum! < 2) {
          setnum++;
        }
      default:
      // ignore
    }
    return MatchInfo(level: level, index: index, setnum: setnum);
  }

  MatchInfo decrement({required int highestQual}) {
    int index = this.index;
    int? setnum = this.setnum;
    MatchLevel level = this.level;
    switch (level) {
      case MatchLevel.qualification:
        if (index > 1) {
          index--;
        }
      case MatchLevel.semifinals:
        assert(setnum != null);
        if (index > 1) {
          index--;
        } else {
          level = MatchLevel.qualification;
          index = highestQual;
          setnum = null;
        }
      case MatchLevel.finals:
        assert(setnum != null);
        if (setnum! > 1) {
          setnum--;
        } else {
          level = MatchLevel.semifinals;
          index = highestSemi;
          setnum = 1;
        }
      default:
      // ignore
    }
    return MatchInfo(level: level, index: index, setnum: setnum);
  }

  @override
  String toString() => "${level.compLevel}${setnum != null ? '${setnum}m' : ''}$index";

  @override
  int compareTo(b) => level != b.level
      ? b.level.index - level.index
      : setnum != null && b.setnum != null && setnum != b.setnum
      ? b.setnum! - setnum!
      : b.index - index;

  @override
  int get hashCode => Object.hash(level, setnum, index);

  @override
  bool operator ==(Object other) =>
      other is MatchInfo && other.level == level && other.setnum == setnum && other.index == index;
}

enum Alliance {
  red(color: Color(0xffed1c24)),
  blue(color: Color(0xff0066b3));

  final Color color;
  const Alliance({required this.color});
  static Alliance fromString(String s) => Alliance.values.firstWhere((a) => a.name == s);
}

class RobotInfo implements Comparable {
  static final _robotPositionPattern = RegExp(r'^(?<color>red|blue)(?<number>[1-3])$');

  final String team;
  final Alliance alliance;
  final int ordinal;
  RobotInfo({required this.team, required this.alliance, required this.ordinal}) {
    assert(1 <= ordinal && ordinal <= 3);
  }

  factory RobotInfo.fromString({required String team, required String position}) {
    RegExpMatch? patternMatch = _robotPositionPattern.firstMatch(position);
    if (patternMatch == null) throw Exception("Malformed Robot Position '$position'");
    return RobotInfo(
      team: team,
      alliance: Alliance.fromString(patternMatch.namedGroup("color")!),
      ordinal: int.parse(patternMatch.namedGroup("number")!),
    );
  }

  @override
  int compareTo(b) =>
      (alliance != b.alliance ? alliance.index - b.alliance.index : ordinal - b.ordinal).toInt();

  @override
  String toString() => team;
}

class TBAInfo {
  final int season;
  final String? event, match;
  TBAInfo({required this.season, this.event, this.match});

  @override
  String toString() =>
      season.toString() + (event != null ? event! : "") + (match != null ? "_${match!}" : "");
}

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

  static Future<dynamic> _getJson(String path, {String? key}) => _client
      .get(
        Uri.https("www.thebluealliance.com", "/api/v3/$path"),
        headers: {
          if (key != null || SharedPreferencesInterface.tbakey != null)
            "X-TBA-Auth-Key": (key ?? SharedPreferencesInterface.tbakey)!,
        },
      )
      .then((resp) => resp.statusCode < 400 ? json.decode(resp.body) : throw resp)
      .onError<ClientException>((e, _) {
        dirtyConnected = false;
        throw e;
      })
      .then((n) {
        dirtyConnected = true;
        return n;
      });

  static final Set<String> _keyCache = {};
  static Future<bool> isKeyValid(String? key) {
    if (key == null) return Future.value(false);
    if (key.isEmpty) return Future.value(false);
    if (_keyCache.contains(key)) return Future.value(true);
    return _getJson("status", key: key)
        .then((resp) {
          if (resp == null) return false;
          _keyCache.add(key);
          return true;
        })
        .onError((_, _) => false);
  }

  static final stockSoT = LocalSourceOfTruth<TBAInfo>("tba");
  static final stock = Stock<TBAInfo, Map<String, String>>(
    sourceOfTruth: stockSoT.mapTo<Map<String, String>>(
      (p) => p.map((k, v) => MapEntry(k, v.toString())),
      (p) => p,
    ),
    fetcher: Fetcher.ofFuture((key) async {
      if (key.event == null) {
        /// season -> {eventcode: event name}
        var data = List<Map<String, dynamic>>.from(
          await _getJson("events/${key.season}/simple"),
          growable: false,
        );
        return Map.fromEntries(data.map((event) => MapEntry(event['event_code'], event['name'])));
      } else if (key.match == null) {
        /// event -> {matchcode: full match name}
        var data = List<String>.from(
          await _getJson("event/${key.season}${key.event}/matches/keys"),
          growable: false,
        );
        return Map.fromEntries(
          data.map((matchCode) => MapEntry(matchCode.split("_").last, matchCode)),
        );
      } else if (key.match == "*") {
        /// match* -> {teamcode: *}
        var data = List<String>.from(
          await _getJson("event/${key.season}${key.event}/teams/keys"),
          growable: false,
        );
        return Map.fromEntries(data.map((teamCode) => MapEntry(teamCode.substring(3), "*")));
      } else {
        /// match -> {teamcode: team position}
        var data = Map<String, dynamic>.from(
          await _getJson("match/${key.season}${key.event}_${key.match}/simple"),
        );
        Map<String, String> o = {};
        for (MapEntry<String, dynamic> alliance in Map<String, dynamic>.from(
          data['alliances'],
        ).entries) {
          for (MapEntry<int, String> team in List<String>.from(
            alliance.value['team_keys'],
            growable: false,
          ).asMap().entries) {
            if (team.value.substring(3) != "0") {
              o[team.value.substring(3)] = "${alliance.key}${team.key + 1}";
            }
          }
        }
        assert(o.length == 6, "Incorrect Team Count for ${key.season}${key.event}_${key.match}");
        return o;
      }
    }),
  );

  static Future<void> batchFetch(int season, String event) async {
    final data = List.from(await _getJson("event/$season$event/matches/simple"), growable: false);
    Map<String, String> matches = {};
    Map<String, String> pitTeams = {};
    for (dynamic matchdata in data) {
      Map<String, String> o = {};
      for (MapEntry<String, dynamic> alliance in Map<String, dynamic>.from(
        matchdata['alliances'],
      ).entries) {
        for (MapEntry<int, String> team in List<String>.from(
          alliance.value['team_keys'],
        ).asMap().entries) {
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

  // /// Returns an partial identifier of fully correct items.
  // typedef MatchScoutIdentifierOptional = ({
  //   int? season,
  //   String? event,
  //   MatchInfo? match,
  //   String? team,
  // });
  // static Future<MatchScoutIdentifierOptional> validate(
  //   MatchScoutIdentifierOptional identifier,
  // ) async {
  //   // unpack record for type promotion
  //   int? season = identifier.season;
  //   String? event = identifier.event;
  //   MatchInfo? match = identifier.match;
  //   String? team = identifier.team;

  //   try {
  //     if (season == null) throw Exception("No Season");
  //     final events = await stock.get(TBAInfo(season: season));
  //     if (event == null || !events.containsKey(event)) {
  //       return (season: season, event: null, match: null, team: null);
  //     }
  //     /// fallthrough to next try/catch
  //   } catch (_) {
  //     return (season: null, event: null, match: null, team: null);
  //   }

  //   try {
  //     final matches = await stock.get(TBAInfo(season: season, event: event));
  //     if (match == null || !matches.containsKey(match.toString())) {
  //       return (season: season, event: event, match: null, team: null);
  //     }
  //     /// fallthrough to next try/catch
  //   } catch (_) {
  //     return (season: season, event: null, match: null, team: null);
  //   }

  //   try {
  //     final teams = await (match.level == MatchLevel.qualification ? stock.get : stock.fresh)(
  //       TBAInfo(season: season, event: event, match: match.toString()),
  //     );
  //     if (team == null || !teams.containsKey(team)) {
  //       return (season: season, event: event, match: match, team: null);
  //     }
  //   } catch (_) {
  //     return (season: season, event: event, match: null, team: null);
  //   }

  //   return identifier;
  // }
}

/// The number of digits in the longest FRC team number
const longestTeam = 5;
