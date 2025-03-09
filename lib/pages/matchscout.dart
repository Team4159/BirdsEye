import 'dart:async';
import 'dart:collection';

import 'package:birdseye/pages/configuration.dart';
import 'package:flutter/material.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/mixed.dart';
import '../interfaces/supabase.dart';
import '../types.dart';
import '../utils.dart';

class MatchScoutPage extends StatefulWidget {
  final String? matchCode;
  const MatchScoutPage({super.key, this.matchCode});

  @override
  State<MatchScoutPage> createState() => _MatchScoutPageState();
}

class _MatchScoutPageState extends State<MatchScoutPage> with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey();
  late MatchScoutInfoImmutable info;
  late final Future<MatchScoutInfo> infoConverter;
  final Map<String, dynamic> _fields = {};
  final ScrollController _scrollController = ScrollController();

  final _matchCodeParamPattern =
      RegExp(r"^(?<season>\d{4})(?<event>[A-z\d]+)_(?<match>.+?)_(?<team>\d{1,5}[A-Z]?)$");
  MatchScoutInfoSerialized? _parseQuery() {
    if (widget.matchCode == null) return null;
    var match = _matchCodeParamPattern.firstMatch(widget.matchCode!);
    if (match == null) return null;
    try {
      return (
        season: int.parse(match.namedGroup("season")!),
        event: match.namedGroup("event")!,
        match: match.namedGroup("match")!,
        team: match.namedGroup("team")!
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    var pq = _parseQuery();
    info = pq == null
        ? MatchScoutInfo(Configuration.instance.season, Configuration.event!)
        : MatchScoutInfoImmutable.fill(pq);
    infoConverter = MatchScoutInfo.promote(info).then((i) => info = i);
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
            FutureBuilder(
                future: infoConverter,
                builder: (context, snapshot) =>
                    SliverToBoxAdapter(child: MatchScoutInfoFields(info: snapshot.data)))
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
                      listenable: info.teamNotifier,
                      builder: (context, child) => AnimatedSlide(
                          offset: info.isFilled ? Offset.zero : const Offset(0, 1),
                          curve: Curves.easeInOutCirc,
                          duration: const Duration(seconds: 1),
                          child: child),
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
                                      stretch: false,
                                      title: Text(section,
                                          style: Theme.of(context).textTheme.headlineLarge,
                                          textScaler: const TextScaler.linear(1.5))),
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
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .secondaryContainer,
                                                                width: 3)),
                                                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer, width: 2))),
                                                    onSaved: (i) => _fields["${section}_$field"] = i),
                                                MatchScoutQuestionTypes.counter => CounterFormField(
                                                    labelText: field
                                                        .split("_")
                                                        .map((s) =>
                                                            s[0].toUpperCase() + s.substring(1))
                                                        .join(" "),
                                                    onSaved: (i) =>
                                                        _fields["${section}_$field"] = i,
                                                    season: info.season),
                                                MatchScoutQuestionTypes.slider => RatingFormField(
                                                    labelText: field
                                                        .split("_")
                                                        .map((s) =>
                                                            s[0].toUpperCase() + s.substring(1))
                                                        .join(" "),
                                                    onSaved: (i) =>
                                                        _fields["${section}_$field"] = i),
                                                MatchScoutQuestionTypes.toggle => ToggleFormField(
                                                    labelText: field
                                                        .split("_")
                                                        .map((s) =>
                                                            s[0].toUpperCase() + s.substring(1))
                                                        .join(" "),
                                                    onSaved: (i) =>
                                                        _fields["${section}_$field"] = i),
                                                MatchScoutQuestionTypes.error => Material(
                                                    type: MaterialType.button,
                                                    borderRadius: BorderRadius.circular(4),
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .errorContainer,
                                                    child: Center(child: Text(field)))
                                              }
                                          ]))
                                ],
                                SliverPadding(
                                    padding: const EdgeInsets.all(20),
                                    sliver: SliverToBoxAdapter(
                                        child: Row(children: [
                                      Expanded(
                                          child: FutureBuilder(
                                              future: infoConverter,
                                              builder: (context, snapshot) => FilledButton(
                                                  onPressed: !snapshot.hasData
                                                      ? null
                                                      : () async {
                                                          _fields.clear();
                                                          _formKey.currentState!.save();
                                                          MatchInfo currmatch = info.match!;
                                                          await MixedInterfaces.submitMatchResponse(
                                                                  (
                                                                season: info.season,
                                                                event: info.event,
                                                                match: currmatch.toString(),
                                                                team: info.team!
                                                              ),
                                                                  _fields)
                                                              .reportError(context);
                                                          _formKey.currentState!.reset();
                                                          snapshot.data!.progressOrReset();
                                                          await _scrollController.animateTo(0,
                                                              duration: const Duration(seconds: 1),
                                                              curve: Curves.easeOutBack);
                                                        },
                                                  child: const Text("Submit")))),
                                      const SizedBox(width: 10),
                                      FutureBuilder(
                                          future: infoConverter,
                                          builder: (context, snapshot) => DeleteConfirmation(
                                              context: context,
                                              reset: !snapshot.hasData
                                                  ? null
                                                  : () async {
                                                      _formKey.currentState!.reset();
                                                      await _scrollController.animateTo(0,
                                                          duration:
                                                              const Duration(milliseconds: 1500),
                                                          curve: Curves.easeOutBack);
                                                      snapshot.data!.resetInfo();
                                                    }))
                                    ])))
                              ]
                                  .map((s) => SliverConstrainedCrossAxis(maxExtent: 500, sliver: s))
                                  .toList()))))));
}

