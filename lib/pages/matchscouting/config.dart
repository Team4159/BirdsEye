import 'dart:collection' show LinkedHashMap;
import 'dart:math' as math;

import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/localstore.dart' show MatchScoutIdentifier;
import 'package:birdseye/util/sensibledropdown.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
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

class _MatchSelector extends StatelessWidget {
  final TBAInfo tbaInfo;
  final MatchInfo? initial;
  final ValueChanged<MatchInfo?>? submit;
  _MatchSelector({required int season, required String event, this.initial, required this.submit})
    : tbaInfo = TBAInfo(season: season, event: event);

  @override
  Widget build(BuildContext context) => SensibleFetcher<LinkedHashMap<String, MatchInfo>>(
    getFuture: () => BlueAlliance.stock
        .get(tbaInfo)
        .then(
          (matchesdata) => LinkedHashMap.fromEntries(
            matchesdata.keys
                .map((k) => MapEntry(k, MatchInfo.fromString(k)))
                .toList(growable: false)
              ..sort((a, b) => a.value.compareTo(b.value)),
          ),
        ),
    loadingIndicator: null,
    child: _MatchSelectorInternal(initial: initial, submit: submit),
  );
}

class _MatchSelectorInternal extends StatefulWidget {
  final MatchInfo? initial;
  final ValueChanged<MatchInfo?>? submit;
  const _MatchSelectorInternal({this.initial, this.submit});

  @override
  State<_MatchSelectorInternal> createState() => _MatchSelectorInternalState();
}

class _MatchSelectorInternalState extends State<_MatchSelectorInternal> {
  late final TextEditingController matchController;
  MatchInfo? match;

  @override
  void initState() {
    matchController = TextEditingController(text: widget.initial?.toString());
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _MatchSelectorInternal old) {
    super.didUpdateWidget(old);
    if (old.initial == widget.initial) return;
    matchController.text = widget.initial?.toString() ?? "";
  }

  void _setMatch(MatchInfo? match) {
    this.match = match;
    matchController.text = match?.toString() ?? "";
    if (widget.submit != null) widget.submit!(match);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = SensibleFetcher.of<LinkedHashMap<String, MatchInfo>>(context);

    int? highestQual;
    try {
      highestQual = snapshot.data?.values
          .where((m) => m.level == MatchLevel.qualification)
          .map((m) => m.index)
          .reduce(math.max);
    } catch (_) {
      highestQual = null;
    }

    final GlobalKey<FormFieldState<String>> fieldKey = GlobalKey();
    return Stack(
      fit: StackFit.passthrough,
      children: [
        TextFormField(
          key: fieldKey,
          textAlignVertical: TextAlignVertical.center,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          controller: matchController,
          decoration: const InputDecoration(helperText: "Match"),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.none,
          enableInteractiveSelection: false,
          autocorrect: false,
          selectionControls: EmptyTextSelectionControls(),
          enabled: snapshot.data != null,
          validator: (value) {
            if (value == null || value.isEmpty) return "Required";
            if (snapshot.data!.containsKey(value)) return null;
            if (MatchInfo.looksLikeFinals(value)) {
              snapshot.refresh().then((_) => fieldKey.currentState?.validate());
              return "Loading";
            }
            return "Invalid";
          },
          onChanged: (value) {
            if (match == null) return;
            match = null;
            if (widget.submit != null) widget.submit!(match);
          },
          onFieldSubmitted: (value) {
            final mat = snapshot.data![value];
            if (mat == null) return;
            match = mat;
            if (widget.submit != null) widget.submit!(match);
          },
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: snapshot.data == null || highestQual == null
                  ? null
                  : () => _setMatch(
                      match?.increment(highestQual: highestQual!) ??
                          MatchInfo(level: MatchLevel.qualification, index: 1),
                    ),
              constraints: const BoxConstraints(),
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              iconSize: 28,
              icon: const Icon(Icons.arrow_drop_up_rounded),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: snapshot.data == null || highestQual == null
                  ? null
                  : () => _setMatch(
                      match?.decrement(highestQual: highestQual!) ??
                          MatchInfo(level: MatchLevel.qualification, index: highestQual!),
                    ),
              constraints: const BoxConstraints(),
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              iconSize: 28,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamSelector extends StatelessWidget {
  final int season;
  final String event;
  final MatchInfo? match;
  final String? initial;

  const _TeamSelector({
    required this.season,
    required this.event,
    required this.match,
    this.initial,
    required this.submit,
  });

  final ValueChanged<String?> submit;

  Future<List<RobotInfo>> _reload() async {
    if (match == null) return Future.value([]);
    final tbainfo = TBAInfo(season: season, event: event, match: match!.toString());

    Map<String, String> tbaData;
    tbaFiller:
    if (match!.level == MatchLevel.qualification) {
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
    return tbaData.entries
        .map((e) => RobotInfo.fromString(team: e.key, position: e.value))
        .toList(growable: false)
      ..sort();
  }

  @override
  Widget build(BuildContext context) => SensibleFetcher<List<RobotInfo>>(
    getFuture: _reload,
    loadingIndicator: null,
    builtInRefresh: false,
    child: _TeamSelectorInternal(initial: initial, submit: submit),
  );
}

class _TeamSelectorInternal extends StatelessWidget {
  const _TeamSelectorInternal({this.initial, required this.submit});

  final String? initial;
  final ValueChanged<String?> submit;

  @override
  Widget build(BuildContext context) {
    final snapshot = SensibleFetcher.of<List<RobotInfo>>(context);

    return SizedBox.fromSize(
      size: Size(75, 60),
      child: CustomDropdown(
        // decoration: const InputDecoration(helperText: "Team"),
        value: snapshot.data?.cast<RobotInfo?>().singleWhere(
          (ri) => ri?.team == initial,
          orElse: () => null,
        ),
        items: snapshot.data == null
            ? null
            : [
                for (final t in snapshot.data!)
                  DropdownMenuItem(
                    value: t,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(child: Text(t.toString())),
                        Container(
                          decoration: BoxDecoration(
                            color: t.alliance.color,
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
              ],
        onChanged: (t) => submit(t?.team),
      ),
    );
  }
}

typedef MatchScoutIdentifierPartial = ({int season, String event, MatchInfo? match, String? team});
