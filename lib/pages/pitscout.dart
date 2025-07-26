import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/mixed.dart';
import '../interfaces/supabase.dart' show PitInterface, SupabaseInterface;
import '../utils.dart';
import './metadata.dart';

class PitScoutPage extends StatefulWidget {
  final int season;
  final String event;
  const PitScoutPage({super.key, required this.season, required this.event});

  @override
  State<PitScoutPage> createState() => _PitScoutPageState();
}

class _PitScoutPageState extends State<PitScoutPage> {
  final GlobalKey<FormFieldState<String>> _teamFieldKey = GlobalKey();
  final ValueNotifier<int?> _team = ValueNotifier(null);
  String? _teamFieldError; // responds to _team's valuenotifier
  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _scrollController = ScrollController();

  List<int>? unfilled; // memory cache
  Future<List<int>> _getUnfilled() {
    if (unfilled != null) return Future.value(unfilled);
    return MixedInterfaces.getPitUnscoutedTeams(widget.season, widget.event).then((teams) {
      teams.remove(UserMetadata.team);
      return unfilled = teams;
    }).catchError((e) => <int>[]);
  }

  @override
  void initState() {
    _getUnfilled();
    super.initState();
    _team.addListener(() => SupabaseInterface.setSession(
        (season: widget.season, event: widget.event, match: null, team: _team.value?.toString())));
  }

  @override
  void dispose() {
    _team.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
            const SliverAppBar(
                primary: true, floating: true, snap: true, title: Text("Pit Scouting")),
            SliverToBoxAdapter(
                child: Align(
                    alignment: Alignment.topRight,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                  flex: 2,
                                  child: TextField(
                                    textAlignVertical: TextAlignVertical.top,
                                    controller: TextEditingController(text: widget.event),
                                    decoration: const InputDecoration(
                                        helperText: "Event",
                                        counter: Icon(Icons.edit_off_rounded,
                                            size: 11, color: Colors.grey)),
                                    readOnly: true,
                                    canRequestFocus: false,
                                  )),
                              const Spacer(),
                              Flexible(
                                  flex: 3,
                                  child: Autocomplete(
                                      optionsMaxHeight: 300,
                                      optionsBuilder: (value) => _getUnfilled().then((teams) =>
                                          teams.where(
                                              (team) => team.toString().startsWith(value.text))),
                                      fieldViewBuilder: (context, textEditingController, focusNode,
                                              onSubmitted) =>
                                          ListenableBuilder(
                                              listenable: _team,
                                              builder: (context, _) => TextFormField(
                                                  key: _teamFieldKey,
                                                  controller: textEditingController,
                                                  focusNode: focusNode,
                                                  autocorrect: false,
                                                  autovalidateMode:
                                                      AutovalidateMode.onUserInteraction,
                                                  decoration: const InputDecoration(
                                                      helperText: "Team", counterText: ""),
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.digitsOnly
                                                  ],
                                                  maxLength: longestTeam,
                                                  validator: (value) {
                                                    if (value?.isEmpty ?? true) {
                                                      return "Required";
                                                    }
                                                    if (_teamFieldError != null) {
                                                      return _teamFieldError!.isEmpty
                                                          ? null
                                                          : _teamFieldError;
                                                    }
                                                    return null;
                                                  },
                                                  onChanged: (value) {
                                                    _team.value = null;
                                                    BlueAlliance.stock
                                                        .get(TBAInfo(
                                                            season: widget.season,
                                                            event: widget.event,
                                                            match: "*"))
                                                        .then((data) => Set<String>.of(data.keys)
                                                            .contains(value))
                                                        .then((isValid) {
                                                      _teamFieldError = isValid ? "" : "Invalid";
                                                      _teamFieldKey.currentState!.validate();
                                                    }).reportError(context);
                                                  },
                                                  onFieldSubmitted: (String? value) async {
                                                    if (value == null) return;
                                                    if (_teamFieldError?.isNotEmpty ?? true) return;
                                                    int team = int.parse(value);
                                                    onSubmitted();
                                                    Map<String, String>? prev =
                                                        (await PitInterface.pitResponseFetch((
                                                      season: widget.season,
                                                      event: widget.event,
                                                      team: team
                                                    ), UserMetadata.id!))
                                                            .singleOrDie;
                                                    if (prev != null) {
                                                      for (var MapEntry(:key, :value)
                                                          in prev.entries) {
                                                        _controllers[key] ??=
                                                            TextEditingController();
                                                        _controllers[key]!.text = value;
                                                      }
                                                    }
                                                    _team.value = team;
                                                  })),
                                      onSelected: (int team) {
                                        _team.value = team;
                                        _teamFieldError = "";
                                      }))
                            ]))))
          ],
      body: SafeArea(
          child: SensibleFutureBuilder(
              future: PitInterface.pitscoutStock.get(widget.season),
              builder: (context, snapshot) => ListenableBuilder(
                  listenable: _team,
                  builder: (context, child) => AnimatedSlide(
                      offset: (_team.value != null) ? Offset.zero : const Offset(0, 1),
                      curve: Curves.easeInOutCirc,
                      duration: Durations.extralong3,
                      child: child),
                  child: CustomScrollView(cacheExtent: double.infinity, slivers: [
                    for (var MapEntry(:key, value: question) in snapshot.data!.entries)
                      SliverPadding(
                          padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                          sliver: SliverToBoxAdapter(
                              child: Material(
                                  type: MaterialType.button,
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(question,
                                                style: Theme.of(context).textTheme.titleSmall,
                                                textScaler: const TextScaler.linear(1.5)),
                                            const SizedBox(height: 16),
                                            TextField(
                                                controller: _controllers[key] ??=
                                                    TextEditingController(),
                                                keyboardType: TextInputType.multiline,
                                                maxLines: null,
                                                maxLength: 65535,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer),
                                                cursorColor: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                decoration: InputDecoration(
                                                    hintText: "Type answer",
                                                    counterText: "",
                                                    focusedBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSecondaryContainer))))
                                          ]))))),
                    SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverToBoxAdapter(
                            child: Row(children: [
                          Expanded(
                              child: FilledButton(
                                  child: const Text("Submit"),
                                  onPressed: () async {
                                    final info = (
                                      season: widget.season,
                                      event: widget.event,
                                      team: _team.value!,
                                    );
                                    final data =
                                        _controllers.map((key, value) => MapEntry(key, value.text));
                                    await MixedInterfaces.submitPitResponse(info, data)
                                        .reportError(context);

                                    /// Clear all the text boxes
                                    for (TextEditingController controller in _controllers.values) {
                                      controller.clear();
                                    }

                                    /// Clear the team dropdown
                                    _teamFieldKey.currentState!.didChange("");

                                    /// Clear the team-related values
                                    _team.value = _teamFieldError = null;
                                    await _scrollController.animateTo(0,
                                        duration: const Duration(seconds: 1),
                                        curve: Curves.easeOutBack);
                                  })),
                          const SizedBox(width: 10),
                          DeleteConfirmation(
                              context: context,
                              reset: () async {
                                for (TextEditingController controller in _controllers.values) {
                                  controller.clear();
                                }
                                await _scrollController.animateTo(0,
                                    duration: const Duration(seconds: 1),
                                    curve: Curves.easeOutBack);
                                _teamFieldKey.currentState!.didChange("");
                                _team.value = _teamFieldError = null;
                              })
                        ])))
                  ])))));
}
