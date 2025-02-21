import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/localstore.dart';
import '../interfaces/supabase.dart';
import '../utils.dart';
import './configuration.dart';
import './metadata.dart';

Future<Map<String, String>?> _getPrevious(int team) => Supabase.instance.client
    .from("pit_data_${Configuration.instance.season}")
    .select()
    .eq("event", Configuration.event!)
    .eq("team", team)
    .eq("scouter", UserMetadata.instance.id!)
    .maybeSingle()
    .withConverter((value) => value == null
        ? {}
        : Map.castFrom(value..removeWhere((k, _) => {"event", "team"}.contains(k))));

Future<void> submitInfo(Map<String, dynamic> data, {int? season}) async {
  final insertSeason = season ?? Configuration.instance.season;

  final event = data["event"];
  final scouter = data["scouter"];
  final team = data["team"];

  final comment = Map<String, dynamic>.from(data);
  comment.removeWhere((key, value) => ["event", "scouter", "team"].contains(key));

  final record = {
    "season": insertSeason,
    "event": event,
    "scouter": scouter,
    "team": team,
    "comment": comment,
  };

  (await SupabaseInterface.canConnect)
      ? Supabase.instance.client.from("pit_data").upsert(record)
      : LocalStoreInterface.addPit(insertSeason, record);
}

class PitScoutPage extends StatefulWidget {
  const PitScoutPage({super.key});

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
    return BlueAlliance.stock
        .get(TBAInfo(season: Configuration.instance.season, event: Configuration.event, match: "*"))
        .then((data) => Set<int>.of(data.keys.map(int.parse)))
        .then((teams) async {
      Set<int> filledteams = await Supabase.instance.client
          .from("pit_data_${Configuration.instance.season}")
          .select("team")
          .eq("event", Configuration.event!)
          .withConverter((value) => value.map<int>((e) => e['team']).toSet())
          .catchError((_) => <int>{});
      if (UserMetadata.instance.team != null) {
        filledteams.add(UserMetadata.instance.team!);
      }
      return teams.difference(filledteams).toList()..sort();
    }).then((teams) {
      return unfilled = teams;
    }).catchError((e) => <int>[]);
  }

  @override
  void initState() {
    _getUnfilled();
    super.initState();
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
                                    controller: TextEditingController(text: Configuration.event),
                                    decoration: const InputDecoration(
                                        helperText: "Event",
                                        counter: Icon(Icons.edit_off_rounded,
                                            size: 11, color: Colors.grey)),
                                    readOnly: true,
                                    canRequestFocus: false,
                                  )),
                              const Flexible(flex: 1, child: SizedBox(width: 12)),
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
                                                  maxLength: 4,
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
                                                            season: Configuration.instance.season,
                                                            event: Configuration.event,
                                                            match: "*"))
                                                        .then((data) => Set<String>.of(data.keys)
                                                            .contains(value))
                                                        .then((isValid) {
                                                      _teamFieldError = isValid ? "" : "Invalid";
                                                      _teamFieldKey.currentState!.validate();
                                                    }).catchError((e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(e.toString())));
                                                    });
                                                  },
                                                  onFieldSubmitted: (String? value) async {
                                                    if (value == null) return;
                                                    if (_teamFieldError?.isNotEmpty ?? true) return;
                                                    int team = int.parse(value);
                                                    onSubmitted();
                                                    Map<String, String>? prev =
                                                        await _getPrevious(team);
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
          child: FutureBuilder(
              future: SupabaseInterface.pitSchema,
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
                                      onPressed: () {
                                        submitInfo({
                                          ..._controllers
                                              .map((key, value) => MapEntry(key, value.text)),
                                          "event": Configuration.event,
                                          "team": _team.value
                                        }).then((_) async {
                                          for (TextEditingController controller
                                              in _controllers.values) {
                                            controller.clear();
                                          }

                                          await _scrollController.animateTo(0,
                                              duration: const Duration(seconds: 1),
                                              curve: Curves.easeOutBack);
                                          _teamFieldKey.currentState!.didChange("");
                                          _team.value = _teamFieldError = null;
                                        }).catchError((e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text(e.toString())));
                                        });
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