typedef MatchRobotPositionInfo = ({bool isRedAlliance, int ordinal, int currentScouters});

class RobotPositionChip extends Container {
  RobotPositionChip(MatchRobotPositionInfo position, {super.key})
      : super(
            decoration: BoxDecoration(
                color: (position.isRedAlliance ? frcred : frcblue)
                    .withAlpha((255 / (position.currentScouters + 1)).truncate()),
                border: Border.all(width: 1, color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(8)),
            width: 20,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.topCenter,
            child: Center(child: Text(position.ordinal.toString())));

  static final _robotPositionPattern = RegExp(r'^(?<color>red|blue)(?<number>[1-3])$');
  static MatchRobotPositionInfo robotPositionFromString(String posStr, {int scouters = 0}) {
    RegExpMatch? patternMatch = _robotPositionPattern.firstMatch(posStr);
    assert(patternMatch != null, "Malformed Robot Position '$posStr'");
    return (
      isRedAlliance: patternMatch?.namedGroup("color") == "red",
      ordinal: patternMatch == null ? 0 : int.parse(patternMatch.namedGroup("number")!),
      currentScouters: scouters
    );
  }
}

class MatchScoutInfoImmutable {
  final int season;
  final String event;

  /// Creates an utterly useless instance. Only for subclasses to invoke.
  MatchScoutInfoImmutable(this.season, this.event) : teamNotifier = NotifiableValueNotifier(null);

  MatchScoutInfoImmutable.fill(MatchScoutInfoSerialized info)
      : season = info.season,
        event = info.event,
        _match = MatchInfo.fromString(info.match),
        teamNotifier = NotifiableValueNotifier(info.team);

  LinkedHashMap<String, MatchInfo>? _matches;
  LinkedHashMap<String, MatchInfo>? get matches => _matches;

  MatchInfo? _match;
  MatchInfo? get match => _match;
  String? getMatchStr() => match?.toString();

  LinkedHashMap<String, MatchRobotPositionInfo>? _teams;
  LinkedHashMap<String, MatchRobotPositionInfo>? get teams => _teams;

  NotifiableValueNotifier<String?> teamNotifier;
  String? get team => teamNotifier.value;

  bool get isFilled => team != null;
}

class MatchScoutInfo extends MatchScoutInfoImmutable {
  MatchScoutInfo(super.season, super.event) : matchController = NotifiableTextEditingController() {
    fetchMatches().then((m) => matches = m);
  }

