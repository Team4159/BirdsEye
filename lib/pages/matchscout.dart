import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './configuration.dart';
import '../interfaces/bluealliance.dart';
import '../interfaces/localstore.dart';
import '../interfaces/supabase.dart';
import '../widgets/deleteconfirmation.dart';

typedef MatchScoutQuestionSchema
    = LinkedHashMap<String, LinkedHashMap<String, MatchScoutQuestionTypes>>;

enum MatchScoutQuestionTypes<T> {
  text<String>(sqlType: "text"),
  counter<int>(sqlType: "smallint"), // int2
  toggle<bool>(sqlType: "boolean"), // bool
  slider<double>(sqlType: "real"), // float4
  error<void>(sqlType: "any");

  final String sqlType;
  const MatchScoutQuestionTypes({required this.sqlType});
  static MatchScoutQuestionTypes fromSQLType(String s) => MatchScoutQuestionTypes.values
      .firstWhere((type) => type.sqlType == s, orElse: () => MatchScoutQuestionTypes.error);
}

Future<void> submitInfo(Map<String, dynamic> data, {int? season}) async => await SupabaseInterface
        .canConnect
    ? Supabase.instance.client.from("${season ?? Configuration.instance.season}_match").insert(data)
    : LocalStoreInterface.addMatch(season ?? Configuration.instance.season, data);

class MatchScoutPage extends StatefulWidget {
  const MatchScoutPage({super.key});

  @override
  State<MatchScoutPage> createState() => _MatchScoutPageState();
}

class _MatchScoutPageState extends State<MatchScoutPage> with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final MatchScoutInfo info = MatchScoutInfo();
  final Map<String, dynamic> _fields = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => switch (state) {
        AppLifecycleState.paused ||
        AppLifecycleState.inactive ||
        AppLifecycleState.detached ||
        AppLifecycleState.hidden =>
          SupabaseInterface.setSession(),
        AppLifecycleState.resumed =>
          SupabaseInterface.setSession(match: info.getMatchStr(), team: info.team),
      };

  @override
  void dispose() {
    SupabaseInterface.setSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
            const SliverAppBar(
                primary: true, floating: true, snap: true, title: Text("Match Scouting")),
            SliverToBoxAdapter(child: MatchScoutInfoFields(info: info))
          ],
      body: SafeArea(
          child: FutureBuilder(
              future: SupabaseInterface.matchSchema,
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
                  : ListenableBuilder(
                      listenable: info.teamController,
                      builder: (context, child) => AnimatedSlide(
                          offset: info.isFilled ? Offset.zero : const Offset(0, 1),
                          curve: Curves.easeInOutCirc,
                          duration: const Duration(seconds: 1),
                          child: child),
                      child: Form(
                          key: _formKey,
                          child: CustomScrollView(cacheExtent: double.infinity, slivers: [
                            for (var MapEntry(key: section, value: contents)
                                in snapshot.data!.entries) ...[
                              SliverAppBar(
                                  primary: false,
                                  excludeHeaderSemantics: true,
                                  automaticallyImplyLeading: false,
                                  centerTitle: true,
                                  stretch: false,
                                  title: Text(section,
                                      style: Theme.of(context).textTheme.headlineLarge,
                                      textScaleFactor: 1.5)),
                              SliverPadding(
                                  padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                                  sliver: SliverGrid.count(
                                      crossAxisCount: 2,
                                      childAspectRatio:
                                          MediaQuery.of(context).size.width > 450 ? 3 : 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 12,
                                      children: [
                                        for (var MapEntry(key: field, value: type)
                                            in contents.entries)
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
                                                            s[0].toUpperCase() + s.substring(1))
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
                                                    enabledBorder: OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                Theme.of(context).colorScheme.secondaryContainer,
                                                            width: 3)),
                                                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer, width: 2))),
                                                onSaved: (i) => _fields["${section}_$field"] = i),
                                            MatchScoutQuestionTypes.counter => CounterFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) => s[0].toUpperCase() + s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields["${section}_$field"] = i),
                                            MatchScoutQuestionTypes.slider => RatingFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) => s[0].toUpperCase() + s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields["${section}_$field"] = i),
                                            MatchScoutQuestionTypes.toggle => ToggleFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) => s[0].toUpperCase() + s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields["${section}_$field"] = i),
                                            MatchScoutQuestionTypes.error => Material(
                                                type: MaterialType.button,
                                                borderRadius: BorderRadius.circular(4),
                                                color: Theme.of(context).colorScheme.errorContainer,
                                                child: Center(child: Text(field)))
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
                                              ..._fields,
                                              "event": Configuration.event,
                                              "match": info.getMatchStr(),
                                              "team": info.team
                                            }).then((_) async {
                                              _formKey.currentState!.reset();
                                              await _scrollController.animateTo(0,
                                                  duration: const Duration(seconds: 1),
                                                  curve: Curves.easeOutBack);
                                              info.resetInfo();
                                            }).catchError((e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())));
                                            });
                                          })),
                                  const SizedBox(width: 10),
                                  DeleteConfirmation(
                                      context: context,
                                      reset: () async {
                                        _formKey.currentState!.reset();
                                        await _scrollController.animateTo(0,
                                            duration: const Duration(milliseconds: 1500),
                                            curve: Curves.easeOutBack);
                                        info.resetInfo();
                                      })
                                ])))
                          ]))))));
}

