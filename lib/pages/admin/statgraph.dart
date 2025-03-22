import 'dart:async';
import 'dart:collection';
import 'dart:math' show min;

import 'package:birdseye/interfaces/mixed.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../interfaces/bluealliance.dart';
import '../../interfaces/supabase.dart';
import '../../utils.dart';
import 'admin.dart';

class StatGraphPage extends StatelessWidget {
  final AnalysisInfo info = AnalysisInfo();
  StatGraphPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 3,
      child: Scaffold(
          drawer: AdminScaffoldShell.drawer(),
          appBar: AppBar(
              title: const Text("Statistic Graphs"),
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      MixedInterfaces.matchAggregateStock.clearAll();
                      SupabaseInterface.eventAggregateStock.clearAll();
                      SupabaseInterface.distinctStock.clearAll();
                    })
              ],
              bottom: TabBar(
                  tabs: [
                    ValueTab(
                        // Season Selector
                        SupabaseInterface.getAvailableSeasons().then((s) => s.toList()..add(0)),
                        initialPositionCallback: (ss) {
                          if (info.season == null) return ss.length - 1;
                          var i = ss.indexOf(info.season!);
                          return i >= 0 ? i : ss.length - 1;
                        },
                        onChange: (s) => info.season = s == 0 ? null : s),
                    ListenableBuilder(
                        // Event Selector
                        listenable: info.seasonNotifier,
                        builder: (context, _) => ValueTab(
                            info.season == null
                                ? Future<List<String>>.error({})
                                : SupabaseInterface.distinctStock
                                    .get((season: info.season!, event: null, team: info.team)).then(
                                        (e) => e.events.toList()
                                          ..sort()
                                          ..add("")),
                            initialPositionCallback: (ss) {
                              if (info.event == null) return ss.length - 1;
                              var i = ss.indexOf(info.event!);
                              return i >= 0 ? i : ss.length - 1;
                            },
                            onChange: (e) => info.event = e.isEmpty ? null : e)),
                    ListenableBuilder(
                        // Team Selector
                        listenable: info.seasoneventNotifier,
                        builder: (context, _) => ValueTab<String>(
                            info.season == null
                                ? Future.error({})
                                : SupabaseInterface.distinctStock
                                    .get((
                                    season: info.season!,
                                    event: info.event,
                                    team: null
                                  )).then((t) => t.teams.toList()
                                      ..sort(
                                          (a, b) => (int.tryParse(a) ?? 0) - (int.tryParse(b) ?? 0))
                                      ..add("")),
                            initialPositionCallback: (ss) {
                              if (info.team == null) return ss.length - 1;
                              var i = ss.indexOf(info.team!);
                              return i >= 0 ? i : ss.length - 1;
                            },
                            onChange: (t) => info.team = t.isEmpty ? null : t))
                  ],
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  dividerHeight: 0,
                  splashBorderRadius: BorderRadius.circular(12),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: HitchedTabIndicator(borderRadius: BorderRadius.circular(12)))),
          body: Column(children: [
            Flexible(
                flex: 1,
                fit: FlexFit.loose,
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.topCenter,
                    constraints: const BoxConstraints(maxHeight: 60),
                    child: TabBarView(children: [
                      ListenableBuilder(
                          listenable: info.seasonNotifier,
                          builder: (context, _) => ValueDetailTabView(info.season == null
                              ? Future.value(["No Season Selected"])
                              : SupabaseInterface.distinctStock
                                  .get((season: info.season!, event: null, team: null)).then(
                                      (data) => [
                                            "${data.scouters.length} Scouter${data.scouters.length != 1 ? 's' : ''}",
                                            "${data.eventmatches.length} Match${data.eventmatches.length != 1 ? 'es' : ''}",
                                            "${data.teams.length} Team${data.teams.length != 1 ? 's' : ''}"
                                          ]))),
                      ListenableBuilder(
                          listenable: info.seasoneventNotifier,
                          builder: (context, _) => ValueDetailTabView(info.event == null
                              ? Future.value(["No Event Selected"])
                              : info.season == null
                                  ? Future.value(["No Season Selected"])
                                  : SupabaseInterface.distinctStock.get((
                                      season: info.season!,
                                      event: info.event!,
                                      team: null
                                    )).then((data) => [
                                        "${data.scouters.length} Scouter${data.scouters.length != 1 ? 's' : ''}",
                                        "${data.matches.length} Match${data.matches.length != 1 ? 'es' : ''}",
                                        "${data.teams.length} Team${data.teams.length != 1 ? 's' : ''}"
                                      ]))),
                      ListenableBuilder(
                          listenable: info,
                          builder: (context, _) {
                            Future<List<String>> out;
                            if (info.team == null) {
                              out = Future.value(["No Team Selected"]);
                            } else if (info.season == null) {
                              out = Future.value(["No Season Selected"]);
                            } else {
                              out = Future.wait(<Future<List<String>>>[
                                SupabaseInterface.distinctStock.get((
                                  season: info.season!,
                                  event: info.event,
                                  team: info.team
                                )).then((data) => [
                                      "${data.matches.length} Match${data.matches.length != 1 ? 'es' : ''}"
                                    ]),
                                if (info.event != null && info.team != null)
                                  BlueAlliance.getOPR(info.season!, info.event!, info.team!)
                                      .then<List<String>>((data) => data != null
                                          ? [
                                              if (data.opr != null)
                                                "${data.opr!.toStringAsPrecision(4)} OPR",
                                              if (data.dpr != null)
                                                "${data.dpr!.toStringAsPrecision(4)} DPR"
                                            ]
                                          : [])
                              ]).then((futures) => futures.expand((e) => e).toList());
                            }
                            return ValueDetailTabView(out);
                          })
                    ]))),
            Flexible(
                flex: 4,
                fit: FlexFit.tight,
                child: SafeArea(
                    minimum: const EdgeInsets.all(24),
                    child: ListenableBuilder(
                        listenable: info,
                        builder: (context, _) {
                          if (info.season != null && info.event != null && info.team != null) {
                            return TeamAtEventGraph(
                                season: info.season!, event: info.event!, team: info.team!);
                          }
                          if (info.season != null && info.team != null) {
                            return TeamInSeasonGraph(season: info.season!, team: info.team!);
                          }
                          if (info.season != null && info.event != null) {
                            return EventInSeasonRankings(season: info.season!, event: info.event!);
                          }
                          return const Center(child: Text("Not implemented"));
                        })))
          ])));
}