  /// Validates a [MatchScoutInfoImmutable], promoting it to a [MatchScoutInfo].
  static Future<MatchScoutInfo> promote(MatchScoutInfoImmutable immutable) async {
    if (immutable is MatchScoutInfo) return immutable;
    var info = MatchScoutInfo(immutable.season, immutable.event);
    await info.matchController.nextChange;
    if (!info._matches!.containsKey(immutable.match.toString())) return info;
    info.match = immutable.match!;
    await info.teamNotifier.nextChange;
    info.team = immutable.team;
    return info;
  }

  Future<LinkedHashMap<String, MatchInfo>> fetchMatches() => BlueAlliance.stock
      .get(TBAInfo(season: season, event: event))
      .then((matchesdata) => LinkedHashMap.fromEntries(
          matchesdata.keys.map((k) => MapEntry(k, MatchInfo.fromString(k))).toList()
            ..sort((a, b) => a.value.compareTo(b.value))));

  int highestQual = -1;
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

  final NotifiableTextEditingController matchController;
  set match(MatchInfo? m) {
    if (m == null) {
      if (matchController.text == "") matchController.notifyListeners();
      matchController.text = "";
      return _match = teams = null;
    }
    if (matches == null) return;
    if (m == match) return;
    if (!matches!.containsValue(m)) {
      return _match = teams = null;
    }
    _match = m;
    matchController.text = m.toString();
    teams = null;
    fetchTeams().then((t) => teams = t);
  }

  void setMatchStr(String? m) =>
      match = m == null ? null : MatchInfo.fromString(m); // invoke the other setter

  Future<LinkedHashMap<String, MatchRobotPositionInfo>?> fetchTeams() {
    String mstr = _match!.toString();
    Future<Map<String, String>> tbaDataFuture =
        _match!.level != MatchLevel.qualification && BlueAlliance.dirtyConnected
            ? BlueAlliance.stock.fresh(TBAInfo(season: season, event: event, match: mstr))
            : BlueAlliance.stock.get(TBAInfo(
                season: season, event: event, match: mstr)); // keep fetching latest info for finals
    return SupabaseInterface.canConnect
        .then((conn) =>
            conn ? SupabaseInterface.getSessions(match: mstr) : Future.value(<String, int>{}))
        .then<LinkedHashMap<String, MatchRobotPositionInfo>?>((sessions) => tbaDataFuture.then(
            (teamsData) => LinkedHashMap.fromEntries((teamsData.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value)))
                .map((e) => MapEntry(
                    e.key,
                    RobotPositionChip.robotPositionFromString(e.value,
                        scouters: sessions.containsKey(e.key) ? sessions[e.key]! : 0))))))
        .catchError((e) => null);
  }

  set teams(LinkedHashMap<String, MatchRobotPositionInfo>? t) {
    _teams = t;
    team = null; // Will push updates in the team function
  }

  set team(String? t) {
    if (t == null) {
      SupabaseInterface.setSession(match: getMatchStr(), team: null);
      if (teamNotifier.value == null) {
        teamNotifier.notifyListeners(); // notify even if the value isnt changing
      }
      return teamNotifier.value = null;
    }
    if (teams == null) return;
    if (t == team || !teams!.containsKey(t)) return;
    teamNotifier.value = t;
    SupabaseInterface.setSession(match: getMatchStr(), team: team);
  }

  void resetInfo() => match = null;

  void progressOrReset() {
    if (match == null || match!.level != MatchLevel.qualification || match!.index >= highestQual) {
      return resetInfo();
    }
    team = null;
    match = MatchInfo(level: MatchLevel.qualification, index: match!.index + 1);
  }
}

