import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';

class AnalysisPage extends StatelessWidget {
  final AnalysisInfo info = AnalysisInfo();
  AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        AppBar(title: const Text("Data Analysis"), actions: [
          FieldButton(
              label: "Season",
              intOnly: true,
              onChange: (value) => info.season = value == null ? null : int.parse(value)),
          const SizedBox(width: 12),
          FieldButton(label: "Event", onChange: (value) => info.event = value),
          const SizedBox(width: 12),
          FieldButton(
              label: "Team",
              intOnly: true,
              onChange: (value) => info.team = value == null ? null : int.parse(value)),
          const SizedBox(width: 12),
        ]),
        const SizedBox(height: 24),
        Expanded(
            child: SafeArea(
                minimum: const EdgeInsets.all(24),
                child: ListenableBuilder(
                    listenable: info,
                    builder: (context, _) {
                      if (info.season != null && info.event != null && info.team != null) {
                        return FutureBuilder(
                            future: Supabase.instance.client.functions.invoke(
                                "match_aggregator_js?season=${info.season}&event=${info.event}", // workaround for lack of query params
                                responseType: ResponseType.text),
                            builder: (context, snapshot) => !snapshot.hasData
                                ? snapshot.hasError
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                            Icon(Icons.warning_rounded,
                                                color: Colors.red[700], size: 50),
                                            const SizedBox(height: 20),
                                            Text(snapshot.error.toString())
                                          ])
                                    : const Center(child: CircularProgressIndicator())
                                : (snapshot.data!.status != null && snapshot.data!.status! >= 400)
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                            Icon(Icons.dangerous_rounded,
                                                color: Colors.red[700], size: 50),
                                            const SizedBox(height: 20),
                                            Text(snapshot.data!.data),
                                            Text("Error ${snapshot.data!.status!}",
                                                style: Theme.of(context).textTheme.labelLarge)
                                          ])
                                    : TeamAtEventGraph(
                                        season: info.season!,
                                        team: info.team!,
                                        response: jsonDecode(snapshot.data!.data)));
                      }
                      return const Center(child: Text("Not implemented"));
                    })))
      ]);
}

class AnalysisInfo extends ChangeNotifier {
  int? _season;
  int? get season => _season;
  set season(int? s) {
    _season = s;
    notifyListeners();
  }

  String? _event;
  String? get event => _event;
  set event(String? e) {
    _event = e;
    notifyListeners();
  }

  int? _team;
  int? get team => _team;
  set team(int? team) {
    _team = team;
    notifyListeners();
  }
}

class FieldButton extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final Function(String?) onChange;
  final String label;
  final bool intOnly;
  FieldButton({super.key, required this.label, this.intOnly = false, required this.onChange}) {
    _focus.addListener(() {
      if (!_focus.hasFocus) return;
      _controller.clear();
      onChange(null);
    });
  }

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
          child: TextField(
        enableSuggestions: false,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        decoration: InputDecoration(
            hintText: label,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            isDense: true,
            constraints: BoxConstraints.tight(const Size.fromHeight(40)),
            border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular((FilledButtonTheme.of(context)
                            .style
                            ?.fixedSize
                            ?.resolve({MaterialState.disabled})?.height ??
                        48) /
                    2))),
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        textCapitalization: TextCapitalization.none,
        inputFormatters: intOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        focusNode: _focus,
        controller: _controller,
        onSubmitted: onChange,
      ));
}

class TeamAtEventGraph extends StatelessWidget {
  final int season, team;
  final Set<MapEntry<MatchInfo, Map<String, int>>> data;
  TeamAtEventGraph({super.key, required this.season, required this.team, required dynamic response})
      : data = (Map<String, dynamic>.from(response).map((key, value) => MapEntry(
                key, Map<String, dynamic>.from(value).map((k1, v1) => MapEntry(int.parse(k1), v1))))
              ..removeWhere((key, value) => !value.containsKey(team)))
            .map((key, value) => MapEntry(parseMatchInfo(key)!, Map<String, int>.from(value[team])))
            .entries
            .toSet();

  @override
  Widget build(BuildContext context) => data.isEmpty
      ? const Center(child: Text("No Data"))
      : LineChart(LineChartData(
          titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  drawBelowEverything: false,
                  axisNameWidget: const Text("Match"),
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (i, meta) => i % 1 == 0
                          ? SideTitleWidget(
                              axisSide: AxisSide.bottom,
                              child: Text(stringifyMatchInfo(unhashMatchInfo(i.toInt()))))
                          : const SizedBox())),
              leftTitles: const AxisTitles(
                  axisNameWidget: Text("Score"),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 35))),
          minY: 0,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          lineTouchData: const LineTouchData(
              touchTooltipData: LineTouchTooltipData(fitInsideVertically: true)),
          lineBarsData: [
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
                  spots: data
                      .map((e) => FlSpot(hashMatchInfo(e.key).toDouble(),
                          scoreTotal(e.value, season: season, period: period).toDouble()))
                      .toList(growable: false)
                    ..sort((a, b) => a.x == b.x
                        ? 0
                        : a.x > b.x
                            ? 1
                            : -1)),
          ],
          // betweenBarsData: [
          //   for (int i = 0; i < GamePeriod.values.length; i++)
          //     BetweenBarsData(fromIndex: i, toIndex: i + 1, color: GamePeriod.values[i].graphColor)
          // ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
                y: data.map((e) => scoreTotal(e.value, season: season)).reduce((v, e) => v + e) /
                    data.length.toDouble(),
                dashArray: [20, 10])
          ])));
}
