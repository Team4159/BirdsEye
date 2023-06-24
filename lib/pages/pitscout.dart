import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../main.dart' show prefs;
import 'configuration.dart';

Future<List<int>> pitScoutGetUnfilled() => BlueAlliance.stock
    .get((
      season: Configuration.instance.season,
      event: prefs.getString('event'),
      match: "*"
    ))
    .then((data) => Set<int>.of(data.keys.map(int.parse)))
    .then((teams) async {
      Set<int> filledteams = await Supabase.instance.client
          .from("${Configuration.instance.season}_pit")
          .select<List<Map<String, dynamic>>>("team")
          .eq("event", prefs.getString('event'))
          .then((value) => value.map((e) => int.parse(e['team'])).toSet());
      return teams.difference(filledteams).toList()..sort();
    });

class PitScoutPage extends StatefulWidget {
  const PitScoutPage({super.key});

  @override
  State<PitScoutPage> createState() => _PitScoutPageState();
}

class _PitScoutPageState extends State<PitScoutPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder(); // TODO add pit scouting
  }
}
