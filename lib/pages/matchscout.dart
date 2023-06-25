import 'dart:collection';

import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/pages/configuration.dart';
import 'package:flutter/material.dart';

typedef MatchScoutQuestionSchema
    = Map<String, Map<String, MatchScoutQuestionTypes>>;

enum MatchScoutQuestionTypes<T> {
  text<String>(sqlType: "text"),
  counter<int>(sqlType: "int2"),
  toggle<bool>(sqlType: "bool"),
  slider<double>(sqlType: "float4");

  final String sqlType;
  const MatchScoutQuestionTypes({required this.sqlType});
  static fromSQLType(String s) =>
      MatchScoutQuestionTypes.values.firstWhere((type) => type.sqlType == s);
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
      label: Text(patternMatch.namedGroup("number") ?? "0"));
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
                primary: true, floating: true, title: Text("Match Scouting")),
            SliverToBoxAdapter(child: _MatchScoutInfoFields(key: _infoKey))
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
              : Form(
                  key: _formKey,
                  child:
                      CustomScrollView(cacheExtent: double.infinity, slivers: [
                    for (var MapEntry(key: section, value: contents)
                        in snapshot.data!.entries) ...[
                      SliverAppBar(
                          primary: false,
                          automaticallyImplyLeading: false,
                          title: Text(section)),
                      SliverGrid.count(
                          crossAxisCount: 2,
                          childAspectRatio: 3 / 1,
                          children: [
                            for (var MapEntry(key: field, value: type)
                                in contents.entries)
                              switch (type) {
                                MatchScoutQuestionTypes.text => TextFormField(
                                    maxLines: null,
                                    expands: true,
                                    decoration: InputDecoration(
                                        labelText: field,
                                        border: const OutlineInputBorder())),
                                MatchScoutQuestionTypes.counter =>
                                  CounterFormField(labelText: field),
                                MatchScoutQuestionTypes.slider =>
                                  RatingFormField(labelText: field),
                                MatchScoutQuestionTypes.toggle =>
                                  ToggleFormField(labelText: field),
                              }
                          ])
                    ]
                  ]))));
}

class _MatchScoutInfoFields extends StatefulWidget {
  const _MatchScoutInfoFields({super.key});

  @override
  State<StatefulWidget> createState() => _MatchScoutInfoFieldsState();
}

class _MatchScoutInfoFieldsState extends State<_MatchScoutInfoFields> {
  String? match;
  int? team;

  LinkedHashMap<String, MatchInfo>? _matches;
  LinkedHashMap<String, String>? _teams;

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
    setState(() => _teams = team = null);
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
      child: FractionallySizedBox(
          widthFactor: 0.25,
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment
                  .baseline, // FIXME nothing aligns correctly :(
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                    flex: 2,
                    child: TextField(
                      controller:
                          TextEditingController(text: Configuration.event),
                      decoration: const InputDecoration(helperText: "Event"),
                      readOnly: true,
                    )),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 2,
                    child: _MatchField(_matches,
                        highestQual: (_matches?.values
                                .where((element) =>
                                    element.level == MatchLevel.qualification)
                                .toList()
                              ?..sort((a, b) => b.index - a.index))
                            ?.first
                            .index,
                        controller: TextEditingController(),
                        onSubmitted: (String? value) {
                      match = value;
                      _loadTeams();
                    })),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 4,
                    child: DropdownButtonFormField(
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
                                              maxWidth: 110, minWidth: 100),
                                          child: ListTile(
                                              minVerticalPadding: 4,
                                              title: Text(team),
                                              trailing:
                                                  generateRobotPositionChip(
                                                      position))))
                              ],
                        onChanged: (int? value) => team = value))
              ])));
}

class _MatchField extends FormField<MatchInfo> {
  // FIXME how does one fix a janky FormField extend (try fixing by using GlobalKey<FormFieldState>)
  final LinkedHashMap<String, MatchInfo>? validMatches;

  _MatchField(this.validMatches,
      {int? highestQual,
      Function(String?)? onSubmitted,
      required TextEditingController controller})
      : super(
            initialValue: validMatches?.values.first,
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
                      enableInteractiveSelection: false,
                      selectionControls: EmptyTextSelectionControls(),
                      validator: (value) => value == null || value.isEmpty
                          ? "Required"
                          : validMatches?.containsKey(value) ?? false
                              ? null
                              : "Invalid",
                      onFieldSubmitted: (String value) {
                        var info = parseMatchInfo(value);
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
                        // FIXME buttons don't show up in the right place
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              onPressed: () {
                                if ((validMatches != null &&
                                        validMatches.isNotEmpty &&
                                        state.value != null) &&
                                    (highestQual == null ||
                                        state.value!.index < highestQual)) {
                                  state.didChange((
                                    level: MatchLevel.qualification,
                                    finalnum: null,
                                    index: state.value!.index + 1
                                  ));
                                  if (onSubmitted != null)
                                    // ignore: curly_braces_in_flow_control_structures
                                    onSubmitted(
                                        stringifyMatchInfo(state.value!));
                                }
                              },
                              icon: const Icon(Icons.arrow_drop_up_rounded),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero),
                          IconButton(
                              onPressed: () {
                                if (validMatches != null &&
                                    validMatches.isNotEmpty &&
                                    state.value != null &&
                                    state.value!.index > 1) {
                                  state.didChange((
                                    level: MatchLevel.qualification,
                                    finalnum: null,
                                    index: state.value!.index - 1
                                  ));
                                  if (onSubmitted != null)
                                    // ignore: curly_braces_in_flow_control_structures
                                    onSubmitted(
                                        stringifyMatchInfo(state.value!));
                                }
                              },
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero)
                        ],
                      ))
                ]));
}

class CounterFormField extends FormField<int> {
  CounterFormField({super.key, String? labelText})
      : super(builder: (state) => const Placeholder());
}

class RatingFormField extends FormField<double> {
  RatingFormField({super.key, String? labelText})
      : super(builder: (state) => const Placeholder());
}

class ToggleFormField extends FormField<bool> {
  ToggleFormField({super.key, String? labelText})
      : super(builder: (state) => const Placeholder());
}
