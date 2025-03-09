import 'dart:collection';

typedef PitScoutInfoSerialized = ({int season, String event, int team});

enum MatchScoutQuestionTypes<T> {
  text<String>(sqlType: "text"),
  counter<int>(sqlType: "smallint"), // int2
  toggle<bool>(sqlType: "boolean"), // bool
  slider<double>(sqlType: "real"), // float4
  error<void>(sqlType: "any");

  final String sqlType;
  const MatchScoutQuestionTypes({required this.sqlType});
  static MatchScoutQuestionTypes fromSQLType(String s) => MatchScoutQuestionTypes.values
      .firstWhere((type) => type.sqlType == s, orElse: () => MatchScoutQuestionTypes.error);
}

typedef MatchScoutQuestionSchema
    = LinkedHashMap<String, LinkedHashMap<String, MatchScoutQuestionTypes>>;
typedef MatchScoutInfoSerialized = ({int season, String event, String match, String team});

/// A record to represent various data aggregation requests
typedef AggInfo = ({int season, String? event, String? team});

typedef Achievement = ({
  int id,
  String name,
  String description,
  String requirements,
  int points,
  int? season,
  String? event
});
