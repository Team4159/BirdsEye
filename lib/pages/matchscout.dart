import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/localstore.dart';
import '../interfaces/supabase.dart';
import '../widgets/resetbutton.dart';
import './configuration.dart';

typedef MatchScoutQuestionSchema
    = Map<String, Map<String, MatchScoutQuestionTypes>>;

enum MatchScoutQuestionTypes<T> {
  text<String>(sqlType: "text"),
  counter<int>(sqlType: "smallint"), // int2
  toggle<bool>(sqlType: "boolean"), // bool
  slider<double>(sqlType: "real"), // float4
  error<void>(sqlType: "any");

  final String sqlType;
  const MatchScoutQuestionTypes({required this.sqlType});
  static MatchScoutQuestionTypes fromSQLType(String s) =>
      MatchScoutQuestionTypes.values.firstWhere((type) => type.sqlType == s,
          orElse: () => MatchScoutQuestionTypes.error);
}

Future<void> submitInfo(Map<String, dynamic> data, {int? season}) async =>
    await SupabaseInterface.canConnect
        ? Supabase.instance.client
            .from("${season ?? Configuration.instance.season}_match")
            .insert(data)
        : LocalStoreInterface.addMatch(
            season ?? Configuration.instance.season, data);

class MatchScoutPage extends StatefulWidget {
  const MatchScoutPage({super.key});

  @override
  State<MatchScoutPage> createState() => _MatchScoutPageState();
}

class _MatchScoutPageState extends State<MatchScoutPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final GlobalKey<_MatchScoutInfoFieldsState> _infoKey = GlobalKey();
  final Map<String, dynamic> _fields = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    SupabaseInterface.setSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
            const SliverAppBar(
                primary: true,
                floating: true,
                snap: true,
                title: Text("Match Scouting")),
            SliverToBoxAdapter(
                child: _MatchScoutInfoFields(
                    key: _infoKey,
                    onUpdate: () {
                      SupabaseInterface.setSession(
                          match: _infoKey.currentState!.match,
                          team: _infoKey.currentState!.team);
                      setState(() {});
                    }))
          ],
      body: FutureBuilder(
          future: SupabaseInterface.matchSchema,
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
              : AnimatedSlide(
                  offset: (_infoKey.currentState?.isFilled ?? false)
                      ? Offset.zero
                      : const Offset(0, 1),
                  curve: Curves.easeInOutCirc,
                  duration: const Duration(seconds: 1),
                  child: Form(
                      key: _formKey,
                      child: CustomScrollView(
                          cacheExtent: double.infinity,
                          slivers: [
                            for (var MapEntry(key: section, value: contents)
                                in snapshot.data!.entries) ...[
                              SliverAppBar(
                                  primary: false,
                                  excludeHeaderSemantics: true,
                                  automaticallyImplyLeading: false,
                                  centerTitle: true,
                                  title: Text(section,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                      textScaleFactor: 1.5)),
                              SliverPadding(
                                  padding: const EdgeInsets.only(
                                      bottom: 12, left: 6, right: 6),
                                  sliver: SliverGrid.count(
                                      crossAxisCount: 2,
                                      childAspectRatio:
                                          MediaQuery.of(context).size.width >
                                                  450
                                              ? 3
                                              : 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 12,
                                      children: [
                                        for (var MapEntry(
                                              key: field,
                                              value: type
                                            ) in contents.entries)
                                          switch (type) {
                                            MatchScoutQuestionTypes.text => TextFormField(
                                                maxLines: null,
                                                expands: true,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer),
                                                cursorColor: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                decoration: InputDecoration(
                                                    labelText: field
                                                        .split("_")
                                                        .map((s) =>
                                                            s[0].toUpperCase() +
                                                            s.substring(1))
                                                        .join(" "),
                                                    filled: true,
                                                    fillColor: Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer
                                                        .withAlpha(75),
                                                    labelStyle: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSecondaryContainer,
                                                        fontWeight: FontWeight.w500),
                                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer, width: 3)),
                                                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer, width: 2))),
                                                onSaved: (i) => _fields["${section}_$field"] = i),
                                            MatchScoutQuestionTypes.counter =>
                                              CounterFormField(
                                                  labelText: field
                                                      .split("_")
                                                      .map((s) =>
                                                          s[0].toUpperCase() +
                                                          s.substring(1))
                                                      .join(" "),
                                                  onSaved: (i) => _fields[
                                                      "${section}_$field"] = i),
                                            MatchScoutQuestionTypes.slider =>
                                              RatingFormField(
                                                  labelText: field
                                                      .split("_")
                                                      .map((s) =>
                                                          s[0].toUpperCase() +
                                                          s.substring(1))
                                                      .join(" "),
                                                  onSaved: (i) => _fields[
                                                      "${section}_$field"] = i),
                                            MatchScoutQuestionTypes.toggle =>
                                              ToggleFormField(
                                                  labelText: field
                                                      .split("_")
                                                      .map((s) =>
                                                          s[0].toUpperCase() +
                                                          s.substring(1))
                                                      .join(" "),
                                                  onSaved: (i) => _fields[
                                                      "${section}_$field"] = i),
                                            MatchScoutQuestionTypes.error =>
                                              Material(
                                                  type: MaterialType.button,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .errorContainer,
                                                  child: Center(
                                                      child: Text(field)))
                                          }
                                      ]))
                            ],
                            SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverToBoxAdapter(
                                    child: Row(children: [
                                  Expanded(
                                      child: FilledButton(
                                          child: const Text("Submit"),
                                          onPressed: () {
                                            _fields.clear();
                                            _formKey.currentState!.save();
                                            submitInfo({
                                              "event": Configuration.event,
                                              "match":
                                                  _infoKey.currentState!.match,
                                              "team":
                                                  _infoKey.currentState!.team,
                                              ..._fields
                                            }).then((_) async {
                                              _formKey.currentState!.reset();
                                              await _scrollController.animateTo(
                                                  0,
                                                  duration: const Duration(
                                                      seconds: 1),
                                                  curve: Curves.easeOutBack);
                                              _infoKey.currentState!.reset();
                                            }).catchError((e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content:
                                                          Text(e.toString())));
                                            });
                                          })),
                                  const SizedBox(width: 10),
                                  DeleteConfirmation(
                                      context: context,
                                      reset: () async {
                                        _formKey.currentState!.reset();
                                        await _scrollController.animateTo(0,
                                            duration: const Duration(
                                                milliseconds: 1500),
                                            curve: Curves.easeOutBack);
                                        _infoKey.currentState!.reset();
                                      })
                                ])))
                          ])))));
}

