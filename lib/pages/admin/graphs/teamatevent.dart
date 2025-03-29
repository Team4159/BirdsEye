import 'dart:collection' show LinkedHashMap;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../interfaces/bluealliance.dart'
    show BlueAlliance, GamePeriod, MatchInfo, TBAInfo, scoreTotal;
import '../../../interfaces/mixed.dart' show MixedInterfaces;

class TeamAtEventGraph extends StatelessWidget {
  final int season;
  final String event, team;
  const TeamAtEventGraph(
      {super.key, required this.season, required this.event, required this.team});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: Future.wait([
        MixedInterfaces.matchAggregateStock.get((season: season, event: event, team: team)),
        BlueAlliance.stock
            .get(TBAInfo(season: season, event: event))
            .then((eventMatches) => Future.wait(eventMatches.keys.map((match) => BlueAlliance.stock
                .get(TBAInfo(season: season, event: event, match: match))
                .then((teams) => teams.keys.contains(team) ? match : null))))
            .then((unparsedEventMatches) => unparsedEventMatches
                .whereType<String>()
                .map((match) => MatchInfo.fromString(match))
                .toList()
              ..sort((b, a) => a.compareTo(b)))
      ]).then((results) => (
            data: results[0] as LinkedHashMap<MatchInfo, Map<String, num>>,
            ordinalMatches: results[1] as List<MatchInfo>
          )),
      builder: (context, snapshot) => snapshot.hasError
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  const SizedBox(height: 20),
                  Text(snapshot.error.runtimeType.toString())
                ])
          : LineChart(
              LineChartData(
                  titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          drawBelowEverything: false,
                          axisNameWidget: const Text("Match"),
                          sideTitles: SideTitles(
                              showTitles: snapshot.hasData,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (i, meta) {
                                if (!snapshot.hasData || i % 1 != 0) return const SizedBox();
                                int n = i.toInt();
                                if (n < 0 || n >= snapshot.data!.ordinalMatches.length) {
                                  return const SizedBox();
                                }
                                return SideTitleWidget(
                                    meta: meta,
                                    child: Text(snapshot.data!.ordinalMatches[n].toString()));
                              })),
                      leftTitles: const AxisTitles(
                          axisNameWidget: Text("Score"),
                          sideTitles: SideTitles(showTitles: true, reservedSize: 32))),
                  minY: 0,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                      drawVerticalLine: false,
                      drawHorizontalLine:
                          snapshot.hasData && snapshot.data!.ordinalMatches.isNotEmpty),
                  lineTouchData: const LineTouchData(
                      touchTooltipData: LineTouchTooltipData(fitInsideVertically: true)),
                  lineBarsData: !snapshot.hasData
                      ? []
                      : [
                          for (GamePeriod period in GamePeriod.values)
                            LineChartBarData(
                                show: true,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                isStrokeJoinRound: true,
                                isCurved: true,
                                curveSmoothness: 0.1,
                                preventCurveOverShooting: true,
                                color: period.graphColor.withAlpha(255),
                                dotData: FlDotData(
                                    getDotPainter: (p1, p2, p3, p4) => FlDotCirclePainter(
                                        color: period.graphColor.withAlpha(255),
                                        radius: 5,
                                        strokeColor: Colors.transparent,
                                        strokeWidth: 0)),
                                spots: snapshot.data!.data.entries
                                    .map((e) => FlSpot(
                                        snapshot.data!.ordinalMatches.indexOf(e.key).toDouble(),
                                        scoreTotal(e.value, season: season, period: period)
                                            .toDouble()))
                                    .toList(growable: false)
                                  ..sort((a, b) => (a.x - b.x).sign.toInt()))
                        ],
                  extraLinesData: ExtraLinesData(
                      horizontalLines: !snapshot.hasData || snapshot.data!.data.isEmpty
                          ? []
                          : [
                              HorizontalLine(
                                  y: snapshot.data!.data.entries
                                          .map((e) => scoreTotal(e.value, season: season))
                                          .fold(0.0, (v, e) => v + e) /
                                      snapshot.data!.data.length
                                          .toDouble(), // todo report this nuerically
                                  dashArray: [20, 10])
                            ])),
              duration: Durations.extralong3,
              curve: Curves.easeInSine));
}
