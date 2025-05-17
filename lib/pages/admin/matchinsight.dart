import 'package:birdseye/pages/configuration.dart';
import 'package:flutter/material.dart';

import '../../interfaces/analysis.dart';
import '../../interfaces/bluealliance.dart';

class MatchInsightPage extends StatefulWidget {
  const MatchInsightPage({super.key});

  @override
  State<StatefulWidget> createState() => _MatchInsightPageState();
}

class _MatchInsightPageState extends State<MatchInsightPage> {
  Map<String, MatchInfo>? _matchList;
  int _highestQual = -1;
  MatchInfo? _selectedMatch;

  @override
  void initState() {
    super.initState();
    if (Configuration.event == null) return;
    BlueAlliance.stock
        .get(TBAInfo(
            season: Configuration.instance.season, event: Configuration.event!, match: null))
        .then((resp) => setState(() {
              _matchList = Map.fromEntries(
                  resp.keys.map((matchKey) => MapEntry(matchKey, MatchInfo.fromString(matchKey))));

              _highestQual = (_matchList!.values
                          .where((element) => element.level == MatchLevel.qualification)
                          .toList()
                        ..sort((a, b) => b.index - a.index))
                      .firstOrNull
                      ?.index ??
                  -1;
            }));
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Align(
            alignment: Alignment.topRight,
            child: SizedBox(
                width: 120,
                child: Stack(fit: StackFit.passthrough, children: [
                  TextFormField(
                      textAlignVertical: TextAlignVertical.center,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(helperText: "Match"),
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      enableInteractiveSelection: false,
                      autocorrect: false,
                      selectionControls: EmptyTextSelectionControls(),
                      controller: TextEditingController(text: _selectedMatch?.toString()),
                      validator: (value) => value?.isEmpty ?? true
                          ? "Required"
                          : _matchList?.containsKey(value) ?? false
                              ? null
                              : "Invalid", // TODO fails at varifying non-qual matches because cache doesn't refresh
                      onChanged: _matchList == null
                          ? null
                          : (value) => _matchList!.containsKey(value)
                              ? setState(() => _selectedMatch = _matchList![value])
                              : null),
                  Align(
                      alignment: Alignment.topRight,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: _matchList == null
                                    ? null
                                    : () {
                                        if (_highestQual < 1) return;
                                        setState(() => _selectedMatch = MatchInfo(
                                            level: MatchLevel.qualification,
                                            index: (_selectedMatch == null
                                                    ? 1
                                                    : _selectedMatch!.index + 1)
                                                .clamp(1, _highestQual)));
                                      },
                                constraints: const BoxConstraints(),
                                style: const ButtonStyle(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                iconSize: 28,
                                icon: const Icon(Icons.arrow_drop_up_rounded),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero),
                            IconButton(
                                onPressed: _matchList == null
                                    ? null
                                    : () {
                                        if (_highestQual < 1) return;
                                        setState(() => _selectedMatch = MatchInfo(
                                            level: MatchLevel.qualification,
                                            index: (_selectedMatch == null
                                                    ? _highestQual
                                                    : _selectedMatch!.index - 1)
                                                .clamp(1, _highestQual)));
                                      },
                                constraints: const BoxConstraints(),
                                style: const ButtonStyle(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                iconSize: 28,
                                icon: const Icon(Icons.arrow_drop_down_rounded),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero)
                          ]))
                ]))),
        const SizedBox(
          height: 8,
        ),
        if (_selectedMatch != null)
          Expanded(
              child: MatchInsight(
                  Configuration.instance.season, Configuration.event!, _selectedMatch!))
        else
          Text("Select A Match for ${Configuration.instance.season}${Configuration.event!}")
      ]);
}

class MatchInsight extends StatelessWidget {
  MatchInsight(int season, String event, MatchInfo match, {super.key})
      : future = Analysis.matchEPA(season, event, match);
  final Future future;

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: future,
      builder: (context, snapshot) => !snapshot.hasData
          ? snapshot.hasError
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                      Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                      const SizedBox(height: 20),
                      Text(snapshot.error.toString())
                    ])
              : const Center(child: CircularProgressIndicator())
          : Column(children: [
              LinearProgressIndicator(
                value: snapshot.data!["red"]["winChance"],
                backgroundColor: frcblue,
                color: frcred,
                minHeight: 8,
              ),
              const SizedBox(height: 4),
              Text(snapshot.data!["red"]["winChance"] > 0.5
                  ? "Red Wins ${(snapshot.data!["red"]["winChance"] * 100).toStringAsFixed(0)}%"
                  : snapshot.data!["blue"]["winChance"] > 0.5
                      ? "Blue Wins ${(snapshot.data!["blue"]["winChance"] * 100).toStringAsFixed(0)}%"
                      : "Tie"),
              const SizedBox(height: 16),
              Expanded(
                  child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final alliance in [
                                  snapshot.data!["red"],
                                  snapshot.data!["blue"]
                                ])
                                  Column(children: [
                                    Text("${alliance["points"].toStringAsFixed(2)} Points"),
                                    const SizedBox(height: 16),
                                    Flex(
                                      direction:
                                          constraints.biggest.width > constraints.biggest.height
                                              ? Axis.horizontal
                                              : Axis.vertical,
                                      children: [
                                        for (final MapEntry(key: rpname, value: rpchance)
                                            in alliance["rp"].entries)
                                          Chip(
                                              avatar:
                                                  Text("${(rpchance * 100).toStringAsFixed(0)}%"),
                                              label: Text(rpname))
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Flex(
                                        direction:
                                            constraints.biggest.width > constraints.biggest.height
                                                ? Axis.horizontal
                                                : Axis.vertical,
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          for (final team in alliance["teams"]) ...[
                                            Text(team),
                                            const SizedBox(width: 8)
                                          ]
                                        ])
                                  ])
                              ])))
            ]));
}
