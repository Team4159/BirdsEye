import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../interfaces/bluealliance.dart';
import '../../interfaces/supabase.dart';
import '../../main.dart';
import '../../utils.dart';
import '../metadata.dart';
import 'admin.dart';

// FIXME cache supabase responses

class StatGraphPage extends StatelessWidget {
  final AnalysisInfo info = AnalysisInfo();
  StatGraphPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 3,
      child: Scaffold(
          drawer: Drawer(
              width: 250,
              child: ListenableBuilder(
                  listenable: UserMetadata.instance.cachedPermissions,
                  builder: (context, _) => Column(children: [
                        ListTile(
                            leading: const Icon(Icons.chevron_left_rounded),
                            title: const Text("Back"),
                            onTap: () => GoRouter.of(context)
                              ..pop()
                              ..goNamed(RoutePaths.configuration.name)),
                        const Divider(),
                        ListTile(
                            leading: const Icon(Icons.auto_graph_rounded),
                            title: const Text("Stat Graphs"),
                            enabled: UserMetadata.instance.cachedPermissions.value.graphViewer,
                            onTap: () => GoRouter.of(context)
                              ..pop()
                              ..goNamed(AdminRoutePaths.statgraphs.name)),
                        ListTile(
                            leading: const Icon(Icons.queue_rounded),
                            title: const Text("Achievement Queue"),
                            enabled:
                                UserMetadata.instance.cachedPermissions.value.achievementApprover,
                            onTap: () => GoRouter.of(context)
                              ..pop()
                              ..goNamed(AdminRoutePaths.achiqueue.name)),
                        ListTile(
                            leading: const Icon(Icons.manage_search_rounded),
                            title: const Text("Qualitative Analysis"),
                            enabled:
                                UserMetadata.instance.cachedPermissions.value.qualitativeAnalyzer,
                            onTap: () => GoRouter.of(context)
                              ..pop()
                              ..goNamed(AdminRoutePaths.qualanaly.name))
                      ]))),
          appBar: AppBar(
              title: const Text("Statistic Graphs"),
              bottom: TabBar(
                  tabs: [
                    ValueTab(
                        SupabaseInterface.getAvailableSeasons().then((s) => s.toList()..add(0)),
                        initialPositionCallback: (ss) {
                          if (info.season == null) return ss.length - 1;
                          var i = ss.indexOf(info.season!);
                          return i >= 0 ? i : ss.length - 1;
                        },
                        onChange: (s) => info.season = s == 0 ? null : s),
                    ListenableBuilder(
                        listenable: info.seasonNotifier,
                        builder: (context, _) => ValueTab(
                            info.season == null
                                ? Future<List<String>>.error({})
                                : Supabase.instance.client
                                    .from("${info.season}_match")
                                    .select("event")
                                    .withConverter(
                                        (data) => data.map((e) => e["event"] as String).toSet())
                                    .then((e) => e.toList()..add("")),
                            initialPositionCallback: (ss) {
                              if (info.event == null) return ss.length - 1;
                              var i = ss.indexOf(info.event!);
                              return i >= 0 ? i : ss.length - 1;
                            },
                            onChange: (e) => info.event = e.isEmpty ? null : e)),
                    ListenableBuilder(
                        listenable: info.seasoneventNotifier,
                        builder: (context, _) {
                          Future<List<String>> out;
                          if (info.season == null) {
                            out = Future.error({});
                          } else {
                            var query = Supabase.instance.client
                                .from("${info.season}_match")
                                .select("team");
                            if (info.event != null) query = query.eq("event", info.event!);
                            out = query
                                .withConverter(
                                    (data) => data.map((e) => e["team"].toString()).toSet())
                                .then((t) => t.toList()..add(""));
                          }
                          return ValueTab(out,
                              initialPositionCallback: (ss) {
                                if (info.team == null) return ss.length - 1;
                                var i = ss.indexOf(info.team!);
                                return i >= 0 ? i : ss.length - 1;
                              },
                              onChange: (t) => info.team = t.isEmpty ? null : t);
                        })
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
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                    alignment: Alignment.topCenter,
                    // FIXME https://supabase.com/blog/postgrest-12#aggregate-functions
                    child: TabBarView(
                        children: [
                      ListenableBuilder(
                          listenable: info.seasonNotifier,
                          builder: (context, _) => ValueDetailTabView(info.season == null
                              ? Future.value(["No Season Selected"])
                              : Supabase.instance.client
                                  .from("${info.season!}_match")
                                  .select("scouter, event, match, team")
                                  .withConverter((resp) => (
                                        scouters: resp.map((e) => e["scouter"]).toSet().length,
                                        matches:
                                            resp.map((e) => e["event"] + e["match"]).toSet().length,
                                        teams: resp.map((e) => e["team"]).toSet().length
                                      ))
                                  .then((data) => [
                                        "${data.scouters} Scouter${data.scouters != 1 ? 's' : ''}",
                                        "${data.matches} Match${data.matches != 1 ? 'es' : ''}",
                                        "${data.teams} Team${data.teams != 1 ? 's' : ''}"
                                      ]))),
                      ListenableBuilder(
                          listenable: info.seasoneventNotifier,
                          builder: (context, _) => ValueDetailTabView(info.event == null
                              ? Future.value(["No Event Selected"])
                              : info.season == null
                                  ? Future.value(["No Season Selected"])
                                  : Supabase.instance.client
                                      .from("${info.season!}_match")
                                      .select("scouter, match, team")
                                      .eq("event", info.event!)
                                      .withConverter((resp) => (
                                            scouters: resp.map((e) => e["scouter"]).toSet().length,
                                            matches: resp.map((e) => e["match"]).toSet().length,
                                            teams: resp.map((e) => e["team"]).toSet().length
                                          ))
                                      .then((data) => [
                                            "${data.scouters} Scouter${data.scouters != 1 ? 's' : ''}",
                                            "${data.matches} Match${data.matches != 1 ? 'es' : ''}",
                                            "${data.teams} Team${data.teams != 1 ? 's' : ''}"
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
                              var query = Supabase.instance.client
                                  .from("${info.season!}_match")
                                  .select("match")
                                  .eq("team", info.team!);
                              if (info.event != null) query = query.eq("event", info.event!);
                              out = Future.wait(<Future<List<String>>>[
                                query
                                    .withConverter(
                                        (data) => data.map((e) => e["match"]).toSet().length)
                                    .then((data) => ["$data Match${data != 1 ? 'es' : ''}"]),
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
                    ]
                            .map((e) => DecoratedBox(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: const ToplessHitchedBorder(
                                        BorderSide(width: 3.5, color: Colors.white))),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16), child: e)))
                            .toList()))),
            Flexible(
                flex: 3,
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
  final CarouselController _carouselController = CarouselController();
  final ValueNotifier<bool> _searchMode = ValueNotifier(false);

  @override
  Widget build(BuildContext context) => Tab(
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular((FilledButtonTheme.of(context)
                          .style
                          ?.fixedSize
                          ?.resolve({MaterialState.disabled})?.height ??
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
                        if (onChange != null && initialPositionCallback == null) {
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => onChange!(snapshot.data!.last));
                        }
                        var stringifiedOptions =
                            LinkedHashSet.of(snapshot.data!.map((e) => e.toString()));
                        return ListenableBuilder(
                            listenable: _searchMode,
                            builder: (context, _) =>
                                IndexedStack(index: _searchMode.value ? 0 : 1, children: [
                                  Autocomplete<T>(
                                      optionsBuilder: (input) => snapshot.data!
                                          .where((e) => e.toString().startsWith(input.toString())),
                                      fieldViewBuilder: (context, textEditingController, focusNode,
                                              onFieldSubmitted) =>
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
                                              inputFormatters: T == int
                                                  ? [FilteringTextInputFormatter.digitsOnly]
                                                  : T == double
                                                      ? [
                                                          FilteringTextInputFormatter.allow(
                                                              RegExp(r"[0-9.]"))
                                                        ]
                                                      : [],
                                              controller: textEditingController..clear(),
                                              focusNode: focusNode..canRequestFocus = true,
                                              onFieldSubmitted: (value) {
                                                if (!stringifiedOptions.contains(value)) return;
                                                onFieldSubmitted();
                                                var v = stringifiedOptions.toList().indexOf(value);
                                                _carouselController.jumpToPage(v);
                                                if (onChange != null) onChange!(snapshot.data![v]);
                                                _searchMode.value = false;
                                              },
                                              autovalidateMode: AutovalidateMode.onUserInteraction,
                                              validator: (value) =>
                                                  stringifiedOptions.contains(value)
                                                      ? null
                                                      : "Invalid",
                                              textAlign: TextAlign.center,
                                              textAlignVertical: TextAlignVertical.center),
                                      onSelected: (value) {
                                        if (onChange != null) onChange!(value);
                                        _carouselController
                                            .jumpToPage(snapshot.data!.indexOf(value));
                                        _searchMode.value = false;
                                      }),
                                  CarouselSlider(
                                      carouselController: _carouselController,
                                      items: snapshot.data!
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall!
                                                    .copyWith(fontSize: 22),
                                              ))
                                          .toList(),
                                      options: CarouselOptions(
                                          height: 40,
                                          viewportFraction: 1,
                                          scrollDirection: Axis.horizontal,
                                          initialPage: initialPositionCallback == null
                                              ? snapshot.data!.length - 1
                                              : initialPositionCallback!(snapshot.data!),
                                          enableInfiniteScroll: snapshot.data!.length > 3,
                                          onPageChanged: (i, _) =>
                                              onChange == null || snapshot.data!.length <= i
                                                  ? null
                                                  : onChange!(snapshot.data![i])))
                                ]));
                      })))));
}

