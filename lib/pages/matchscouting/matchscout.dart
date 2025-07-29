import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/pages/matchscouting/config.dart';
import 'package:birdseye/util/common.dart';
import 'package:flutter/material.dart';

import 'form.dart' show MatchScoutForm;

class MatchScoutPage extends StatelessWidget {
  final MatchScoutIdentifierPartial initial;
  const MatchScoutPage(this.initial, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.max,
    children: [
      AppBar(title: const Text("Match Scouting")),
      Expanded(
        child: MatchScoutConfig(
          initial: initial,
          submit: (identifier) async {
            if (identifier == null) return;
            final nav = Navigator.of(context);
            await SupabaseInterface.setSession(identifier);
            final formContent = await nav.push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (context) => SizedBox.expand(
                  child: MatchScoutForm(
                    identifier.season,
                    reset: () async => Navigator.pop(context),
                    submit: (fields) async => Navigator.pop(context, fields),
                  ),
                ),
              ),
            );
            if (formContent != null) {
              final fut = SupabaseInterface.matchResponseSubmit(identifier, formContent);
              if (context.mounted) fut.reportError(context);
            }
            await SupabaseInterface.setSession((
              season: identifier.season,
              event: identifier.event,
              match: null,
              team: null,
            ));
          },
        ),
      ),
    ],
  );
}
