import 'dart:collection';

import 'package:flutter/material.dart';

import '../../interfaces/bluealliance.dart';
import '../configuration.dart';
import '../matchscout.dart';
import '../metadata.dart';
import 'graphs/teaminseason.dart';

class MatchInsightPage extends StatelessWidget {
  final ValueNotifier<MatchInfo?> _selectedMatch = ValueNotifier(null);
  MatchInsightPage({super.key});

  // to prevent it rerunning every rebuild
  final _fetch = BlueAlliance.stock
      .get(TBAInfo(season: Configuration.instance.season, event: Configuration.event!))
      .then((eventMatches) => Future.wait(eventMatches.keys.map((matchCode) =>
          BlueAlliance.stock.get(TBAInfo(season: Configuration.instance.season, event: Configuration.event!, match: matchCode)).then(
              (matchTeams) => matchTeams.keys
                      .any((teamKey) => teamKey.startsWith(UserMetadata.instance.team!.toString()))
                  ? MapEntry(MatchInfo.fromString(matchCode), matchTeams)
                  : null))))
      .then((teamMatches) => LinkedHashMap.fromEntries(
          teamMatches.whereType<MapEntry<MatchInfo, Map<String, String>>>().toList()..sort((a, b) => a.key.compareTo(b.key))));

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _fetch,
      builder: (context, snapshot) => ListenableBuilder(
          listenable: _selectedMatch,
          builder: (context, _) => CustomScrollView(slivers: [
                SliverAppBar(title: const Text("Match Insight"), actions: [
                  DropdownButton(
                      items: !snapshot.hasData
                          ? <DropdownMenuItem<MatchInfo>>[]
                          : snapshot.data!.keys
                              .map((matchCode) => DropdownMenuItem(
                                  value: matchCode, child: Text(matchCode.toString())))
                              .toList(),
                      value: _selectedMatch.value,
                      onChanged: (matchCode) => _selectedMatch.value = matchCode)
                ]),
                if (!snapshot.hasData)
                  if (snapshot.hasError)
                    SliverFillRemaining(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                          Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                          const SizedBox(height: 20),
                          Text(snapshot.error.toString())
                        ]))
                  else
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else
                  SliverSafeArea(
                      minimum: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                      sliver: SliverGrid.count(
                          crossAxisCount: 2,
                          childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3 / 2 : 1 / 2,
                          crossAxisSpacing: MediaQuery.of(context).size.width > 600 ? 24 : 8,
                          children: [
                            if (_selectedMatch.value != null)
                              for (var team in snapshot.data![_selectedMatch.value!]!.entries
                                  .map((matchTeam) => MapEntry(matchTeam.key,
                                      RobotPositionChip.robotPositionFromString(matchTeam.value)))
                                  .toList(growable: false)
                                ..sort((a, b) =>
                                    (a.value.ordinal * 2 + (a.value.isRedAlliance ? 1 : 0)) -
                                    (b.value.ordinal * 2 + (b.value.isRedAlliance ? 1 : 0))))
                                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                  const SizedBox(height: 16),
                                  Text(
                                    team.key,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                        color: team.value.isRedAlliance ? frcred : frcblue),
                                  ),
                                  Expanded(
                                      child: TeamInSeasonGraph(
                                          season: Configuration.instance.season, team: team.key))
                                ])
                          ]))
              ])));
}