class MatchScoutInfo {
  MatchScoutInfo()
      : matchController = TextEditingController(),
        teamController = ValueNotifier(null) {
    BlueAlliance.stock
        .get((season: Configuration.instance.season, event: Configuration.event, match: null)).then(
            (matchesdata) => matches = LinkedHashMap.fromEntries(
                matchesdata.keys.map((k) => MapEntry(k, parseMatchInfo(k)!)).toList()
                  ..sort((a, b) => compareMatchInfo(a.value, b.value))));
  }

  int highestQual = -1;
  LinkedHashMap<String, MatchInfo>? _matches;
  LinkedHashMap<String, MatchInfo>? get matches => _matches;
  set matches(LinkedHashMap<String, MatchInfo>? m) {
    _matches = m;
    match = null;
    highestQual = m == null
        ? -1
        : (m.values.where((element) => element.level == MatchLevel.qualification).toList()
                  ..sort((a, b) => b.index - a.index))
                .firstOrNull
                ?.index ??
            -1;
  }

  final TextEditingController matchController;
  MatchInfo? _match;
  MatchInfo? get match => _match;
  set match(MatchInfo? m) {
    if (m == null) {
      matchController.text = "";
      return _match = teams = null;
    }
    if (matches == null) return;
    if (m == match || !matches!.containsValue(m)) return;
    String mstr = stringifyMatchInfo(m);
    matchController.text = mstr;
    _match = m;
    teams = null;
    Future<Map<String, String>> tbaDataFuture = m.level == MatchLevel.qualification ||
            !BlueAlliance.dirtyConnected
        ? BlueAlliance.stock
            .get((season: Configuration.instance.season, event: Configuration.event, match: mstr))
        : BlueAlliance.stock.fresh((
            season: Configuration.instance.season,
            event: Configuration.event,
            match: mstr
          )); // keep fetching latest info for finals
    SupabaseInterface.canConnect
        .then((conn) => conn ? SupabaseInterface.getSessions(match: mstr) : Future.value({}))
        .then((sessions) => tbaDataFuture
                .then((td) => td.length < 6 ? throw Exception("Incorrect Team Count!") : td)
                // WARNING untested: filter unfilled (finals) matches out
                .then((teamsData) => LinkedHashMap.fromEntries((teamsData.entries.toList()
                      ..sort((a, b) => a.value.compareTo(b.value)))
                    .map((e) => MapEntry(e.key, e.value))
                    .map((e) => MapEntry(e.key,
                        "${sessions.containsKey(e.key) ? '${sessions[e.key]}|' : ''}${e.value}"))))
                .then((data) {
              teams = data;
              team = (data.keys.toList()..sort((a, b) => (sessions[a] ?? 0) - (sessions[b] ?? 0)))
                  .first;
            }))
        .catchError((e) => teams = null);
  }

  String? getMatchStr() => match == null ? null : stringifyMatchInfo(match!);
  void setMatchStr(String? m) => match = parseMatchInfo(m); // invoke the other setter

  LinkedHashMap<String, String>? _teams;
  LinkedHashMap<String, String>? get teams => _teams;
  set teams(LinkedHashMap<String, String>? t) {
    _teams = t;
    team = null;
  }

  ValueNotifier<String?> teamController;
  String? get team => teamController.value;
  set team(String? t) {
    if (t == null) return teamController.value = null;
    if (teams == null) return;
    if (t == team || !teams!.containsKey(t)) return;
    teamController.value = t;
    if (team != null) SupabaseInterface.setSession(match: getMatchStr(), team: team);
  }

  void resetInfo() => match = null;

  bool get isFilled => team != null;
}

class MatchScoutInfoFields extends StatelessWidget {
  const MatchScoutInfoFields({super.key, required this.info});
  final MatchScoutInfo info;