class ValueTab<T extends Object> extends StatelessWidget {
  final FutureOr<List<T>> options;
  final void Function(T)? onChange;
  final int Function(List<T>)? initialPositionCallback;
  ValueTab(this.options, {this.initialPositionCallback, this.onChange, super.key});
  final ValueNotifier<bool> _searchMode = ValueNotifier(false);

  @override
  Widget build(BuildContext context) => Tab(
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular((FilledButtonTheme.of(context)
                          .style
                          ?.fixedSize
                          ?.resolve({WidgetState.disabled})?.height ??
                      48) /
                  2)),
          child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () =>
                  _searchMode.value = T == String || T == num ? !_searchMode.value : false,
              child: ConstrainedBox(
                  constraints: BoxConstraints.tight(const Size.fromHeight(40)),
                  child: FutureBuilder(
                      future: Future.value(options),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                              child: LinearProgressIndicator(
                                  borderRadius: BorderRadius.all(Radius.circular(4))));
                        }
                        var swipeController = PageController(
                            initialPage: initialPositionCallback == null
                                ? snapshot.data!.length - 1
                                : initialPositionCallback!(snapshot.data!));
                        if (onChange != null && initialPositionCallback == null) {
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => onChange!(snapshot.data!.last));
                        }
                        var stringifiedOptions =
                            LinkedHashSet.of(snapshot.data!.map((e) => e.toString()));
                        return ListenableBuilder(
                            listenable: _searchMode,
                            builder: (context, _) => IndexedStack(
                                    index: _searchMode.value ? 0 : 1,
                                    sizing: StackFit.expand,
                                    children: [
                                      Autocomplete<T>(
                                          optionsBuilder: (input) => snapshot.data!
                                              .where((e) => e.toString().startsWith(input.text)),
                                          fieldViewBuilder: (context, textEditingController,
                                                  focusNode, onFieldSubmitted) =>
                                              TextFormField(
                                                  spellCheckConfiguration:
                                                      const SpellCheckConfiguration.disabled(),
                                                  autocorrect: false,
                                                  enableSuggestions: false,
                                                  textCapitalization: TextCapitalization.none,
                                                  keyboardType: T == int || T == double
                                                      ? TextInputType.numberWithOptions(
                                                          decimal: T == double)
                                                      : TextInputType.text,
                                                  inputFormatters: [
                                                    if (T == int)
                                                      FilteringTextInputFormatter.digitsOnly,
                                                    if (T == double)
                                                      FilteringTextInputFormatter.allow(
                                                          RegExp(r"[0-9.]"))
                                                  ],
                                                  decoration: const InputDecoration(
                                                      border: InputBorder.none),
                                                  controller: textEditingController..clear(),
                                                  focusNode: focusNode,
                                                  onFieldSubmitted: (value) {
                                                    if (!stringifiedOptions.contains(value)) return;
                                                    onFieldSubmitted();
                                                    var v =
                                                        stringifiedOptions.toList().indexOf(value);
                                                    swipeController.jumpToPage(v);
                                                    if (onChange != null) {
                                                      onChange!(snapshot.data![v]);
                                                    }
                                                    _searchMode.value = false;
                                                  },
                                                  autovalidateMode:
                                                      AutovalidateMode.onUserInteraction,
                                                  validator: (value) =>
                                                      stringifiedOptions.contains(value)
                                                          ? null
                                                          : "Invalid",
                                                  textAlign: TextAlign.center,
                                                  textAlignVertical: TextAlignVertical.center),
                                          onSelected: (value) {
                                            if (onChange != null) onChange!(value);
                                            swipeController
                                                .jumpToPage(snapshot.data!.indexOf(value));
                                            _searchMode.value = false;
                                          }),
                                      PageView(
                                          controller: swipeController,
                                          scrollBehavior: ScrollConfiguration.of(context).copyWith(
                                              scrollbars: false,
                                              overscroll: false,
                                              dragDevices: PointerDeviceKind.values.toSet()),
                                          onPageChanged: (i) =>
                                              onChange == null || snapshot.data!.length <= i
                                                  ? null
                                                  : onChange!(snapshot.data![i]),
                                          children: snapshot.data!
                                              .map((e) => Text(
                                                    e == 0.0 ? "" : e.toString(),
                                                    overflow: kIsWeb
                                                        ? TextOverflow.ellipsis
                                                        : TextOverflow.fade,
                                                    softWrap: false,
                                                    maxLines: 1,
                                                    textHeightBehavior: const TextHeightBehavior(
                                                        leadingDistribution:
                                                            TextLeadingDistribution.even),
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall!
                                                        .copyWith(fontSize: 22),
                                                  ))
                                              .toList())
                                    ]));
                      })))));
}

