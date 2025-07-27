import 'dart:collection' show LinkedHashMap;
import 'dart:math' as math;

import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/types.dart' show MatchScoutIdentifier, MatchScoutIdentifierPartial;
import 'package:birdseye/utils.dart' show SensibleDropdown;
import 'package:flutter/material.dart';

class MatchScoutConfig extends StatefulWidget {
  final MatchScoutIdentifierPartial initial;
  const MatchScoutConfig({super.key, required this.initial, required this.submit});

  final ValueChanged<MatchScoutIdentifier?> submit;

  @override
  State<StatefulWidget> createState() => _MatchScoutConfigState();
}

class _MatchScoutConfigState extends State<MatchScoutConfig> {
  late final ValueNotifier<MatchInfo?> match;
  String? teamInitial;

  @override
  void initState() {
    match = ValueNotifier(widget.initial.match);
    teamInitial = widget.initial.team;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant MatchScoutConfig oldWidget) {
    match.value = widget.initial.match;
    teamInitial = widget.initial.team;
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    match.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints.loose(Size.fromWidth(120)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            textAlignVertical: TextAlignVertical.center,
            controller: TextEditingController(text: widget.initial.event),
            decoration: const InputDecoration(
              helperText: "Event",
              counter: Icon(Icons.edit_off_rounded, size: 11, color: Colors.grey),
            ),
            readOnly: true,
            canRequestFocus: false,
          ),
          const SizedBox(height: 12),
          _MatchSelector(
            season: widget.initial.season,
            event: widget.initial.event,
            initial: match.value,
            submit: (m) {
              teamInitial = null;
              match.value = m;
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: match,
            builder: (context, match, _) => _TeamSelector(
              season: widget.initial.season,
              event: widget.initial.event,
              match: match,
              initial: teamInitial,
              submit: (t) => widget.submit(
                match == null || t == null
                    ? null
                    : (
                        season: widget.initial.season,
                        event: widget.initial.event,
                        match: match,
                        team: t,
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MatchSelector extends StatefulWidget {
  final int season;
  final String event;
  final MatchInfo? initial;
  _MatchSelector({required this.season, required this.event, this.initial, required this.submit})
    : _matchListProvider = BlueAlliance.stock
          .get(TBAInfo(season: season, event: event))
          .then(
            (matchesdata) => LinkedHashMap.fromEntries(
              matchesdata.keys.map((k) => MapEntry(k, MatchInfo.fromString(k))).toList()
                ..sort((a, b) => a.value.compareTo(b.value)),
            ),
          );

  final Future<LinkedHashMap<String, MatchInfo>> _matchListProvider;
  final ValueChanged<MatchInfo?>? submit;

  @override
  State<StatefulWidget> createState() => _MatchSelectorState();
}

class _MatchSelectorState extends State<_MatchSelector> {
  MatchInfo? match;
  late final TextEditingController _matchController;

  @override
  void initState() {
    match = widget.initial;
    _matchController = TextEditingController(text: match?.toString() ?? '');
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _MatchSelector oldWidget) {
    match = widget.initial;
    _matchController.value = TextEditingValue(text: match?.toString() ?? '');
    super.didUpdateWidget(oldWidget);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _matchController.value = TextEditingValue(text: match?.toString() ?? '');
    if (widget.submit != null) widget.submit!(match);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: widget._matchListProvider,
    builder: (context, snapshot) {
      int? highestQual;
      try {
        highestQual = snapshot.data?.values
            .where((m) => m.level == MatchLevel.qualification)
            .map((m) => m.index)
            .reduce(math.max);
      } catch (_) {
        highestQual = null;
      }

      return Stack(
        fit: StackFit.passthrough,
        children: [
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
                : "Invalid",
            onFieldSubmitted: (value) => setState(() => match = MatchInfo.fromString(value)),
          ),
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
                          setState(
                            () => match =
                                match?.increment(highestQual: highestQual!) ??
                                MatchInfo(level: MatchLevel.qualification, index: 1),
                          );
                        },
                  constraints: const BoxConstraints(),
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  iconSize: 28,
                  icon: const Icon(Icons.arrow_drop_up_rounded),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: !snapshot.hasData
                      ? null
                      : () {
                          if (highestQual == null) return;
                          setState(
                            () => match =
                                match?.decrement(highestQual: highestQual!) ??
                                MatchInfo(level: MatchLevel.qualification, index: highestQual!),
                          );
                        },
                  constraints: const BoxConstraints(),
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  iconSize: 28,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _TeamSelector extends StatelessWidget {
  final String? initial;

  _TeamSelector({
    required int season,
    required String event,
    required MatchInfo? match,
    this.initial,
    required this.submit,
  }) : _teamsProvider = Future(() async {
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
       });

  final ValueChanged<String?> submit;
  final Future<List<RobotInfo>?> _teamsProvider;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _teamsProvider,
    builder: (context, snapshot) => SensibleDropdown(
      snapshot.data,
      label: "Team",
      initial: snapshot.data?.cast<RobotInfo?>().singleWhere(
        (ri) => ri?.team == initial,
        orElse: () => null,
      ),
      itemBuilder: (t) => DropdownMenuItem(
        value: t,
        alignment: Alignment.center,
        child: SizedBox.fromSize(
          size: Size.fromWidth(75),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(t.toString())),
              Container(
                decoration: BoxDecoration(
                  color: t.alliance.color,
                  // TODO: reimplement number-of-scouters (from the sessions) with live subscribe this time
                  // .withAlpha((255 / (position.currentScouters + 1)).truncate()),
                  border: Border.all(width: 1, color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: 20,
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.topCenter,
                child: Center(child: Text(t.ordinal.toString())),
              ),
            ],
          ),
        ),
      ),
      onChanged: (t) => submit(t?.team),
    ),
  );
}
