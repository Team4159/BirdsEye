import 'package:birdseye/usermetadata.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:birdseye/util/common.dart' show DeleteConfirmation, ErrorReportingFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/supabase.dart' show PitInterface, SupabaseInterface;

class PitScoutPage extends StatelessWidget {
  final int season;
  final String event;
  PitScoutPage({super.key, required this.season, required this.event});

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int?> _team = ValueNotifier(null);
  final GlobalKey<FormFieldState<String>> _configKey = GlobalKey();

  void reset() {
    _scrollController.animateTo(0, duration: Durations.medium2, curve: Curves.easeInCubic);

    /// Clear the team field
    _team.value = null;
    _configKey.currentState!.reset();
  }

  @override
  Widget build(BuildContext context) => SensibleFetcher<List<Object>>(
    getFuture: () => Future.wait(<Future<Object>>[
      BlueAlliance.stock
          .get(TBAInfo(season: season, event: event, match: "*"))
          .then((data) => data.keys.toSet()),
      PitInterface.getPitScoutedTeams(
        season,
        event,
        // ignore: use_build_context_synchronously
      ).then((scouted) => scouted..add(UserMetadata.read(context)!.team!)),
    ]),
    loadingIndicator: null,
    builtInRefresh: false,
    child: NestedScrollView(
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
                textFieldKey: _configKey,
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
                    initial:
                        PitInterface.pitResponseFetch((
                              season: season,
                              event: event,
                              team: team,
                            ), UserMetadata.of(context).id!)
                            .then<Map<String, String>?>((prevResp) => prevResp.singleOrNull)
                            .onError((_, _) => null),
                    submit: (fields) async {
                      final info = (season: season, event: event, team: team);
                      await PitInterface.pitResponseSubmit(info, fields).reportError(context);
                      reset();
                    },
                    reset: reset,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// Depends on a `SensibleFetcher<List<Object>>` in the hierarchy
class _PitScoutConfig extends StatelessWidget {
  final Key? textFieldKey;

  final int season;
  final String event;
  const _PitScoutConfig({
    this.textFieldKey,
    required this.season,
    required this.event,
    required this.submit,
  });

  final ValueChanged<int?> submit;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Flexible(
        flex: 2,
        child: TextField(
          textAlignVertical: TextAlignVertical.top,
          controller: TextEditingController(text: event),
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
        child: _PitScoutConfigTeamField(textFieldKey: textFieldKey, submit: submit),
      ),
    ],
  );
}

class _PitScoutConfigTeamField extends StatelessWidget {
  final Key? textFieldKey;

  final ValueChanged<int?> submit;
  const _PitScoutConfigTeamField({this.textFieldKey, required this.submit});

  @override
  Widget build(BuildContext context) {
    final snapshot = SensibleFetcher.of<List<Object>>(context);
    final teams = snapshot.data?[0] as Set<String>?;
    final scouted = snapshot.data?[1] as Set<int>?;

    final List<int>? unscouted;
    if (teams != null && scouted != null) {
      unscouted = teams.map(int.tryParse).whereType<int>().toSet().difference(scouted).toList()
        ..sort();
    } else {
      unscouted = null;
    }

    return Autocomplete<int>(
      optionsBuilder: (value) =>
          unscouted?.where((team) => team.toString().startsWith(value.text)) ?? <int>[],
      fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) => TextFormField(
        key: textFieldKey,
        controller: textEditingController,
        focusNode: focusNode,
        autocorrect: false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(helperText: "Team", counterText: ""),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: longestTeam,
        validator: (value) {
          if (value == null || value.isEmpty) return "Required";
          if (teams == null) return "Loading";
          if (teams.contains(value)) return null;
          return "Invalid";
        },
        onChanged: (_) => submit(null),
        onFieldSubmitted: (value) {
          onSubmitted();
          if (teams != null && teams.contains(value)) submit(int.parse(value));
        },
      ),
      onSelected: submit,
    );
  }
}

class _PitScoutForm extends StatelessWidget {
  final int season;
  final Future Function(Map<String, String> fields) submit;
  final VoidCallback? reset;

  _PitScoutForm(
    this.season, {
    Future<Map<String, String>?>? initial,
    required this.submit,
    this.reset,
  }) {
    initial?.then((initial) {
      if (initial == null) return;
      for (final MapEntry(:key, :value) in initial.entries) {
        (_controllers[key] ??= TextEditingController()).text = value;
      }
    });
  }
  final Map<String, TextEditingController> _controllers = {};

  // just so we don't have to rebuild it :)
  late final Widget _submitButton = Expanded(
    child: FilledButton(
      child: const Text("Submit"),
      onPressed: () async {
        await submit(_controllers.map((key, value) => MapEntry(key, value.text)));
        for (final controller in _controllers.values) {
          controller.clear();
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) => SensibleFetcher<Map<String, String>>(
    getFuture: () => PitInterface.pitSchemaStock.get(season),
    loadingIndicator: const CircularProgressIndicator(),
    child: Builder(
      builder: (context) => CustomScrollView(
        cacheExtent: double.infinity,
        slivers: [
          for (var MapEntry(:key, value: question) in SensibleFetcher.of<Map<String, String>>(
            context,
          ).data!.entries)
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
                          maxLength: 4096,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
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
                  _submitButton,
                  const SizedBox(width: 10),
                  DeleteConfirmation(
                    context: context,
                    reset: () async {
                      for (final controller in _controllers.values) {
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
    ),
  );
}
