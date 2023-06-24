import 'dart:convert' show json;

import 'package:http/http.dart' show Client;
import 'package:stock/stock.dart';

import '../main.dart' show prefs;

class BlueAlliance {
  static final client = Client();

  static Future _getJson(String path, {String? key}) => client
      .get(Uri.https("www.thebluealliance.com", "/api/v3/$path",
          {"X-TBA-Auth-Key": key ?? prefs.getString("tbaKey")}))
      .then((resp) => resp.statusCode < 400
          ? json.decode(resp.body)
          : throw Exception(resp.body));

  static final Set<String> _keyCache = {};
  static Future<bool> isKeyValid(String? key) => key == null || key.isEmpty
      ? Future.value(false)
      : _keyCache.contains(key)
          ? Future.value(true)
          : _getJson("status", key: key).then((_) {
              _keyCache.add(key);
              return true;
            }).catchError((_) => false);

  static final stock = Stock<({int season, String? event, String? match}),
          Map<String, String>>(
      sourceOfTruth: CachedSourceOfTruth(),
      fetcher: Fetcher.ofFuture((key) async {
        if (key.event == null) {
          // season
          var data = List<Map<String, dynamic>>.from(
              await _getJson("events/${key.season}/simple"));
          return Map.fromEntries(data
              .map((event) => MapEntry(event['event_code'], event['name'])));
        } else if (key.match == null) {
          // event
          var data = List<String>.from(
              await _getJson("event/${key.season}${key.event}/matches/keys"));
          return Map.fromEntries(data.map(
              (matchCode) => MapEntry(matchCode.split("_").last, matchCode)));
        } else if (key.match == "*") {
          // match*
          var data = List<String>.from(
              await _getJson("event/${key.season}${key.event}/teams/keys"));
          return Map.fromEntries(
              data.map((teamCode) => MapEntry(teamCode.substring(3), "*")));
        } else {
          // match
          var data = Map<String, dynamic>.from(await _getJson(
              "match/${key.season}${key.event}_${key.match}/simple"));
          Map<String, String> o = {};
          for (MapEntry<String, dynamic> alliance
              in Map<String, dynamic>.from(data['alliances']).entries) {
            for (MapEntry<int, String> team
                in List<String>.from(alliance.value['team_keys'])
                    .asMap()
                    .entries) {
              if (team.value.substring(3) != "0") {
                o[team.value.substring(3)] = "${alliance.key}${team.key + 1}";
              }
            }
          }
          return o;
        }
      }));
}
