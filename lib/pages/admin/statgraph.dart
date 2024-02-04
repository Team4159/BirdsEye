import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../interfaces/bluealliance.dart';

// FIXME the fl_chart package is explicitly set to a prior version because 0.66.1 doesn't work on web.

class StatGraphPage extends StatelessWidget {
  final AnalysisInfo info = AnalysisInfo();
  StatGraphPage({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        AppBar(title: const Text("Statistic Graphs"), actions: [
          FieldButton(
              label: "Season",
              intOnly: true,
              onChange: (value) => info.season = value == null ? null : int.parse(value)),
          const SizedBox(width: 12),
          FieldButton(label: "Event", onChange: (value) => info.event = value),
          const SizedBox(width: 12),
          FieldButton(label: "Team", onChange: (value) => info.team = value),
          const SizedBox(width: 12)
        ]),
        const SizedBox(height: 24),
        Expanded(
            child: SafeArea(
                minimum: const EdgeInsets.all(24),
                child: ListenableBuilder(
                    listenable: info,
                    builder: (context, _) {
                      if (info.season != null && info.event != null && info.team != null) {
                        return TeamAtEventGraph(
                            season: info.season!, event: info.event!, team: info.team!);
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
  String? get event => _event?.toLowerCase();
  set event(String? e) {
    _event = e;
    notifyListeners();
  }

  String? _team;
  String? get team => _team?.toUpperCase();
  set team(String? team) {
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
          autocorrect: false,
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
          keyboardType: intOnly ? TextInputType.number : TextInputType.text,
          focusNode: _focus,
          controller: _controller,
          onSubmitted: (String value) {
            value = value.trim().toLowerCase();
            _controller.value = TextEditingValue(text: value);
            onChange(value);
          }));
}

class TeamAtEventGraph extends StatefulWidget {
  final int season;
  final String event, team;
  const TeamAtEventGraph(
      {super.key, required this.season, required this.event, required this.team});
  @override
  State<StatefulWidget> createState() => _TeamAtEventGraphState();
}

class _TeamAtEventGraphState extends State<TeamAtEventGraph> {
  Set<MapEntry<MatchInfo, Map<String, int>>>? data;
  List<MatchInfo>? ordinalMatches;

  @override
  initState() {
    Future.wait([
      Supabase.instance.client.functions
          .invoke(
            "match_aggregator_js?season=${widget.season}&event=${widget.event}", // workaround for lack of query params
          )
          .then((resp) => resp.status >= 400
              ? throw Exception("HTTP Error ${resp.status}")
              : (Map<String, dynamic>.from(resp.data) // match:
                      .map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))) // team:
                    ..removeWhere((key, value) => !value.containsKey(widget.team)))
                  .map((key, value) => MapEntry(
                      parseMatchInfo(key)!,
                      Map<String, int>.from(value[widget.team]
                        ..removeWhere((key, value) => value is! int)))) // match: {scoretype: value}
                  .entries
                  .toSet()),
      BlueAlliance.stock
          .get((season: widget.season, event: widget.event, match: null))
          .then((eventMatches) => Future.wait(eventMatches.keys.map((match) => BlueAlliance.stock
              .get((season: widget.season, event: widget.event, match: match)).then(
                  (teams) => teams.keys.contains(widget.team) ? match : null))))
          .then((unparsedEventMatches) => unparsedEventMatches
              .where((match) => match != null)
              .map((match) => parseMatchInfo(match)!)
              .toList()
            ..sort((a, b) => compareMatchInfo(b, a)))
    ])
        .then((results) => setState(() {
              data = results[0] as Set<MapEntry<MatchInfo, Map<String, int>>>;
              ordinalMatches = results[1] as List<MatchInfo>;
            }))
        .catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) => LineChart(
      LineChartData(
          titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  drawBelowEverything: false,
                  axisNameWidget: const Text("Match"),
                  sideTitles: SideTitles(
                      showTitles: ordinalMatches != null,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (i, meta) => ordinalMatches != null && i % 1 == 0
                          ? SideTitleWidget(
                              axisSide: AxisSide.bottom,
                              child: Text(stringifyMatchInfo(ordinalMatches![i.toInt()])))
                          : const SizedBox())),
              leftTitles: const AxisTitles(
                  axisNameWidget: Text("Score"),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 32))),
          minY: 0,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
              drawVerticalLine: false,
              drawHorizontalLine: ordinalMatches != null && ordinalMatches!.isNotEmpty),
          lineTouchData: const LineTouchData(
              touchTooltipData: LineTouchTooltipData(fitInsideVertically: true)),
          lineBarsData: data == null || ordinalMatches == null
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
                        spots: data!
                            .map((e) => FlSpot(
                                ordinalMatches!.indexOf(e.key).toDouble(),
                                scoreTotal(e.value, season: widget.season, period: period)
                                    .toDouble()))
                            .toList(growable: false)
                          ..sort((a, b) => a.x == b.x
                              ? 0
                              : a.x > b.x
                                  ? 1
                                  : -1))
                ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (data != null)
              HorizontalLine(
                  y: data!
                          .map((e) => scoreTotal(e.value, season: widget.season))
                          .reduce((v, e) => v + e) /
                      data!.length.toDouble(),
                  dashArray: [20, 10])
          ])),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInSine);
}
