import 'package:localstore/localstore.dart';

class LocalStoreInterface {
  static final _db = Localstore.instance;

  static Future<void> addMatch(int season, Map<String, dynamic> data) => _db
      .collection("matchscout")
      .doc("match-$season${data['event']}_${data['match']}-${data['team']}")
      .set(data..['season'] = season);

  static Future<void> addPit(int season, Map<String, dynamic> data) => _db
      .collection("pitscout")
      .doc("pit-$season${data['event']}-${data['team']}")
      .set(data..['season'] = season);

  static Future<void> remove(String id) => id.startsWith("match")
      ? _db.collection("matchscout").doc(id).delete()
      : id.startsWith("pit")
          ? _db.collection("pitscout").doc(id).delete()
          : throw Exception("Invalid LocalStore ID: $id");

  static Future<Map<String, dynamic>?> get(String id) => id.startsWith("match")
      ? _db.collection("matchscout").doc(id).get()
      : id.startsWith("pit")
          ? _db.collection("pitscout").doc(id).get()
          : throw Exception("Invalid LocalStore ID: $id");

  static Future<Set<String>> getMatches() => _db
      .collection("matchscout")
      .get()
      .then((value) => value?.keys.toSet() ?? <String>{});

  static Future<Set<String>> getPits() => _db
      .collection("pitscout")
      .get()
      .then((value) => value?.keys.toSet() ?? <String>{});
}
