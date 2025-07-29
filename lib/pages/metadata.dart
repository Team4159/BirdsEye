import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/sharedprefs.dart';
import 'package:birdseye/routing.dart';
import 'package:birdseye/usermetadata.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MetadataPage extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final _nameController = TextEditingController();
  final _teamController = TextEditingController();
  final _apikeyController = TextEditingController(text: SharedPreferencesInterface.tbakey);
  final _tbaFieldError = ValueNotifier<String?>(null);
  MetadataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userMeta = UserMetadata.of(context);
    _nameController.text = userMeta.name ?? "";
    _teamController.text = userMeta.team?.toString() ?? "";
    return Scaffold(
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
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-z\d+/=]'))],
                  controller: _apikeyController,
                  decoration: InputDecoration(
                    labelText: "TBA API Key",
                    counterText: "",
                    errorText: error,
                    suffixIcon: IconButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => _TBAInfoDialog(
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
                          _apikeyController.text = SharedPreferencesInterface.tbakey ?? "";
                          try {
                            final valid = await BlueAlliance.isKeyValid(_apikeyController.text);
                            if (!valid) {
                              _tbaFieldError.value = "Invalid";
                              return;
                            }
                            // ignore: use_build_context_synchronously
                            const ConfigurationRoute().go(context);
                          } catch (e) {
                            _tbaFieldError.value = e.toString();
                          }
                        },
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          try {
                            final valid = await BlueAlliance.isKeyValid(_apikeyController.text);
                            if (!valid) {
                              _tbaFieldError.value = "Invalid";
                              return;
                            }
                            SharedPreferencesInterface.tbakey = _apikeyController.text;
                            await userMeta.update(
                              _nameController.text,
                              int.parse(_teamController.text),
                            );
                            // ignore: use_build_context_synchronously
                            const ConfigurationRoute().go(context);
                          } catch (e) {
                            _tbaFieldError.value = e.toString();
                          }
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
}

class _TBAInfoDialog extends Dialog {
  _TBAInfoDialog({required TextStyle titleText, required TextStyle littleText})
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
