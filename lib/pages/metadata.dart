import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/supabase.dart';
import '../main.dart';

class MetadataPage extends StatelessWidget {
  final bool isRedirect;
  final GlobalKey<FormState> _formKey = GlobalKey();
  final _nameController = TextEditingController(text: UserMetadata.instance.name);
  final _teamController = TextEditingController(text: UserMetadata.instance.team.toString());
  final _tbaFieldController = TextEditingController(text: prefs.getString("tbaKey"));
  MetadataPage({super.key, this.isRedirect = false}) {
    UserMetadata.instance.addListener(() {
      _nameController.text = UserMetadata.instance.name ?? "";
      _teamController.text = UserMetadata.instance.team?.toString() ?? "";
    });
  }

  static Dialog _tbaInfoDialog(BuildContext context) => Dialog(
      child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: "Getting a TheBlueAlliance API Key\n\n",
                style: Theme.of(context).textTheme.titleLarge),
            const TextSpan(text: "Visit the "),
            TextSpan(
                text: "account page",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(decoration: TextDecoration.underline, color: Colors.blue),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Clipboard.setData(
                          const ClipboardData(text: "https://www.thebluealliance.com/account"))
                      .then((_) => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text("Copied!"))))),
            const TextSpan(text: " (may ask for sign-in)\n"),
            const TextSpan(text: "Scroll down to "),
            TextSpan(text: 'Read API Keys', style: Theme.of(context).textTheme.bodySmall),
            const TextSpan(text: " and enter "),
            TextSpan(text: 'BirdsEye', style: Theme.of(context).textTheme.bodySmall),
            const TextSpan(text: " as the description\n"),
            const TextSpan(text: "Click "),
            TextSpan(text: 'Add New Key', style: Theme.of(context).textTheme.bodySmall),
            const TextSpan(text: " then copy the "),
            TextSpan(text: 'X-TBA-Auth-Key', style: Theme.of(context).textTheme.bodySmall),
            const TextSpan(text: " text (base 64 string)")
          ]))));

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: UserMetadata.instance.fetch().then((_) async {
        if (isRedirect && UserMetadata.isAuthenticated) {
          return UserMetadata.instance.isValid.then((valid) {
            if (!valid) return true;
            GoRouter.of(context).goNamed(RoutePaths.configuration.name);
            // replaceNamed throws a Unexpected null value if used here
            return null;
          });
        }
        return true;
      }),
      builder: (context, snapshot) => !snapshot.hasData
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.always,
                  child: Column(children: [
                    Text("Modify User Info",
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    TextFormField(
                        autofillHints: const [AutofillHints.name, AutofillHints.nickname],
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Name"),
                        keyboardType: TextInputType.name,
                        validator: (value) => value == null || value.isEmpty ? "Required" : null),
                    TextFormField(
                        controller: _teamController,
                        decoration: const InputDecoration(labelText: "Team", counterText: ""),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                        validator: (value) => value == null || value.isEmpty ? "Required" : null),
                    TextField(
                        obscureText: true,
                        autocorrect: false,
                        controller: _tbaFieldController,
                        decoration: InputDecoration(
                            labelText: "TBA API Key",
                            counterText: "",
                            suffixIcon: IconButton(
                                onPressed: () =>
                                    showDialog(context: context, builder: _tbaInfoDialog),
                                tooltip: "Instructions",
                                icon: const Icon(Icons.info_outline_rounded))),
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
                                      onPressed: () async {
                                        await UserMetadata.instance.fetch(hard: true);
                                        _tbaFieldController.text = prefs.getString("tbaKey") ?? "";
                                        if (!_formKey.currentState!.validate()) return;
                                        BlueAlliance.isKeyValid(_tbaFieldController.text)
                                            .then((valid) => valid
                                                ? GoRouter.of(context)
                                                    .goNamed(RoutePaths.configuration.name)
                                                : throw Exception("Invalid TBA Key!"))
                                            .catchError((e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text(e.message)));
                                        });
                                      },
                                      child: const Text("Cancel")),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                      onPressed: () {
                                        if (!_formKey.currentState!.validate()) return;
                                        BlueAlliance.isKeyValid(_tbaFieldController.text)
                                            .then((valid) {
                                          if (!valid) {
                                            throw Exception("Invalid TBA Key!");
                                          }
                                          prefs.setString("tbaKey", _tbaFieldController.text);
                                          return UserMetadata.instance
                                              .update(_nameController.text,
                                                  int.parse(_teamController.text))
                                              .then((_) => GoRouter.of(context)
                                                  .goNamed(RoutePaths.configuration.name));
                                        }).catchError((e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text(e.message)));
                                        });
                                      },
                                      child: const Text("Submit"))
                                ])))
                  ]))));
}

class UserMetadata extends ChangeNotifier {
  static void initialize() => Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        switch (event.event) {
          case AuthChangeEvent.mfaChallengeVerified ||
                AuthChangeEvent.passwordRecovery ||
                AuthChangeEvent.tokenRefreshed:
            break;
          case AuthChangeEvent.signedOut:
            SupabaseInterface.clearSession();
            UserMetadata.instance._name = UserMetadata.instance._team = null;
            break;
          default:
            assert(isAuthenticated);
            UserMetadata.instance.fetch();
        }
      });
  static UserMetadata instance = UserMetadata();
  static bool get isAuthenticated => Supabase.instance.client.auth.currentUser != null;

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
        .update({"name": _name ?? "User", "team": _team ?? 0})
        .eq("id", id)
        .then((_) => notifyListeners());
  }

  Future<void> fetch({bool hard = false}) => Supabase.instance.client
          .from("users")
          .select<Map<String, dynamic>?>('name, team')
          .eq('id', id)
          .maybeSingle()
          .then((value) {
        if (value == null) throw Exception("No User Found");
        bool dirty = hard || _name != value['name'] || _team != value['team'];
        _name = value['name'];
        _team = value['team'];
        if (dirty) notifyListeners();
      }).catchError((e) {
        bool dirty = hard || _name != null || _team != null;
        _name = _team = null;
        if (dirty) notifyListeners();
        throw e;
      });

  Future<bool> get isValid async =>
      _name != null &&
      _team != null &&
      prefs.containsKey("tbaKey") &&
      await BlueAlliance.isKeyValid(prefs.getString("tbaKey"));
}
