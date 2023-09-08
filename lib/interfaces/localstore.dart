import 'package:localstore/localstore.dart';
import 'package:stock/stock.dart';

class LocalStoreInterface {
  static final _db = Localstore.instance;

  static Future<void> addMatch(int season, Map<String, dynamic> data) => _db
      .collection("scout")
      .doc("match-$season${data['event']}_${data['match']}-${data['team']}")
      .set(data..['season'] = season);

  static Future<void> addPit(int season, Map<String, dynamic> data) => _db
      .collection("scout")
      .doc("pit-$season${data['event']}-${data['team']}")
      .set(data..['season'] = season);

  static Future<void> remove(String id) => _db.collection("scout").doc(id).delete();

  static Future<Map<String, dynamic>?> get(String id) => _db.collection("scout").doc(id).get();

  static Future<Set<String>> get getAll =>
      _db.collection("scout").get().then((value) => value?.keys.toSet() ?? {});
}

class LocalSourceOfTruth<Key> implements SourceOfTruth<Key, Map<String, dynamic>> {
  // FIXME very strange connection bugs. maybe switch to sqlflite
  final CollectionRef collection;
  LocalSourceOfTruth(String key) : collection = LocalStoreInterface._db.collection(key);

  @override
  Future<void> delete(Key key) => collection.doc(key.hashCode.toString()).delete();

  @override
  Future<void> deleteAll() => collection.delete();

  @override
  Stream<Map<String, dynamic>?> reader(Key key) =>
      Stream.fromFuture(collection.doc(key.hashCode.toString()).get());

  @override
  Future<void> write(Key key, Map<String, dynamic>? value) =>
      collection.doc(key.hashCode.toString()).set(value ?? {});
}
