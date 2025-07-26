import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluealliance.dart' show BlueAlliance, TBAInfo;

class SharedPreferencesInterface {
  static late final SharedPreferences _prefs;

  /// Initialize the library to prepare to access data
  static Future<void> initialize() async => _prefs = await SharedPreferences.getInstance();

  static String? get tbakey => _prefs.containsKey("tbaKey") ? _prefs.getString("tbaKey")! : null;

  static set tbakey(String? k) =>
      k == null ? _prefs.remove("tbaKey") : _prefs.setString("tbaKey", k);

  static int get season {
    if (_prefs.containsKey("season")) return _prefs.getInt("season")!;
    return season = DateTime.now().year;
  }

  static set season(int s) {
    if (seasonListenable.value == s) return;
    _prefs.setInt("season", s);
    seasonListenable.value = s;
  }

  static final seasonListenable =
      ValueNotifier<int>(season); // holds a risk of desyncing from stored value but idc

  static String? get event => _prefs.containsKey("event") ? _prefs.getString("event") : null;
  static set event(String? e) => e == null ? _prefs.remove("event") : _prefs.setString("event", e);

  static Future<bool> get isValid async =>
      event != null &&
      await BlueAlliance.stock
          .get(TBAInfo(season: season))
          .then((value) => value.containsKey(event));
}
