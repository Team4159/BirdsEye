import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../main.dart' show RoutePaths, prefs;

class MetadataPage extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final _tbaFieldController =
      TextEditingController(text: prefs.getString("tbaKey"));
  MetadataPage({super.key});

  @override
  Widget build(BuildContext context) {
    String? name;
    int? team;
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.always,
            child: Column(children: [
              Text("Modify User Info",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              ListenableBuilder(
                  listenable: UserMetadata.instance,
                  builder: (context, child) => TextFormField(
                        initialValue: UserMetadata.instance.name,
                        decoration: const InputDecoration(labelText: "Name"),
                        keyboardType: TextInputType.name,
                        validator: (value) =>
                            value == null || value.isEmpty ? "Required" : null,
                        onSaved: (String? value) => name = value,
                      )),
              ListenableBuilder(
                  listenable: UserMetadata.instance,
                  builder: (context, child) => TextFormField(
                        initialValue: UserMetadata.instance.team?.toString(),
                        decoration: const InputDecoration(
                            labelText: "Team", counterText: ""),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 4,
                        validator: (value) =>
                            value == null || value.isEmpty ? "Required" : null,
                        onSaved: (String? value) =>
                            team = int.tryParse(value ?? ""),
                      )),
              TextField(
                  obscureText: true,
                  controller: _tbaFieldController,
                  decoration: const InputDecoration(
                      labelText: "TBA API Key", counterText: ""),
                  keyboardType: TextInputType.none,
                  maxLength: 64),
              Expanded(
                  child: Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                                onPressed: () {
                                  _formKey.currentState!.reset();
                                  _tbaFieldController.text =
                                      prefs.getString("tbaKey") ?? "";
                                  if (!_formKey.currentState!.validate()) {
                                    return UserMetadata.instance
                                        .fetch()
                                        .ignore();
                                  }
                                  BlueAlliance.isKeyValid(
                                          prefs.getString("tbaKey"))
                                      .then((valid) => valid
                                          ? GoRouter.of(context).goNamed(
                                              RoutePaths.configuration.name)
                                          : throw Exception("Invalid TBA Key!"))
                                      .catchError((e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)));
                                  });
                                },
                                child: const Text("Cancel")),
                            const SizedBox(width: 8),
                            FilledButton(
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  _formKey.currentState!.save();
                                  BlueAlliance.isKeyValid(
                                          _tbaFieldController.text)
                                      .then((valid) {
                                    if (!valid) {
                                      throw Exception("Invalid TBA Key!");
                                    }
                                    prefs.setString(
                                        "tbaKey", _tbaFieldController.text);
                                    return UserMetadata.instance
                                        .update(name, team)
                                        .then((_) => GoRouter.of(context)
                                            .goNamed(
                                                RoutePaths.configuration.name));
                                  }).catchError((e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)));
                                  });
                                },
                                child: const Text("Submit"))
                          ])))
            ])));
  }
}

class UserMetadata extends ChangeNotifier {
  static void initialize() =>
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.event
            case AuthChangeEvent.mfaChallengeVerified ||
                AuthChangeEvent.passwordRecovery ||
                AuthChangeEvent.tokenRefreshed) return;
        if (event.event == AuthChangeEvent.signedIn) {
          UserMetadata.instance = UserMetadata();
        }
        UserMetadata.instance.fetch();
      });
  static late UserMetadata instance;
  static bool get isAuthenticated =>
      Supabase.instance.client.auth.currentUser != null;

  final String? id = Supabase.instance.client.auth.currentUser?.id;
  String? _name;
  int? _team;

  String? get name => _name;
  int? get team => _team;

  Future<void> update(String? name, int? team) {
    _name = name;
    _team = team;
    return Supabase.instance.client
        .from("users")
        .update(<String, dynamic>{
          if (_name != null) "name": name,
          if (_team != null) "team": team
        })
        .eq("id", id)
        .then((_) => notifyListeners());
  }

  Future<void> fetch() => Supabase.instance.client
          .from("users")
          .select<Map<String, dynamic>?>('name, team')
          .eq('id', id)
          .maybeSingle()
          .then((value) {
        if (value == null) throw Exception("No User Found");
        _name = value['name'];
        _team = value['team'];
      }).catchError((e) {
        _name = _team = null;
        throw e;
      }).whenComplete(() => notifyListeners());

  Future<bool> get isValid async =>
      _name != null &&
      _team != null &&
      prefs.containsKey("tbaKey") &&
      await BlueAlliance.isKeyValid(prefs.getString("tbaKey"));
}
