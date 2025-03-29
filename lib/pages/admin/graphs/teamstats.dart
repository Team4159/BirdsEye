// import 'package:birdseye/interfaces/bluealliance.dart' show MatchInfo;
// import 'package:birdseye/interfaces/mixed.dart' show MixedInterfaces;
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';

// class TeamInSeasonWheel extends StatelessWidget {
//   final int season;
//   final String event, team;
//   const TeamInSeasonWheel(
//       {super.key, required this.season, required this.event, required this.team});

//   @override
//   Widget build(BuildContext context) => FutureBuilder(
//       future: MixedInterfaces.matchAggregateStock
//           .get((season: season, event: event, team: team)).then((result) {
//         final matches = result.keys.toList() as List<({String event, MatchInfo info})>;
//         switch (season) {
//           case 2025:
//           default:
//         }
//       }),
//       builder: (context, _) =>
//           RadarChart(RadarChartData(dataSets: [RadarDataSet(dataEntries: null)])));
// }
