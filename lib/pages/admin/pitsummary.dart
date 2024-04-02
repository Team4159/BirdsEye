import 'package:birdseye/pages/configuration.dart';
import 'package:flutter/material.dart';

import '../../interfaces/supabase.dart';

class PitSummary extends StatelessWidget {
  PitSummary({super.key});
  final ValueNotifier<int> _selectedTeam = ValueNotifier(0);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _selectedTeam,
      builder: (context, _) => FutureBuilder(
          future: SupabaseInterface.pitAggregateStock.get((
            season: Configuration.instance.season,
            event: Configuration.event!,
            team: _selectedTeam.value
          )),
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
              : ListView()));
}
