import 'dart:collection';

import 'package:flutter/material.dart';

import '../../interfaces/bluealliance.dart';
import '../admin/statgraph.dart';
import '../configuration.dart';
import '../matchscout.dart';
import '../metadata.dart';

class MatchInsightPage extends StatelessWidget {
  final ValueNotifier<String?> _selectedMatch = ValueNotifier(null);
  MatchInsightPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: BlueAlliance.stock
          .get((season: Configuration.instance.season, event: Configuration.event!, match: null))
          .then((eventMatches) => Future.wait(eventMatches.keys.map((matchCode) => BlueAlliance.stock
              .get((season: Configuration.instance.season, event: Configuration.event!, match: matchCode)).then(
                  (matchTeams) => matchTeams.keys.any(
                          (teamKey) => teamKey.startsWith(UserMetadata.instance.team!.toString()))
                      ? MapEntry(matchCode, matchTeams)
                      : null))))
          .then((teamMatches) =>
              LinkedHashMap.fromEntries(teamMatches.whereType<MapEntry<String, Map<String, String>>>())),
      builder: (context, snapshot) => !snapshot.hasData
          ? snapshot.hasError
              ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  const SizedBox(height: 20),
                  Text(snapshot.error.toString())
                ])
              : const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _selectedMatch,
              builder: (context, _) => CustomScrollView(slivers: [
                    SliverAppBar(title: const Text("Match Insight"), actions: [
                      DropdownButton(
                          items: snapshot.data!.keys
                              .map((matchCode) =>
                                  DropdownMenuItem(value: matchCode, child: Text(matchCode)))
                              .toList(),
                          value: _selectedMatch.value,
                          onChanged: (matchCode) => _selectedMatch.value = matchCode)
                    ]),
                    SliverSafeArea(
                        minimum: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                        sliver: SliverGrid.count(
                            crossAxisCount: 2,
                            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 2 : 1 / 2,
                            crossAxisSpacing: 8,
                            children: [
                              if (_selectedMatch.value != null)
                                for (var team in snapshot.data![_selectedMatch.value]!.entries
                                    .map((matchTeam) => MapEntry(matchTeam.key,
                                        RobotPositionChip.robotPositionFromString(matchTeam.value)))
                                    .toList(growable: false)
                                  ..sort((a, b) =>
                                      (a.value.ordinal * 2 + (a.value.isRedAlliance ? 1 : 0)) -
                                      (b.value.ordinal * 2 + (b.value.isRedAlliance ? 1 : 0))))
                                  Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                    Text(
                                      team.key,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                          color: team.value.isRedAlliance ? frcred : frcblue),
                                    ),
                                    Expanded(
                                        child: Transform.scale(
                                            scale: 2 / 3,
                                            child: TeamInSeasonGraph(
                                                season: Configuration.instance.season,
                                                team: team.key)))
                                  ])
                            ]))
                  ])));
}