class ValueDetailTabView extends StatelessWidget {
  final FutureOr<List<String>> detail;
  const ValueDetailTabView(this.detail, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: Future.value(detail),
      builder: (context, snapshot) => DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: const ToplessHitchedBorder(BorderSide(width: 3.5, color: Colors.white))),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: !snapshot.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(snapshot.data!.join(", "),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                          textScaler: const TextScaler.linear(1.5))))));
}

class AnalysisInfo extends ChangeNotifier {
  int? _season;
  int? get season => _season;
  set season(int? s) {
    _season = s;
    seasonNotifier.notifyListeners();
    seasoneventNotifier.notifyListeners();
    notifyListeners();
  }

  ChangeNotifier seasonNotifier = ChangeNotifier();

  String? _event;
  String? get event => _event;
  set event(String? e) {
    _event = e?.toLowerCase();
    seasoneventNotifier.notifyListeners();
    notifyListeners();
  }

  ChangeNotifier seasoneventNotifier =
      ChangeNotifier(); // this could be replaced with Listenable.combine

  String? _team;
  String? get team => _team?.toUpperCase();
  set team(String? team) {
    _team = team;
    notifyListeners();
  }
}

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
                                          .followedBy([0]).reduce((v, e) => v + e) /
                                      snapshot.data!.data.length.toDouble(),
                                  dashArray: [20, 10])
                            ])),
              duration: Durations.extralong3,
              curve: Curves.easeInSine));
}

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
                  assert(periodRadius < maxRadius);

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
                                        Theme.of(context)
                                            .colorScheme
                                            .primaryContainer, // TODO colorize
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

