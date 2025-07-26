import 'package:birdseye/interfaces/mixed.dart';
import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/pages/matchscouting/config.dart';
import 'package:birdseye/types.dart';
import 'package:birdseye/utils.dart';
import 'package:flutter/material.dart';

import 'form.dart' show MatchScoutForm;

class MatchScoutPage extends StatelessWidget {
  final MatchScoutIdentifierPartial initial;
  const MatchScoutPage(this.initial, {super.key});

  @override
  Widget build(BuildContext context) => MatchScoutIdentifierConfig(
      initial: initial,
      submit: (identifier) async {
        if (identifier == null) return;
        final nav = Navigator.of(context);
        await SupabaseInterface.setSession(identifier).nullifyErrors;
        final formContent = await nav.push<Map<String, dynamic>>(MaterialPageRoute(
            builder: (context) => MatchScoutForm(identifier.season,
                reset: () async => Navigator.pop(context),
                submit: (fields) async => Navigator.pop(context, fields))));
        if (formContent != null) MixedInterfaces.submitMatchResponse(identifier, formContent);
        await SupabaseInterface.setSession(
                (season: identifier.season, event: identifier.event, match: null, team: null))
            .nullifyErrors;
      });
}