class _MatchScoutInfoFields extends StatefulWidget {
  final VoidCallback? onUpdate;
  const _MatchScoutInfoFields({super.key, this.onUpdate});

  @override
  State<StatefulWidget> createState() => _MatchScoutInfoFieldsState();
}

class _MatchScoutInfoFieldsState extends State<_MatchScoutInfoFields> {
  bool get isFilled => match != null && team != null;
  String? match;
  int? team;

  LinkedHashMap<String, MatchInfo>? _matches;
  LinkedHashMap<int, String>? _teams;

  int? _highestQual;
  final GlobalKey<FormFieldState> _teamSelectorKey = GlobalKey();
  final TextEditingController _matchSelectorController =
      TextEditingController();

  void reset() {
    bool t = team != null;
    setState(() => match = team = null);
    _teamSelectorKey.currentState?.reset();
    setState(() => _teams = null);
    _matchSelectorController.clear();
    if (widget.onUpdate != null && t) widget.onUpdate!();
  }

  @override
  void initState() {
    BlueAlliance.stock.get((
      season: Configuration.instance.season,
      event: Configuration.event,
      match: null
    )).then((value) {
      var a = LinkedHashMap.fromEntries(value.entries
          .map((entry) => MapEntry(entry.key, parseMatchInfo(entry.key)!))
          .toList()
        ..sort((a, b) => a.value.level != b.value.level
            ? b.value.level.index - a.value.level.index
            : a.value.finalnum != null &&
                    b.value.finalnum != null &&
                    a.value.finalnum != b.value.finalnum
                ? b.value.finalnum! - a.value.finalnum!
                : b.value.index - a.value.index));
      _highestQual = (a.values
              .where((element) => element.level == MatchLevel.qualification)
              .toList()
            ..sort((a, b) => b.index - a.index))
          .firstOrNull
          ?.index;
      setState(() => _matches = a);
    }).catchError((e) {
      setState(() => _highestQual = _matches = _teams = match = team = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    });

    super.initState();
  }

  Future<void> _loadTeams() {
    if (team != null && widget.onUpdate != null) widget.onUpdate!();
    setState(() => team = null);
    _teamSelectorKey.currentState?.reset();
    setState(() => _teams = null);

    return SupabaseInterface.getSessions(match: match!)
        .then((sessions) => BlueAlliance.stock
            .get((
              season: Configuration.instance.season,
              event: Configuration.event,
              match: match!
            ))
            .then((value) => LinkedHashMap.fromEntries((value.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value)))
                .map((e) => MapEntry(int.parse(e.key),
                    "${sessions.containsKey(e.key) ? '${sessions[e.key]}|' : ''}${e.value}"))))
            .then((data) {
              int t = (sessions.entries.toList().cast<MapEntry<int, dynamic>>()
                    ..sort((a, b) => a.value - b.value))
                  .firstWhere((element) => data.containsKey(element),
                      orElse: () => data.entries.first)
                  .key;
              setState(() {
                _teams = data;
                team = t;
              });
              if (widget.onUpdate != null) widget.onUpdate!();
            }))
        .catchError((e) {
      setState(() => _teams = team = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    });
  }

