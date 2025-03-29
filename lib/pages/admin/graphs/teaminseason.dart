import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../interfaces/bluealliance.dart'
    show GamePeriod, aggByType, gamepiececolors, nonScoreFilter, scoreTotalByPeriod;
import '../../../interfaces/mixed.dart' show MixedInterfaces;
import 'statchart.dart';

class TeamInSeasonGraph extends StatelessWidget {
  final int season;
  final String team;
  const TeamInSeasonGraph({super.key, required this.season, required this.team});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: MixedInterfaces.matchAggregateStock
          .get((season: season, event: null, team: team)).then((result) {
        Map<GamePeriod, double> op = {};
        Map<String, ({int count, int score})> ot = {};
        Map<String, double> om = {};
        for (Map<String, num> matchScores in result.values) {
          final Map<String, int> intScores =
              (Map.of(matchScores)..removeWhere((k, v) => v is! int)).cast<String, int>();
          for (MapEntry<GamePeriod, int> periodScore
              in scoreTotalByPeriod(intScores, season: season).entries) {
            if (periodScore.key == GamePeriod.others) continue;
            op[periodScore.key] = (op[periodScore.key] ?? 0) + periodScore.value;
          }
          for (final typeScore in aggByType(intScores, season: season).entries) {
            ot[typeScore.key] = (
              count: (ot[typeScore.key]?.count ?? 0) + typeScore.value.count,
              score: (ot[typeScore.key]?.score ?? 0) + typeScore.value.score
            );
          }
          for (MapEntry<String, num> miscVals
              in nonScoreFilter(matchScores, season: season).entries) {
            om[miscVals.key] = (om[miscVals.key] ?? 0) + miscVals.value;
          }
        }
        final numMatches = result.values.length.toDouble();
        return (
          period: op.map((key, value) => MapEntry(key, value / numMatches)),
          type: ot.map((key, value) =>
              MapEntry(key, (count: value.count / numMatches, score: value.score / numMatches))),
          misc: om.map((key, value) => MapEntry(key, value / numMatches))
        );
      }),
      builder: (context, snapshot) => snapshot.hasError
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  const SizedBox(height: 20),
                  Text(snapshot.error.toString())
                ])
          : !snapshot.hasData
              ? Center(child: CircularProgressIndicator())
              : LayoutBuilder(builder: (context, constraints) {
                  final mainAxis = constraints.biggest.width > constraints.biggest.height
                      ? Axis.horizontal
                      : Axis.vertical;
                  final maxRadius = (mainAxis == Axis.vertical
                          ? constraints.maxWidth / 2
                          : min(constraints.maxWidth / 4, constraints.maxHeight / 2)) *
                      0.9;

                  final periodRadius = maxRadius *
                      (!_scoreScalers.containsKey(season)
                          ? 1
                          : _scoreScalers[season]!(
                              snapshot.data!.period.values.fold(0, (a, b) => a + b)));
                  assert(periodRadius <= maxRadius);

                  return Flex(
                      direction: mainAxis,
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: StatChart(
                                snapshot.data!.period.entries
                                    .map(
                                        (e) => StatChartData(e.key.name, e.value, e.key.graphColor))
                                    .toList(),
                                radius: periodRadius)),
                        Expanded(
                            child: StatChart(
                                snapshot.data!.type.entries
                                    .map((e) => StatChartData(
                                        e.key,
                                        e.value.count,
                                        gamepiececolors[season]?[e.key] ??
                                            Theme.of(context).colorScheme.primaryContainer,
                                        e.value.score.toStringAsFixed(2)))
                                    .toList(),
                                radius:
                                    maxRadius * (!_scoreScalers.containsKey(season) ? 1 : 0.85))),
                        if (snapshot.data!.misc.isNotEmpty)
                          FittedBox(
                              fit: BoxFit.fitWidth,
                              child: Flex(
                                  direction:
                                      mainAxis == Axis.horizontal ? Axis.vertical : Axis.horizontal,
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    for (var extradata in {
                                      "Agility": snapshot.data!.misc['comments_agility'],
                                      "Contribution": snapshot.data!.misc['comments_contribution']
                                    }.entries.where((e) => e.value != null))
                                      Card.filled(
                                          color: Theme.of(context).colorScheme.secondaryContainer,
                                          child: ConstrainedBox(
                                              constraints:
                                                  const BoxConstraints(minWidth: 40, maxHeight: 60),
                                              child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(extradata.key),
                                                        Text(
                                                            "${(extradata.value! * 5).toStringAsFixed(1)} / 5")
                                                      ]))))
                                  ]))
                      ]);
                }));

  static final Map<int, double Function(double)> _scoreScalers = {
    2025: (x) => (0.8 * x * x) / (x * x + 280) + 0.2
  };
}