  static final _robotPositionPattern =
      RegExp(r'^(?:(?<count>\d+)\|)?(?<color>red|blue)(?<number>[1-3])$');
  static Widget _generateRobotPositionChip(String position) {
    RegExpMatch? patternMatch = _robotPositionPattern.firstMatch(position);
    if (patternMatch == null) throw Exception("Malformed Robot Position '$position'");
    return Container(
        decoration: BoxDecoration(
            color: const {
              "red": Color(0xffed1c24),
              "blue": Color(0xff0066b3)
            }[patternMatch.namedGroup("color")]!
                .withOpacity(1 / ((int.tryParse(patternMatch.namedGroup("count") ?? "") ?? 0) + 1)),
            border: Border.all(width: 1, color: Colors.grey[800]!),
            borderRadius: BorderRadius.circular(8)),
        width: 20,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.topCenter,
        child: Center(child: Text(patternMatch.namedGroup("number")!)));
  }

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 72, minHeight: 72),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                    flex: 2,
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      controller: TextEditingController(text: Configuration.event),
                      decoration: const InputDecoration(
                          helperText: "Event",
                          counter: Icon(Icons.edit_off_rounded, size: 11, color: Colors.grey)),
                      readOnly: true,
                      canRequestFocus: false,
                    )),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 4,
                    child: Stack(fit: StackFit.passthrough, children: [
                      TextFormField(
                          textAlignVertical: TextAlignVertical.center,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: info.matchController,
                          decoration: const InputDecoration(helperText: "Match"),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.none,
                          enableInteractiveSelection: false,
                          selectionControls: EmptyTextSelectionControls(),
                          validator: (value) => value?.isEmpty ?? true
                              ? "Required"
                              : info.matches?.containsKey(value) ?? false
                                  ? null
                                  : "Invalid",
                          onFieldSubmitted: info.setMatchStr),
                      Align(
                          alignment: Alignment.topRight,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      if (info.highestQual < 1) return;
                                      info.match = (
                                        level: MatchLevel.qualification,
                                        finalnum: null,
                                        index: (info.match == null ? 1 : info.match!.index + 1)
                                            .clamp(1, info.highestQual)
                                      );
                                    },
                                    constraints: const BoxConstraints(maxHeight: 22),
                                    iconSize: 28,
                                    icon: const Icon(Icons.arrow_drop_up_rounded),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero),
                                IconButton(
                                    onPressed: () {
                                      if (info.highestQual < 1) return;
                                      info.match = (
                                        level: MatchLevel.qualification,
                                        finalnum: null,
                                        index: (info.match == null
                                                ? info.highestQual
                                                : info.match!.index - 1)
                                            .clamp(1, info.highestQual)
                                      );
                                    },
                                    constraints: const BoxConstraints(maxHeight: 22),
                                    iconSize: 28,
                                    icon: const Icon(Icons.arrow_drop_down_rounded),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero)
                              ]))
                    ])),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 5,
                    child: ListenableBuilder(
                        listenable: info.teamController,
                        builder: (context, _) => DropdownButtonFormField(
                            alignment: Alignment.bottomCenter,
                            decoration: const InputDecoration(helperText: "Team"),
                            focusColor: Colors.transparent,
                            isExpanded: false,
                            value: info.team,
                            items: info.teams == null
                                ? <DropdownMenuItem<String>>[]
                                : [
                                    for (var MapEntry(key: team, value: position)
                                        in info.teams!.entries)
                                      DropdownMenuItem(
                                          value: team,
                                          alignment: Alignment.center,
                                          child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 77),
                                              child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                                  textBaseline: TextBaseline.alphabetic,
                                                  children: [
                                                    const SizedBox(width: 5),
                                                    Expanded(child: Text(team.toString())),
                                                    _generateRobotPositionChip(position)
                                                  ])))
                                  ],
                            onChanged: (String? value) => info.team = value)))
              ])));
}

class CounterFormField extends FormField<int> {
  CounterFormField({super.key, super.onSaved, super.initialValue = 0, String? labelText})
      : super(
            builder: (FormFieldState<int> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color:
                    _getColor(labelText) ?? Theme.of(state.context).colorScheme.tertiaryContainer,
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
                                                color: _getColor(labelText) != null
                                                    ? Colors.white
                                                    : Theme.of(state.context)
                                                        .colorScheme
                                                        .onTertiaryContainer))
                                        : null)),
                            Expanded(
                                flex: 5, child: FittedBox(child: Text(state.value.toString()))),
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
                                onPressed: () =>
                                    state.value! > 0 ? state.didChange(state.value! - 1) : null,
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
  RatingFormField({super.key, super.onSaved, super.initialValue = 3 / 5, String? labelText})
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
                                          onPressed: () => state.didChange(index / 5 + 1 / 5),
                                          iconSize: 36,
                                          tooltip: _labels[index],
                                          icon: index + 1 <= (state.value ?? -1) * 5
                                              ? const Icon(Icons.star_rounded, color: Colors.yellow)
                                              : const Icon(Icons.star_border_rounded,
                                                  color: Colors.grey)))))),
                      const Expanded(flex: 1, child: SizedBox(width: 4)),
                    ])));

  static final List<String> _labels = ["poor", "bad", "okay", "good", "pro"];
}

class ToggleFormField extends FormField<bool> {
  ToggleFormField({super.key, super.onSaved, super.initialValue = false, String? labelText})
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
                          Expanded(flex: 5, child: FittedBox(child: Text(state.value.toString()))),
                          const Expanded(flex: 1, child: SizedBox(width: 4)),
                        ]))));
}