  static final _robotPositionPattern =
      RegExp(r'^(?:(?<count>\d+)|)?(?<color>red|blue)(?<number>[1-3])$');
  static Chip _generateRobotPositionChip(String position) {
    RegExpMatch? patternMatch = _robotPositionPattern.firstMatch(position);
    if (patternMatch == null) throw Exception("Malformed Robot Position");
    return Chip(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
        visualDensity: VisualDensity.compact,
        backgroundColor: const {
          "red": Color(0xffed1c24),
          "blue": Color(0xff0066b3)
        }[patternMatch.namedGroup("color")]!
            .withOpacity(1 /
                (int.tryParse(patternMatch.namedGroup("count") ?? "") ?? 1)),
        label: Text(patternMatch.namedGroup("number")!));
  }

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 300, maxHeight: 72, minHeight: 72),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                    flex: 2,
                    child: TextField(
                      textAlignVertical: TextAlignVertical.top,
                      controller:
                          TextEditingController(text: Configuration.event),
                      decoration: const InputDecoration(
                          helperText: "Event",
                          counter: Icon(Icons.edit_off_rounded,
                              size: 11, color: Colors.grey)),
                      readOnly: true,
                      canRequestFocus: false,
                    )),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 4,
                    child: Stack(fit: StackFit.passthrough, children: [
                      TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _matchSelectorController
                            ..text = match ?? "",
                          decoration:
                              const InputDecoration(helperText: "Match"),
                          readOnly: _matches?.isEmpty ?? true,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.none,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          selectionControls: EmptyTextSelectionControls(),
                          validator: (value) => value == null || value.isEmpty
                              ? "Required"
                              : _matches?.containsKey(value) ?? false
                                  ? null
                                  : "Invalid",
                          onFieldSubmitted: (String value) {
                            var info = (_matches?.containsKey(value) ?? false)
                                ? parseMatchInfo(value)
                                : null;
                            if (info == null) {
                              _matchSelectorController.text = match ?? "";
                              return;
                            }
                            match = value;
                            _loadTeams();
                          }),
                      Align(
                          alignment: Alignment.topRight,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      if ((_matches?.isNotEmpty ?? false) &&
                                          match != null &&
                                          _highestQual != null) {
                                        var matchInfo = parseMatchInfo(
                                            _matchSelectorController.text);
                                        if (matchInfo == null ||
                                            matchInfo.index >= _highestQual!) {
                                          return;
                                        }
                                        _matchSelectorController.text =
                                            stringifyMatchInfo((
                                          level: MatchLevel.qualification,
                                          finalnum: null,
                                          index: matchInfo.index + 1
                                        ));
                                        match = _matchSelectorController.text;
                                        _loadTeams();
                                      }
                                    },
                                    constraints:
                                        const BoxConstraints(maxHeight: 22),
                                    iconSize: 28,
                                    icon:
                                        const Icon(Icons.arrow_drop_up_rounded),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero),
                                IconButton(
                                    onPressed: () {
                                      if ((_matches?.isNotEmpty ?? false) &&
                                          match != null &&
                                          _highestQual != null) {
                                        var matchInfo = parseMatchInfo(
                                            _matchSelectorController.text);
                                        if (matchInfo == null ||
                                            matchInfo.index <= 1) return;
                                        _matchSelectorController.text =
                                            stringifyMatchInfo((
                                          level: MatchLevel.qualification,
                                          finalnum: null,
                                          index: matchInfo.index - 1
                                        ));
                                        match = _matchSelectorController.text;
                                        _loadTeams();
                                      }
                                    },
                                    constraints:
                                        const BoxConstraints(maxHeight: 22),
                                    iconSize: 28,
                                    icon: const Icon(
                                        Icons.arrow_drop_down_rounded),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero)
                              ]))
                    ])),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 5,
                    child: DropdownButtonFormField(
                        alignment: Alignment.bottomCenter,
                        key: _teamSelectorKey,
                        value: team,
                        decoration: const InputDecoration(helperText: "Team"),
                        items: _teams == null
                            ? <DropdownMenuItem<int>>[]
                            : [
                                for (var MapEntry(key: team, value: position)
                                    in _teams!.entries)
                                  DropdownMenuItem(
                                      value: team,
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 90),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                    child:
                                                        Text(team.toString())),
                                                _generateRobotPositionChip(
                                                    position)
                                              ])))
                              ],
                        onChanged: (int? value) {
                          var t = team != value;
                          team = value;
                          if (t && match != null && widget.onUpdate != null) {
                            widget.onUpdate!();
                          }
                        }))
              ])));
}

