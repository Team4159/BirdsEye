import 'dart:collection';

import 'package:flutter/material.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/supabase.dart';
import 'configuration.dart';

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

Chip generateRobotPositionChip(String position) {
  RegExpMatch? patternMatch = robotPositionPattern.firstMatch(position);
  if (patternMatch == null) throw Exception("Malformed Robot Position");
  return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
      visualDensity: VisualDensity.compact,
      backgroundColor: const {
        "red": Color(0xffed1c24),
        "blue": Color(0xff0066b3)
      }[patternMatch.namedGroup("color")],
      label: Text(patternMatch.namedGroup("number")!));
}

class MatchScoutPage extends StatefulWidget {
  const MatchScoutPage({super.key});

  @override
  State<MatchScoutPage> createState() => _MatchScoutPageState();
}

class _MatchScoutPageState extends State<MatchScoutPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final GlobalKey<_MatchScoutInfoFieldsState> _infoKey = GlobalKey();

  @override
  Widget build(BuildContext context) => NestedScrollView(
      headerSliverBuilder: (context, _) => [
            const SliverAppBar(
                primary: true,
                floating: true,
                snap: true,
                title: Text("Match Scouting")),
            SliverToBoxAdapter(
                child: _MatchScoutInfoFields(
                    key: _infoKey, onUpdate: () => setState(() {})))
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
                                  padding: const EdgeInsets.only(bottom: 12),
                                  sliver: SliverGrid.count(
                                      crossAxisCount: 2,
                                      childAspectRatio: 3 / 1,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 12,
                                      children: [
                                        for (var MapEntry(
                                              key: field,
                                              value: type
                                            ) in contents.entries)
                                          switch (type) {
                                            MatchScoutQuestionTypes.text =>
                                              TextFormField(
                                                  maxLines: null,
                                                  expands: true,
                                                  decoration: InputDecoration(
                                                      labelText: field,
                                                      border:
                                                          const OutlineInputBorder())),
                                            MatchScoutQuestionTypes.counter =>
                                              CounterFormField(
                                                  labelText: field),
                                            MatchScoutQuestionTypes.slider =>
                                              RatingFormField(labelText: field),
                                            MatchScoutQuestionTypes.toggle =>
                                              ToggleFormField(labelText: field),
                                            MatchScoutQuestionTypes.error =>
                                              Material(
                                                  type: MaterialType.button,
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
                                    child: FilledButton(
                                        child: const Text("Submit"),
                                        onPressed: () {
                                          // TODO add submitting
                                        })))
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
  LinkedHashMap<String, String>? _teams;

  final GlobalKey<FormFieldState> _teamSelectorKey = GlobalKey();

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
      setState(() => _matches = a);
    }).catchError((e) {
      setState(() => _matches = _teams = match = team = null);
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
    return (match != null
            ? BlueAlliance.stock.get((
                season: Configuration.instance.season,
                event: Configuration.event,
                match: match
              )).then((value) => setState(() => _teams =
                LinkedHashMap.fromEntries(value.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value)))))
            : Future.error("No Match Code!"))
        .catchError((e) {
      setState(() => _teams = team = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    });
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
                    child: _MatchField(_matches,
                        highestQual: (_matches?.values
                                .where((element) =>
                                    element.level == MatchLevel.qualification)
                                .toList()
                              ?..sort((a, b) => b.index - a.index))
                            ?.firstOrNull
                            ?.index,
                        controller: TextEditingController(),
                        onSubmitted: (String? value) {
                      match = value;
                      _loadTeams();
                    })),
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
                                      value: int.parse(team),
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 90),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(child: Text(team)),
                                                generateRobotPositionChip(
                                                    position)
                                              ])))
                              ],
                        onChanged: (int? value) {
                          var t = team == null;
                          team = value;
                          if (t && match != null && widget.onUpdate != null) {
                            widget.onUpdate!();
                          }
                        }))
              ])));
}

class _MatchField extends FormField<MatchInfo> {
  // FIXME this should not require a controller (try fixing by using GlobalKey<FormFieldState>)
  final LinkedHashMap<String, MatchInfo>? validMatches;

