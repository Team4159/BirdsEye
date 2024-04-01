import 'dart:async';

import 'package:localstore/localstore.dart';
import 'package:stock/stock.dart';

import '../pages/matchscout.dart' show MatchScoutInfoSerialized;

class LocalStoreInterface {
  static final _db = Localstore.instance;

  static Future<void> addMatch(MatchScoutInfoSerialized key, Map<String, dynamic> fields) => _db
      .collection("scout")
      .doc("match-${key.season}${key.event}_${key.match}-${key.team}")
      .set(fields
        ..['season'] = key.season
        ..['event'] = key.event
        ..['match'] = key.match
        ..['team'] = key.team);

  static Future<void> addPit(int season, Map<String, dynamic> data) => _db
      .collection("scout")
      .doc("pit-$season${data['event']}-${data['team']}")
      .set(data..['season'] = season);

  static Future<void> remove(String id) => _db.collection("scout").doc(id).delete();

  static Future<Map<String, dynamic>?> get(String id) => _db.collection("scout").doc(id).get();

  static Future<Set<String>> get getAll =>
      _db.collection("scout").get().then((value) => value?.keys.toSet() ?? {});
}

class LocalSourceOfTruth<K> implements SourceOfTruth<K, Map<String, dynamic>> {
  final CollectionRef collection;
  final StreamController<({String key, Map<String, dynamic>? value})> _stream =
      StreamController.broadcast();
  LocalSourceOfTruth(String collection)
      : collection = LocalStoreInterface._db.collection(collection);

  @override
  Future<void> delete(K key) {
    String s = key.toString();
    _stream.add((key: s, value: null));
    return collection.doc(s).delete();
  }

  @override
  Future<void> deleteAll() => collection.get().then((docs) {
        if (docs == null) return;
        for (String key in docs.keys) {
          _stream.add((key: key, value: null));
        }
      }).then((_) => collection.delete());

  @override
  Stream<Map<String, dynamic>?> reader(K key) async* {
    String s = key.toString();
    yield* collection.doc(s).get().asStream();
    yield* _stream.stream.where((e) => e.key == s).map((e) => e.value);
  }

  @override
  Future<void> write(K key, Map<String, dynamic>? value) {
    String s = key.toString();
    _stream.add((key: s, value: value));
    return collection.doc(s).set(value ?? {});
  }
}
