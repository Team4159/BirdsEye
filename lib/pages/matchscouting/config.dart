import 'dart:collection' show LinkedHashMap;
import 'dart:math' as math;

import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/types.dart' show MatchScoutIdentifier, MatchScoutIdentifierPartial;
import 'package:birdseye/utils.dart' show SensibleDropdown;
import 'package:flutter/material.dart';

class MatchScoutIdentifierConfig extends StatefulWidget {
  final MatchScoutIdentifierPartial initial;
  const MatchScoutIdentifierConfig({super.key, required this.initial, required this.submit});

  final ValueChanged<MatchScoutIdentifier?> submit;

  @override
  State<StatefulWidget> createState() => _MatchScoutIdentifierConfigState();
}

class _MatchScoutIdentifierConfigState extends State<MatchScoutIdentifierConfig> {
  MatchInfo? match;
  ValueNotifier<String?> team = ValueNotifier(null);

  @override
  void initState() {
    team.addListener(() => widget.submit(match == null || team.value == null
        ? null
        : (
            season: widget.initial.season,
            event: widget.initial.event,
            match: match!,
            team: team.value!
          )));
    match = widget.initial.match;
    team.value = widget.initial.team;
    super.initState();
  }

  @override
  void dispose() {
    team.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: TextEditingController(text: widget.initial.event),
              decoration: const InputDecoration(
                  helperText: "Event",
                  counter: Icon(Icons.edit_off_rounded, size: 11, color: Colors.grey)),
              readOnly: true,
              canRequestFocus: false,
            ),
            const SizedBox(height: 12),
            _MatchSelector(
                season: widget.initial.season,
                event: widget.initial.event,
                initial: match,
                submit: (m) {
                  match = m;
                  team.value = null;
                }),
            const SizedBox(width: 12),
            _TeamSelector(
                season: widget.initial.season,
                event: widget.initial.event,
                match: match,
                initial: team.value,
                submit: (t) => team.value =
                    t) //FIXME there may need to be a setState to force rebuilds of this widget
          ]);
}

class _MatchSelector extends StatefulWidget {
  final int season;
  final String event;
  final MatchInfo? initial;
  _MatchSelector({required this.season, required this.event, this.initial, required this.submit})
      : _matchListProvider = BlueAlliance.stock.get(TBAInfo(season: season, event: event)).then(
            (matchesdata) => LinkedHashMap.fromEntries(
                matchesdata.keys.map((k) => MapEntry(k, MatchInfo.fromString(k))).toList()
                  ..sort((a, b) => a.value.compareTo(b.value))));

  final Future<LinkedHashMap<String, MatchInfo>> _matchListProvider;
  final ValueChanged<MatchInfo?>? submit;

  @override
  State<StatefulWidget> createState() => _MatchSelectorState();
}

class _MatchSelectorState extends State<_MatchSelector> {
  MatchInfo? match;
  final TextEditingController _matchController = TextEditingController();

  @override
  void initState() {
    match = widget.initial;
    super.initState();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (widget.submit != null) widget.submit!(match);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: widget._matchListProvider,
      builder: (context, snapshot) {
        int? highestQual = snapshot.data?.values
            .where((m) => m.level == MatchLevel.qualification)
            .map((m) => m.index)
            .reduce(math.max);

        if (_matchController.value.text != (match?.toString() ?? '')) {
          _matchController.value = TextEditingValue(text: match?.toString() ?? '');
        }

        return Stack(fit: StackFit.passthrough, children: [
          TextFormField(
              textAlignVertical: TextAlignVertical.center,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _matchController,
              decoration: const InputDecoration(helperText: "Match"),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              enableInteractiveSelection: false,
              autocorrect: false,
              selectionControls: EmptyTextSelectionControls(),
              enabled: snapshot.hasData,
              validator: (value) => value?.isEmpty ?? true
                  ? "Required"
                  : snapshot.data!.containsKey(value)
                      ? null
                      : "Invalid", // TODO fails at varifying non-qual matches because cache doesn't refresh
              onFieldSubmitted: (value) => setState(() => match = MatchInfo.fromString(value))),
          Align(
              alignment: Alignment.topRight,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: !snapshot.hasData
                            ? null
                            : () {
                                if (highestQual == null) return;
                                setState(() => match!.increment(highestQual: highestQual));
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
                        onPressed: !snapshot.hasData
                            ? null
                            : () {
                                if (highestQual == null) return;
                                setState(() => match!.decrement(highestQual: highestQual));
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
        ]);
      });
}

class _TeamSelector extends StatelessWidget {
  final int season;
  final String event;
  final MatchInfo? match;
  final String? initial;

  _TeamSelector(
      {required this.season,
      required this.event,
      required this.match,
      this.initial,
      required this.submit})
      : _teamListProvider = (() async {
          if (match == null) return null;
          final tbainfo = TBAInfo(season: season, event: event, match: match.toString());

          Map<String, String> tbaData;
          tbaFiller:
          if (match.level == MatchLevel.qualification) {
            tbaData = await BlueAlliance.stock.get(tbainfo);
          } else {
            try {
              final cached = await BlueAlliance.stockSoT.reader(tbainfo).single;
              if (cached != null && cached.isNotEmpty) {
                tbaData = cached.map((k, v) => MapEntry(k, v.toString()));
                break tbaFiller;
              }
            } catch (_) {}
            tbaData = await BlueAlliance.stock.fresh(tbainfo);
          }
          return (tbaData.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
              .map((e) => RobotInfo.fromString(team: e.key, position: e.value))
              .toList();
        })();

  final Future<List<RobotInfo>?> _teamListProvider;
  final ValueChanged<String?>? submit;

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _teamListProvider,
      builder: (context, snapshot) => SensibleDropdown(snapshot.data,
          label: "Team",
          initial: (snapshot.data as List<RobotInfo?>?)
              ?.singleWhere((ri) => ri!.team == initial, orElse: () => null),
          itemBuilder: (t) => DropdownMenuItem(
              value: t,
              alignment: Alignment.center,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 77),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(child: Text(t.toString())),
                        Container(
                            decoration: BoxDecoration(
                                color: t.alliance.color,
                                // .withAlpha((255 / (position.currentScouters + 1)).truncate()),
                                border: Border.all(width: 1, color: Colors.grey[800]!),
                                borderRadius: BorderRadius.circular(8)),
                            width: 20,
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.topCenter,
                            child: Center(child: Text(t.ordinal.toString())))
                      ]))),
          onChanged: (t) => submit == null ? null : submit!(t?.team)));
}

// TODO: reimplement number-of-scouters (from the sessions) with live subscribe this time