class MatchScoutInfoFields extends StatelessWidget {
  const MatchScoutInfoFields({super.key, required this.info});
  final MatchScoutInfo? info;

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
                      controller: TextEditingController(text: info?.event),
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
                          controller: info?.matchController,
                          decoration: const InputDecoration(helperText: "Match"),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.none,
                          enableInteractiveSelection: false,
                          autocorrect: false,
                          selectionControls: EmptyTextSelectionControls(),
                          enabled: info != null,
                          validator: (value) => value?.isEmpty ?? true
                              ? "Required"
                              : info!.matches?.containsKey(value) ?? false
                                  ? null
                                  : "Invalid", // TODO fails at varifying non-qual matches because cache doesn't refresh
                          onChanged: info?.setMatchStr),
                      Align(
                          alignment: Alignment.topRight,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    onPressed: info == null
                                        ? null
                                        : () {
                                            if (info!.highestQual < 1) return;
                                            info!.match = MatchInfo(
                                                level: MatchLevel.qualification,
                                                index: (info!.match == null
                                                        ? 1
                                                        : info!.match!.index + 1)
                                                    .clamp(1, info!.highestQual));
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
                                    onPressed: info == null
                                        ? null
                                        : () {
                                            if (info!.highestQual < 1) return;
                                            info!.match = MatchInfo(
                                                level: MatchLevel.qualification,
                                                index: (info!.match == null
                                                        ? info!.highestQual
                                                        : info!.match!.index - 1)
                                                    .clamp(1, info!.highestQual));
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
                    ])),
                const Flexible(flex: 1, child: SizedBox(width: 12)),
                Flexible(
                    flex: 5,
                    child: ListenableOrNot(
                        listenable: info?.teamNotifier,
                        builder: (context, _) => DropdownButtonFormField(
                            alignment: Alignment.bottomCenter,
                            decoration: const InputDecoration(helperText: "Team"),
                            focusColor: Colors.transparent,
                            isExpanded: false,
                            value: info?.team,
                            items: info?.teams == null
                                ? <DropdownMenuItem<String>>[]
                                : [
                                    for (var MapEntry(key: team, value: position)
                                        in info!.teams!.entries)
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
                                                    RobotPositionChip(position)
                                                  ])))
                                  ],
                            onTap: () => info!.team ??= (info!.teams!.keys.toList(growable: false)
                                  ..sort((a, b) =>
                                      info!.teams![a]!.currentScouters -
                                      info!.teams![b]!.currentScouters))
                                .first,
                            onChanged:
                                info == null ? null : (String? value) => info!.team = value)))
              ])));
}

class CounterFormField extends FormField<int> {
  CounterFormField(
      {super.key, super.onSaved, super.initialValue = 0, String? labelText, required int season})
      : super(builder: (FormFieldState<int> state) {
          Color? customColor = _getColor(labelText, season);
          return Material(
              type: MaterialType.button,
              borderRadius: BorderRadius.circular(4),
              color: customColor ?? Theme.of(state.context).colorScheme.tertiaryContainer,
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
                                              color: customColor != null
                                                  ? customColor.grayLuminance > 0.5
                                                      ? Colors.grey[900]
                                                      : Colors.white
                                                  : Theme.of(state.context)
                                                      .colorScheme
                                                      .onTertiaryContainer))
                                      : null)),
                          Expanded(
                              flex: 5,
                              child: FittedBox(
                                  child: Text(state.value.toString(),
                                      style: TextStyle(
                                          color: customColor == null
                                              ? null
                                              : customColor.grayLuminance > 0.5
                                                  ? Colors.grey[900]
                                                  : Colors.white)))),
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
                              color: customColor != null && customColor.grayLuminance > 0.5
                                  ? Colors.black54
                                  : Colors.white70,
                              onPressed: () =>
                                  state.value! > 0 ? state.didChange(state.value! - 1) : null,
                            )))
                  ])));
        });
  static Color? _getColor(String? labelText, int season) {
    if (labelText == null) return null;
    final lower = labelText.toLowerCase();
    return switch (season) {
      2025 => lower.startsWith("coral")
          ? const Color(0xffc0c0c0)
          : lower.startsWith("algae")
              ? const Color(0xff3a854d)
              : null,
      2023 => lower.startsWith("cone")
          ? const Color(0xffccc000)
          : lower.startsWith("cube")
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