  _MatchField(this.validMatches,
      {int? highestQual,
      Function(String?)? onSubmitted,
      required TextEditingController controller})
      : super(
            builder: (state) => Stack(fit: StackFit.passthrough, children: [
                  TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: controller
                        ..text = state.value == null
                            ? ""
                            : stringifyMatchInfo(state.value!),
                      decoration: const InputDecoration(helperText: "Match"),
                      readOnly: validMatches == null || validMatches.isEmpty,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      selectionControls: EmptyTextSelectionControls(),
                      validator: (value) => value == null || value.isEmpty
                          ? "Required"
                          : validMatches?.containsKey(value) ?? false
                              ? null
                              : "Invalid",
                      onFieldSubmitted: (String value) {
                        var info = (validMatches?.containsKey(value) ?? false)
                            ? parseMatchInfo(value)
                            : null;
                        if (info == null) {
                          controller.text = state.value == null
                              ? ""
                              : stringifyMatchInfo(state.value!);
                          return;
                        }
                        state.didChange(info);
                        if (onSubmitted != null) onSubmitted(value);
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
                                  if (validMatches != null &&
                                      validMatches.isNotEmpty &&
                                      state.value != null &&
                                      highestQual != null &&
                                      state.value!.index < highestQual) {
                                    state.didChange((
                                      level: MatchLevel.qualification,
                                      finalnum: null,
                                      index: state.value!.index + 1
                                    ));
                                    if (onSubmitted != null) {
                                      onSubmitted(
                                          stringifyMatchInfo(state.value!));
                                    }
                                  }
                                },
                                constraints:
                                    const BoxConstraints(maxHeight: 22),
                                iconSize: 28,
                                icon: const Icon(Icons.arrow_drop_up_rounded),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero),
                            IconButton(
                                onPressed: () {
                                  if (validMatches != null &&
                                      validMatches.isNotEmpty &&
                                      state.value != null &&
                                      highestQual != null &&
                                      state.value!.index > 1) {
                                    state.didChange((
                                      level: MatchLevel.qualification,
                                      finalnum: null,
                                      index: state.value!.index - 1
                                    ));
                                    if (onSubmitted != null) {
                                      onSubmitted(
                                          stringifyMatchInfo(state.value!));
                                    }
                                  }
                                },
                                constraints:
                                    const BoxConstraints(maxHeight: 22),
                                iconSize: 28,
                                icon: const Icon(Icons.arrow_drop_down_rounded),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero)
                          ]))
                ]));
}

class CounterFormField extends FormField<int> {
  CounterFormField(
      {super.key, super.onSaved, super.initialValue = 0, String? labelText})
      : super(
            builder: (FormFieldState<int> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(state.context).colorScheme.primaryContainer,
                child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => state.didChange(state.value! + 1),
                    child: Flex(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      direction: Axis.vertical,
                      children: [
                        const Flexible(flex: 1, child: SizedBox(width: 4)),
                        Flexible(
                            flex: 1,
                            child: FittedBox(
                                child: labelText != null
                                    ? Text(labelText)
                                    : null)),
                        Flexible(
                            flex: 2,
                            child:
                                FittedBox(child: Text(state.value.toString()))),
                        Flexible(
                            flex: 1,
                            child: FittedBox(
                                fit: BoxFit.fitHeight,
                                alignment: Alignment.bottomRight,
                                child: IconButton(
                                  iconSize: 96,
                                  icon: const Icon(Icons.remove),
                                  color: Colors.white70,
                                  visualDensity: VisualDensity.comfortable,
                                  padding: const EdgeInsets.only(right: 16),
                                  alignment: Alignment.center,
                                  onPressed: () => state.value! > 0
                                      ? state.didChange(state.value! - 1)
                                      : null,
                                )))
                      ],
                    ))));
  static Color? getColor(BuildContext context, String? labelText) {
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
  RatingFormField({super.key, String? labelText})
      : super(builder: (state) => const Placeholder());
}

class ToggleFormField extends FormField<bool> {
  ToggleFormField({super.key, String? labelText})
      : super(builder: (state) => const Placeholder());
}
