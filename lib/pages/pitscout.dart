import 'package:async/async.dart' show CancelableOperation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/mixed.dart';
import '../interfaces/supabase.dart' show PitInterface, SupabaseInterface;
import '../utils.dart';
import './metadata.dart';

class PitScoutPage extends StatelessWidget {
  final int season;
  final String event;
  PitScoutPage({super.key, required this.season, required this.event});

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int?> _team = ValueNotifier(null);
  final GlobalKey<_PitScoutConfigState> _configKey = GlobalKey();

  @override
  Widget build(BuildContext context) => NestedScrollView(
    controller: _scrollController,
    headerSliverBuilder: (context, _) => [
      const SliverAppBar(primary: true, floating: true, snap: true, title: Text("Pit Scouting")),
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.topRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: _PitScoutConfig(
              season: season,
              event: event,
              submit: (team) {
                if (_team.value == team) return;
                SupabaseInterface.setSession((
                  season: season,
                  event: event,
                  match: null,
                  team: team.toString(),
                ));
                _team.value = team;
              },
              key: _configKey,
            ),
          ),
        ),
      ),
    ],
    body: ValueListenableBuilder(
      valueListenable: _team,
      builder: (context, team, _) => AnimatedSwitcher(
        duration: Durations.extralong4,
        child: team == null
            ? const Center(child: Text("Enter a team number."))
            : SafeArea(
                child: _PitScoutForm(
                  season,
                  event,
                  team,
                  submit: (fields) async {
                    final info = (season: season, event: event, team: team);
                    await MixedInterfaces.submitPitResponse(info, fields).reportError(context);
                    _scrollController.animateTo(
                      0,
                      duration: Durations.medium2,
                      curve: Curves.easeInCubic,
                    );

                    /// Clear the team dropdown
                    _team.value = null;
                    _configKey.currentState!.reset();
                  },
                  reset: () async {
                    _scrollController.animateTo(
                      0,
                      duration: Durations.medium2,
                      curve: Curves.easeInCubic,
                    );

                    /// Clear the team dropdown
                    _team.value = null;
                    _configKey.currentState!.reset();
                  },
                ),
              ),
      ),
    ),
  );
}

class _PitScoutConfig extends StatefulWidget {
  final int season;
  final String event;
  const _PitScoutConfig({
    super.key,
    required this.season,
    required this.event,
    required this.submit,
  });

  final ValueChanged<int?> submit;

  @override
  State<_PitScoutConfig> createState() => _PitScoutConfigState();
}

class _PitScoutConfigState extends State<_PitScoutConfig> {
  List<int>? _unfilledTeams;
  final GlobalKey<FormFieldState<String>> _teamFieldKey = GlobalKey();
  CancelableOperation? _teamFieldValFuture;

  /// String: Has Error. Empty Str: Loading. Null: Valid
  String? _teamFieldError;

  void reset() {
    _teamFieldValFuture?.cancel();
    _teamFieldError = null;
    _teamFieldKey.currentState?.didChange(null);
  }

  @override
  void initState() {
    reload();
    super.initState();
  }

  Future<void> reload() => MixedInterfaces.getPitUnscoutedTeams(widget.season, widget.event)
      .then((teams) {
        teams.remove(UserMetadata.team);
        return setState(() => _unfilledTeams = teams);
      })
      .reportError(context);

  @override
  Widget build(Object context) => Row(
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
            counter: Icon(Icons.edit_off_rounded, size: 11, color: Colors.grey),
          ),
          readOnly: true,
          canRequestFocus: false,
        ),
      ),
      const Spacer(),
      Flexible(
        flex: 3,
        child: Autocomplete(
          optionsMaxHeight: 300,
          optionsBuilder: (value) =>
              _unfilledTeams?.where((team) => team.toString().startsWith(value.text)) ?? <int>[],
          fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) =>
              TextFormField(
                key: _teamFieldKey,
                controller: textEditingController,
                focusNode: focusNode,
                autocorrect: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(helperText: "Team", counterText: ""),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: longestTeam,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return "Required";
                  }

                  if (_teamFieldError == "") {
                    _teamFieldValFuture = CancelableOperation.fromFuture(
                      BlueAlliance.stock
                          .get(TBAInfo(season: widget.season, event: widget.event, match: "*"))
                          .then((data) => Set<String>.of(data.keys).contains(value))
                          .then((isValid) {
                            _teamFieldError = isValid ? null : "Invalid";
                            _teamFieldKey.currentState!.validate();
                          })
                          .reportError(context),
                    );
                    return _teamFieldError = "Loading..";
                  }

                  return _teamFieldError;
                },
                onChanged: (value) {
                  widget.submit(null);
                  _teamFieldValFuture?.cancel();
                  _teamFieldError = "";
                },
                onFieldSubmitted: (String? value) async {
                  if (value == null || value.isEmpty) return;
                  if (_teamFieldError != null) return;
                  int team = int.parse(value);
                  onSubmitted();
                  widget.submit(team);
                },
              ),
          onSelected: (int team) {
            widget.submit(team);
            _teamFieldError = null;
          },
        ),
      ),
    ],
  );
}

class _PitScoutForm extends StatelessWidget {
  final Map<String, TextEditingController> _controllers = {};
  _PitScoutForm(this.season, String event, int team, {this.reset, required this.submit}) {
    PitInterface.pitResponseFetch((
      season: season,
      event: event,
      team: team,
    ), UserMetadata.id!).then((prevResp) {
      if (prevResp.isEmpty) return;
      for (var MapEntry(:key, :value) in prevResp.single.entries) {
        _controllers[key] ??= TextEditingController();
        _controllers[key]!.text = value;
      }
    });
  }
  final Future Function()? reset;
  final Future Function(Map<String, dynamic> fields) submit;
  final int season;

  @override
  Widget build(BuildContext context) => SensibleFutureBuilder(
    future: PitInterface.pitscoutStock.get(season),
    builder: (context, data) => CustomScrollView(
      cacheExtent: double.infinity,
      slivers: [
        for (var MapEntry(:key, value: question) in data.entries)
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
                      Text(
                        question,
                        style: Theme.of(context).textTheme.titleSmall,
                        textScaler: const TextScaler.linear(1.5),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controllers[key] ??= TextEditingController(),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        maxLength: 65535,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                        cursorColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        decoration: InputDecoration(
                          hintText: "Type answer",
                          counterText: "",
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    child: const Text("Submit"),
                    onPressed: () async {
                      await submit(_controllers.map((key, value) => MapEntry(key, value.text)));
                      for (TextEditingController controller in _controllers.values) {
                        controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                DeleteConfirmation(
                  context: context,
                  reset: () async {
                    for (TextEditingController controller in _controllers.values) {
                      controller.clear();
                    }
                    if (reset != null) reset!();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
