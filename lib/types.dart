import 'dart:collection';

import 'package:birdseye/interfaces/bluealliance.dart' show MatchInfo;

/// identifier for pit scouting responses
typedef PitScoutIdentifier = ({int season, String event, int team});

/// encodes conversions between match scouting form field, form field type, and database column type
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
typedef MatchScoutIdentifier = ({int season, String event, MatchInfo match, String team});
typedef MatchScoutIdentifierPartial = ({int season, String event, MatchInfo? match, String? team});
typedef MatchScoutIdentifierOptional = ({
  int? season,
  String? event,
  MatchInfo? match,
  String? team
});

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
