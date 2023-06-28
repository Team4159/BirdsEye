import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/pages/metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import 'configuration.dart';

Future<List<int>> pitScoutGetUnfilled() => BlueAlliance.stock
    .get((
      season: Configuration.instance.season,
      event: Configuration.event,
      match: "*"
    ))
    .then((data) => Set<int>.of(data.keys.map(int.parse)))
    .then((teams) async {
      Set<int> filledteams = await Supabase.instance.client
          .from("${Configuration.instance.season}_pit")
          .select<List<Map<String, dynamic>>>("team")
          .eq("event", Configuration.event)
          .then((value) => value.map<int>((e) => e['team']).toSet());
      if (UserMetadata.instance.team != null) {
        filledteams.add(UserMetadata.instance.team!);
      }
      return teams.difference(filledteams).toList()..sort();
    });

class PitScoutPage extends StatefulWidget {
  const PitScoutPage({super.key});

  @override
  State<PitScoutPage> createState() => _PitScoutPageState();
}

class _PitScoutPageState extends State<PitScoutPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final GlobalKey<FormFieldState<String>> _teamFieldKey = GlobalKey();
  String? _teamFieldError;
  int? _team;
  final Map<String, String?> _fields = {};
  final ScrollController _scrollController = ScrollController();

  List<int>? unfilled;
  Future<List<int>> _getUnfilled() {
    if (unfilled != null) return Future.value(unfilled);
    return pitScoutGetUnfilled().then((teams) {
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
                primary: true,
                floating: true,
                snap: true,
                title: Text("Pit Scouting")),
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
                                    controller: TextEditingController(
                                        text: Configuration.event),
                                    decoration: const InputDecoration(
                                        helperText: "Event",
                                        counter: Icon(Icons.edit_off_rounded,
                                            size: 11, color: Colors.grey)),
                                    readOnly: true,
                                    canRequestFocus: false,
                                  )),
                              const Flexible(
                                  flex: 1, child: SizedBox(width: 12)),
                              Flexible(
                                  flex: 3,
                                  child: Autocomplete(
                                      optionsMaxHeight: 300,
                                      optionsBuilder: (value) => _getUnfilled()
                                          .then((teams) => teams.where((team) =>
                                              team
                                                  .toString()
                                                  .startsWith(value.text))),
                                      fieldViewBuilder: (context,
                                              textEditingController,
                                              focusNode,
                                              onSubmitted) =>
                                          TextFormField(
                                              key: _teamFieldKey,
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              autovalidateMode:
                                                  AutovalidateMode.always,
                                              decoration: const InputDecoration(
                                                  helperText: "Team",
                                                  counterText: ""),
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly
                                              ],
                                              maxLength: 4,
                                              validator: (value) {
                                                if (value?.isEmpty ?? true) {
                                                  return "Required";
                                                }
                                                if (_teamFieldError != null) {
                                                  return _teamFieldError!
                                                          .isEmpty
                                                      ? null
                                                      : _teamFieldError;
                                                }
                                                return null;
                                              },
                                              onChanged: (value) {
                                                if (_team != null) {
                                                  setState(() => _team = null);
                                                }
                                                BlueAlliance.stock
                                                    .get((
                                                      season: Configuration
                                                          .instance.season,
                                                      event:
                                                          Configuration.event,
                                                      match: "*"
                                                    ))
                                                    .then((data) =>
                                                        Set<String>.of(
                                                                data.keys)
                                                            .contains(value))
                                                    .then((isValid) {
                                                      _teamFieldError = isValid
                                                          ? ""
                                                          : "Invalid";
                                                      _teamFieldKey
                                                          .currentState!
                                                          .validate();
                                                    })
                                                    .catchError((e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(e
                                                                  .toString())));
                                                    });
                                              },
                                              onFieldSubmitted: (String? value) {
                                                if (value == null) return;
                                                if (_teamFieldError
                                                        ?.isNotEmpty ??
                                                    true) return;
                                                setState(() =>
                                                    _team = int.parse(value));
                                                onSubmitted();
                                              }),
                                      onSelected: (value) => setState(() => _team = value)))
                            ]))))
          ],
      body: FutureBuilder(
          future: SupabaseInterface.pitSchema,
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
                  offset: (_team != null) ? Offset.zero : const Offset(0, 1),
                  curve: Curves.easeInOutCirc,
                  duration: const Duration(seconds: 1),
                  child: Form(
                      key: _formKey,
                      child: CustomScrollView(
                          cacheExtent: double.infinity,
                          slivers: [
                            for (var MapEntry(:key, value: question)
                                in snapshot.data!.entries)
                              SliverPadding(
                                  padding: const EdgeInsets.only(
                                      top: 12, left: 12, right: 12),
                                  sliver: SliverToBoxAdapter(
                                      child: Material(
                                          type: MaterialType.button,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(question,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall,
                                                        textScaleFactor: 1.5),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                        keyboardType:
                                                            TextInputType
                                                                .multiline,
                                                        maxLines: null,
                                                        maxLength: 65535,
                                                        decoration:
                                                            const InputDecoration(
                                                                hintText:
                                                                    "Type answer",
                                                                counterText:
                                                                    ""),
                                                        onSaved: (value) =>
                                                            _fields[key] =
                                                                value)
                                                  ]))))),
                            SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverToBoxAdapter(
                                    child: FilledButton(
                                        child: const Text("Submit"),
                                        onPressed: () {
                                          _fields.clear();
                                          _formKey.currentState!.save();
                                          Supabase.instance.client
                                              .from(
                                                  "${Configuration.instance.season}_pit")
                                              .insert({
                                            "event": Configuration.event,
                                            "team": _team,
                                            ..._fields
                                          }).then((_) async {
                                            _formKey.currentState!.reset();
                                            await _scrollController.animateTo(0,
                                                duration:
                                                    const Duration(seconds: 1),
                                                curve: Curves.easeOutBack);
                                            _teamFieldKey.currentState!
                                                .didChange("");
                                            _team = _teamFieldError = null;
                                          }).catchError((e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text(e.toString())));
                                          });
                                        })))
                          ])))));
}