class ValueDetailTabView extends StatelessWidget {
  final FutureOr<List<String>> detail;
  const ValueDetailTabView(this.detail, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: Future.value(detail),
      builder: (context, snapshot) => !snapshot.hasData
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth > 3 * constraints.maxHeight
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(snapshot.data!.join(", "),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                          textScaler: const TextScaler.linear(1.5)))
                  : Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: snapshot.data!
                          .map((e) => Text(
                                e,
                                style: Theme.of(context).textTheme.labelLarge,
                                textScaler: const TextScaler.linear(1.3),
                              ))
                          .toList())));
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
  String? get event => _event?.toLowerCase();
  set event(String? e) {
    _event = e;
    seasoneventNotifier.notifyListeners();
    notifyListeners();
  }

  ChangeNotifier seasoneventNotifier = ChangeNotifier();

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
        Supabase.instance.client.functions
            .invoke(
              "match_aggregator_js?season=$season&event=$event", // workaround for lack of query params
            )
            .then((resp) => resp.status >= 400
                ? throw Exception("HTTP Error ${resp.status}")
                : (Map<String, dynamic>.from(resp.data) // match:
                        .map((key, value) =>
                            MapEntry(key, Map<String, dynamic>.from(value))) // team:
                      ..removeWhere((key, value) => !value.containsKey(team)))
                    .map((key, value) => MapEntry(parseMatchInfo(key)!,
                        Map<String, num>.from(value[team]))) // match: {scoretype: aggregated_count}
                    .entries
                    .toSet()),
        BlueAlliance.stock
            .get((season: season, event: event, match: null))
            .then((eventMatches) => Future.wait(eventMatches.keys.map((match) => BlueAlliance.stock
                .get((season: season, event: event, match: match)).then(
                    (teams) => teams.keys.contains(team) ? match : null))))
            .then((unparsedEventMatches) => unparsedEventMatches
                .where((match) => match != null)
                .map((match) => parseMatchInfo(match)!)
                .toList()
              ..sort((a, b) => compareMatchInfo(b, a)))
      ]).then((results) => (
            data: results[0] as Set<MapEntry<MatchInfo, Map<String, num>>>,
            ordinalMatches: results[1] as List<MatchInfo>
          )),
      builder: (context, snapshot) => snapshot.hasError
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  const SizedBox(height: 20),
                  Text(snapshot.error.toString())
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
                                    axisSide: AxisSide.bottom,
                                    child:
                                        Text(stringifyMatchInfo(snapshot.data!.ordinalMatches[n])));
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
                                spots: snapshot.data!.data
                                    .map((e) => FlSpot(
                                        snapshot.data!.ordinalMatches.indexOf(e.key).toDouble(),
                                        scoreTotal(e.value, season: season, period: period)
                                            .toDouble()))
                                    .toList(growable: false)
                                  ..sort((a, b) => a.x == b.x
                                      ? 0
                                      : a.x > b.x
                                          ? 1
                                          : -1))
                        ],
                  extraLinesData: ExtraLinesData(
                      horizontalLines: !snapshot.hasData || snapshot.data!.data.isEmpty
                          ? []
                          : [
                              HorizontalLine(
                                  y: snapshot.data!.data
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
      future: Supabase.instance.client.functions
          .invoke(
            "match_aggregator_js?season=$season&team=$team", // workaround for lack of query params
          )
          .then((resp) => resp.status >= 400
              ? throw Exception("HTTP Error ${resp.status}")
              : Map.fromEntries(Map<String, dynamic>.from(resp.data)
                  .entries
                  .map((evententry) => Map<String, dynamic>.from(evententry.value) // event:
                      .map((matchstring, matchscores) => MapEntry(
                          //  match:
                          (event: evententry.key, match: parseMatchInfo(matchstring)!),
                          Map<String, num>.from(matchscores))))
                  .expand((e) => e.entries)))
          .then((result) {
        Map<GamePeriod, double> op = {};
        Map<String, double> ot = {};
        Map<String, double> om = {};
        for (Map<String, num> matchScores in result.values) {
          for (MapEntry<GamePeriod, num> periodScore
              in scoreTotalByPeriod(matchScores, season: season).entries) {
            op[periodScore.key] = (op[periodScore.key] ?? 0) + periodScore.value;
          }
          for (MapEntry<String, num> typeScore
              in scoreTotalByType(matchScores, season: season).entries) {
            ot[typeScore.key] = (ot[typeScore.key] ?? 0) + typeScore.value;
          }
          for (MapEntry<String, num> miscVals
              in nonScoreFilter(matchScores, season: season).entries) {
            om[miscVals.key] = (om[miscVals.key] ?? 0) + miscVals.value;
          }
        }
        return (
          period: op.map((key, value) => MapEntry(key, value / result.values.length.toDouble())),
          type: ot,
          misc: om.map((key, value) => MapEntry(key, value / result.values.length.toDouble()))
        );
      }),
      builder: (context, snapshot) => Flex(
          direction: MediaQuery.of(context).size.width > 600 ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PieChart(
                PieChartData(
                    centerSpaceRadius: 100,
                    sections: !snapshot.hasData
                        ? []
                        : snapshot.data!.period.entries
                            .map((e) => PieChartSectionData(
                                value: e.value,
                                title: e.key.name,
                                color: e.key.graphColor,
                                showTitle: true,
                                titleStyle: Theme.of(context).textTheme.labelSmall,
                                borderSide:
                                    BorderSide(color: Theme.of(context).colorScheme.outline)))
                            .toList()),
                swapAnimationDuration: Durations.extralong3,
                swapAnimationCurve: Curves.easeInSine),
            PieChart(
                PieChartData(
                    centerSpaceRadius: 100,
                    sections: !snapshot.hasData
                        ? []
                        : snapshot.data!.type.entries
                            .map((e) => PieChartSectionData(
                                value: e.value,
                                title: e.key,
                                color: Theme.of(context).colorScheme.primaryContainer,
                                showTitle: true,
                                titleStyle: Theme.of(context).textTheme.labelSmall,
                                borderSide:
                                    BorderSide(color: Theme.of(context).colorScheme.outline)))
                            .toList()),
                swapAnimationDuration: Durations.extralong3,
                swapAnimationCurve: Curves.easeInSine)
          ]
              .map<Widget>((e) => Flexible(
                  child: ConstrainedBox(
                      constraints: BoxConstraints.tight(const Size.square(400)),
                      child: Transform.scale(
                          scale: min(MediaQuery.of(context).size.shortestSide / 400, 1),
                          child: e))))
              .followedBy([
            if (season == 2024 && snapshot.hasData)
              Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: {
                    if (snapshot.data!.misc.containsKey('comments_agility'))
                      "Agility": snapshot.data!.misc['comments_agility']!,
                    if (snapshot.data!.misc.containsKey('comments_contribution'))
                      "Contribution": snapshot.data!.misc['comments_contribution']!
                  }
                      .entries
                      .map((e) => Card.filled(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 70),
                              child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(e.key),
                                        Text("${(e.value * 5).toStringAsFixed(1)} / 5")
                                      ])))))
                      .toList())
          ]).toList()));
}

class EventInSeasonRankings extends StatelessWidget {
  final int season;
  final String event;
  const EventInSeasonRankings({super.key, required this.season, required this.event});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: Supabase.instance.client.functions
          .invoke("event_aggregator?season=$season&event=$event")
          .then((resp) => resp.status >= 400
              ? throw Exception("HTTP Error ${resp.status}")
              : LinkedHashMap.fromEntries(Map<String, double?>.from(resp.data)
                  .entries
                  .whereType<MapEntry<String, double>>()
                  .toList()
                ..sort((a, b) => a.value == b.value
                    ? 0
                    : a.value > b.value
                        ? -1
                        : 1))),
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
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: snapshot.data!.entries
                      .map((e) =>
                          ListTile(title: Text(e.key), trailing: Text(e.value.toStringAsFixed(2))))
                      .toList()));
}