class CounterFormField extends FormField<int> {
  CounterFormField(
      {super.key, super.onSaved, super.initialValue = 0, String? labelText})
      : super(
            builder: (FormFieldState<int> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: _getColor(labelText) ??
                    Theme.of(state.context).colorScheme.tertiaryContainer,
                child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => state.didChange(state.value! + 1),
                    child: Stack(fit: StackFit.passthrough, children: [
                      Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(flex: 1, child: SizedBox()),
                            Expanded(
                                flex: 3,
                                child: FittedBox(
                                    child: labelText != null
                                        ? Text(labelText,
                                            style: TextStyle(
                                                color: _getColor(labelText) !=
                                                        null
                                                    ? Colors.white
                                                    : Theme.of(state.context)
                                                        .colorScheme
                                                        .onTertiaryContainer))
                                        : null)),
                            Expanded(
                                flex: 5,
                                child: FittedBox(
                                    child: Text(state.value.toString()))),
                            const Expanded(flex: 1, child: SizedBox()),
                          ]),
                      FractionallySizedBox(
                          widthFactor: 0.25,
                          alignment: Alignment.bottomRight,
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                iconSize: 64,
                                icon: const Icon(Icons.remove),
                                color: Colors.white70,
                                onPressed: () => state.value! > 0
                                    ? state.didChange(state.value! - 1)
                                    : null,
                              )))
                    ]))));
  static Color? _getColor(String? labelText) {
    if (labelText == null) return null;
    return switch (Configuration.instance.season) {
      2023 => labelText.toLowerCase().startsWith("cone")
          ? const Color(0xffccc000)
          : labelText.toLowerCase().startsWith("cube")
              ? const Color(0xffa000a0)
              : null,
      _ => null
    };
  }
}

class RatingFormField extends FormField<double> {
  RatingFormField(
      {super.key, super.onSaved, super.initialValue = 3 / 5, String? labelText})
      : super(
            builder: (FormFieldState<double> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(state.context).colorScheme.secondaryContainer,
                child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 1, child: SizedBox(width: 4)),
                      Expanded(
                          flex: 3,
                          child: FittedBox(
                              child: labelText != null
                                  ? Text(labelText,
                                      style: TextStyle(
                                          color: Theme.of(state.context)
                                              .colorScheme
                                              .onSecondaryContainer))
                                  : null)),
                      Expanded(
                          flex: 5,
                          child: FittedBox(
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(
                                      5,
                                      (index) => IconButton(
                                          onPressed: () => state
                                              .didChange(index / 5 + 1 / 5),
                                          iconSize: 36,
                                          tooltip: _labels[index],
                                          icon: index + 1 <=
                                                  (state.value ?? -1) * 5
                                              ? const Icon(Icons.star_rounded,
                                                  color: Colors.yellow)
                                              : const Icon(
                                                  Icons.star_border_rounded,
                                                  color: Colors.grey)))))),
                      const Expanded(flex: 1, child: SizedBox(width: 4)),
                    ])));

  static final List<String> _labels = ["poor", "bad", "okay", "good", "pro"];
}

class ToggleFormField extends FormField<bool> {
  ToggleFormField(
      {super.key, super.onSaved, super.initialValue = false, String? labelText})
      : super(
            builder: (FormFieldState<bool> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: state.value!
                    ? Theme.of(state.context).colorScheme.secondaryContainer
                    : Colors.grey,
                child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => state.didChange(!state.value!),
                    child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(flex: 1, child: SizedBox(width: 4)),
                          Expanded(
                              flex: 3,
                              child: FittedBox(
                                  child: labelText != null
                                      ? Text(labelText,
                                          style: TextStyle(
                                              color: state.value!
                                                  ? Theme.of(state.context)
                                                      .colorScheme
                                                      .onSecondaryContainer
                                                  : Colors.white))
                                      : null)),
                          Expanded(
                              flex: 5,
                              child: FittedBox(
                                  child: Text(state.value.toString()))),
                          const Expanded(flex: 1, child: SizedBox(width: 4)),
                        ]))));
}
