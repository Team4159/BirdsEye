import 'dart:async';

import '../types.dart';
import 'package:localstore/localstore.dart';
import 'package:stock/stock.dart';

class LocalStoreInterface {
  static final _db = Localstore.instance;

  static Future<void> addMatch(MatchScoutInfoSerialized key, Map<String, dynamic> data) => _db
      .collection("scout")
      .doc("match-${key.season}${key.event}_${key.match}-${key.team}")
      .set(data
        ..['season'] = key.season
        ..['event'] = key.event
        ..['match'] = key.match
        ..['team'] = key.team);

  static Future<void> addPit(PitScoutInfoSerialized key, Map<String, dynamic> data) =>
      _db.collection("scout").doc("pit-${key.season}${key.event}-${key.team}").set(data
        ..['season'] = key.season
        ..['event'] = key.event
        ..['team'] = key.team);

  static Future<void> remove(String id) => _db.collection("scout").doc(id).delete();

  static Future<({MatchScoutInfoSerialized key, Map<String, dynamic> data})?> getMatch(
      String id) async {
    assert(id.startsWith("match"));
    var data = await _db.collection("scout").doc(id).get();
    return data == null
        ? null
        : (
            key: (
              season: data.remove('season') as int,
              event: data.remove('event') as String,
              match: data.remove('match') as String,
              team: data.remove('team') as String
            ),
            data: data
          );
  }

  static Future<({PitScoutInfoSerialized key, Map<String, dynamic> data})?> getPit(
      String id) async {
    assert(id.startsWith("pit"));
    var data = await _db.collection("scout").doc(id).get();
    return data == null
        ? null
        : (
            key: (
              season: data.remove('season') as int,
              event: data.remove('event') as String,
              team: data.remove('team') as int
            ),
            data: data
          );
  }

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
