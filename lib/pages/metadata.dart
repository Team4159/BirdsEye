import 'dart:async';

import 'package:birdseye/routing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/sharedprefs.dart' show SharedPreferencesInterface;
import '../interfaces/supabase.dart' show SupabaseInterface;
import '../utils.dart';

class MetadataPage extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final _nameController = TextEditingController(text: UserMetadata.name);
  final _teamController = TextEditingController(text: UserMetadata.team?.toString());
  final _tbaFieldController = TextEditingController(text: SharedPreferencesInterface.tbakey);
  final _tbaFieldError = ValueNotifier<String?>(null);
  MetadataPage({super.key}) {
    UserMetadata.changeNotifier.addListener(() {
      _nameController.text = UserMetadata.name ?? "";
      _teamController.text = UserMetadata.team?.toString() ?? "";
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      minimum: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          children: [
            Text(
              "Modify User Info",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextFormField(
              autofillHints: const [AutofillHints.name, AutofillHints.nickname],
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
              keyboardType: TextInputType.name,
              validator: (value) => value == null || value.isEmpty ? "Required" : null,
            ),
            TextFormField(
              controller: _teamController,
              decoration: const InputDecoration(labelText: "Team", counterText: ""),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: longestTeam,
              validator: (value) => value == null || value.isEmpty ? "Required" : null,
            ),
            ValueListenableBuilder(
              valueListenable: _tbaFieldError,
              builder: (context, error, _) => TextField(
                obscureText: true,
                autocorrect: false,
                controller: _tbaFieldController,
                decoration: InputDecoration(
                  labelText: "TBA API Key",
                  counterText: "",
                  errorText: error,
                  suffixIcon: IconButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => TBAInfoDialog(
                        littleText: Theme.of(context).textTheme.bodySmall!,
                        titleText: Theme.of(context).textTheme.titleLarge!,
                      ),
                    ),
                    tooltip: "Instructions",
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ),
                keyboardType: TextInputType.none,
                maxLength: 64,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await UserMetadata.fetch(hard: true);
                        _tbaFieldController.text = SharedPreferencesInterface.tbakey ?? "";
                        if (!_formKey.currentState!.validate()) return;
                        if (!context.mounted) return;
                        BlueAlliance.isKeyValid(_tbaFieldController.text)
                            .then(
                              (valid) => valid
                                  ? appRouter.go(const ConfigurationRoute().location)
                                  : throw Exception("Invalid TBA Key!"),
                            )
                            .reportError(context);
                      },
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        BlueAlliance.isKeyValid(_tbaFieldController.text)
                            .then((valid) async {
                              if (!valid) throw Exception("Invalid TBA Key!");
                              SharedPreferencesInterface.tbakey = _tbaFieldController.text;
                              await UserMetadata.update(
                                _nameController.text,
                                int.parse(_teamController.text),
                              );
                              appRouter.go(const ConfigurationRoute().location);
                            })
                            .reportError(context);
                      },
                      child: const Text("Submit"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TBAInfoDialog extends Dialog {
  TBAInfoDialog({super.key, required TextStyle titleText, required TextStyle littleText})
    : super(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "Getting a TheBlueAlliance API Key\n\n", style: titleText),
                const TextSpan(text: "Visit the "),
                TextSpan(
                  text: "account page",
                  style: littleText.copyWith(
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(Uri.https("thebluealliance.com", "/account")),
                ),
                const TextSpan(text: " (may ask for sign-in)\n"),
                const TextSpan(text: "Scroll down to "),
                TextSpan(text: 'Read API Keys', style: littleText),
                const TextSpan(text: " and enter "),
                TextSpan(text: 'BirdsEye', style: littleText),
                const TextSpan(text: " as the description\n"),
                const TextSpan(text: "Click "),
                TextSpan(text: 'Add New Key', style: littleText),
                const TextSpan(text: " then copy the "),
                TextSpan(text: 'X-TBA-Auth-Key', style: littleText),
                const TextSpan(text: " text (base 64 string)"),
              ],
            ),
          ),
        ),
      );
}

class UserMetadata {
  /// Begin listening for the initial login event
  static void init() {
    Supabase.instance.client.auth.onAuthStateChange
        .firstWhere((event) => event.session != null)
        .then((auth) => UserMetadata.signIn(auth.session!))
        .then((_) => appRouter.go(const MetadataRoute(redir: true).location));
  }

  static String? _id;
  static ({String name, int team})? _info;

  static String? get id => _id;
  static String? get name => _info?.name;
  static int? get team => _info?.team;

  static final NotifiableChangeNotifier changeNotifier = NotifiableChangeNotifier();

  static bool get signedIn => id != null;
  static Future<bool> get isValid async =>
      _info != null && await BlueAlliance.isKeyValid(SharedPreferencesInterface.tbakey);

  static Future<void> signIn(Session session) {
    _id = session.user.id;
    return fetch();
  }

  static Future<void> fetch({bool hard = false}) {
    return Supabase.instance.client
        .from("users")
        .select('name, team')
        .eq('id', id!)
        .maybeSingle()
        .then((resp) {
          if (resp == null) throw Exception("No User Found");
          if (!hard && name == resp['name'] && team == resp['team']) return;
          _info = (name: resp['name'], team: resp['team']);
          changeNotifier.notifyListeners();
        })
        .catchError((e) {
          _info = null;
          changeNotifier.notifyListeners();
          throw e;
        });
  }

  static Future<void> update(String name, int team) => Supabase.instance.client
      .from("users")
      .update({"name": name, "team": team})
      .eq("id", id!)
      .select()
      .single()
      .then((resp) {
        _info = (name: resp['name'], team: resp['team']);
        changeNotifier.notifyListeners();
      });

  static Future<void> signOut() async {
    await SupabaseInterface.clearSession();
    await Supabase.instance.client.auth.signOut();
    await Supabase.instance.client.auth.onAuthStateChange.firstWhere(
      (event) => event.session == null,
    );
    _id = _info = null;
    changeNotifier.notifyListeners();
  }
}