class EventInSeasonRankings extends StatelessWidget {
  final int season;
  final String event;
  EventInSeasonRankings({super.key, required this.season, required this.event});

  final ValueNotifier<EventAggregateMethod> method = ValueNotifier(EventAggregateMethod.defense);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: method,
      builder: (context, _) => CustomScrollView(slivers: [
            SliverPadding(
                padding: const EdgeInsets.only(bottom: 12),
                sliver: SliverToBoxAdapter(
                    child: Row(children: [
                  const Expanded(child: SizedBox()),
                  Text("Sort: ", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 12),
                  SegmentedButton(
                      segments: EventAggregateMethod.values
                          .map((method) => ButtonSegment(value: method, label: Text(method.name)))
                          .toList(),
                      selected: {method.value},
                      onSelectionChanged: (value) => method.value = value.single)
                ]))),
            FutureBuilder(
                future: SupabaseInterface.eventAggregateStock
                    .get((season: season, event: event, method: method.value)),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                          Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                          const SizedBox(height: 20),
                          Text(snapshot.error.toString())
                        ]));
                  }
                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                        hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
                  }
                  return SliverAnimatedInList(snapshot.data!.entries.toList(),
                      builder: (context, dynamic e) => ListTile(
                          title: Text(e.key, style: Theme.of(context).textTheme.bodyLarge),
                          trailing: Text(e.value.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.bodyMedium),
                          dense: true));
                })
          ]));
}

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

class StatChartData {
  final String label;
  final double size;
  final String hoverLabel;
  final Color color;

  StatChartData(this.label, this.size, this.color, [String? tooltip])
      : hoverLabel = tooltip ?? size.toStringAsFixed(2);
}

class StatChart extends StatefulWidget {
  final num radius;
  final List<StatChartData> data;
  const StatChart(this.data, {super.key, required this.radius});

  @override
  State<StatefulWidget> createState() => _StatChartState();
}

class _StatChartState extends State<StatChart> {
  int? _touched;
  _StatChartState();

  @override
  build(BuildContext context) => PieChart(
      PieChartData(
          centerSpaceRadius: widget.radius * 0.7,
          sections: widget.data.indexed
              .map((e) => PieChartSectionData(
                  radius: widget.radius * 0.3,
                  title: e.$2.label,
                  color: e.$2.color,
                  value: e.$2.size,
                  showTitle: true,
                  titleStyle: Theme.of(context).textTheme.labelSmall,
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  badgeWidget: _touched != e.$1
                      ? null
                      : Card.filled(
                          child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                              child: Text(e.$2.hoverLabel)))))
              .toList(),
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (e, r) => r?.touchedSection?.touchedSectionIndex == _touched
                ? null
                : setState(() => _touched =
                    !e.isInterestedForInteractions ? null : r?.touchedSection?.touchedSectionIndex),
          )),
      duration: Durations.extralong3,
      curve: Curves.easeInSine);
}
