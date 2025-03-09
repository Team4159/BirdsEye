import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../interfaces/bluealliance.dart';
import '../../interfaces/supabase.dart' show PitInterface;
import '../../pages/configuration.dart';

class PitSummary extends StatefulWidget {
  const PitSummary({super.key});

  @override
  State<StatefulWidget> createState() => _PitSummaryState();
}

class _PitSummaryState extends State<PitSummary> {
  int? _selectedTeam;

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _selectedTeam == null
          ? Future.value(<Map<String, String>>[{}, {}])
          : Future.wait([
              PitInterface.pitSchema,
              PitInterface.pitAggregateStock.get((
                season: Configuration.instance.season,
                event: Configuration.event!,
                team: _selectedTeam!
              ))
            ]),
      builder: (context, snapshot) => Column(children: [
            AppBar(title: const Text("Pit Responses"), actions: [
              FutureBuilder(
                  future: BlueAlliance.stock.get(TBAInfo(
                      season: Configuration.instance.season,
                      event: Configuration.event!,
                      match: "*")),
                  builder: (context, snapshot2) => DropdownButton(
                      items: !snapshot2.hasData
                          ? <DropdownMenuItem<int>>[]
                          : snapshot2.data!.keys
                              .map((teamStr) => int.tryParse(teamStr))
                              .whereType<int>()
                              .map((teamCode) => DropdownMenuItem(
                                  value: teamCode, child: Text(teamCode.toString())))
                              .toList(),
                      value: _selectedTeam,
                      onChanged: (teamCode) => setState(() => _selectedTeam = teamCode))),
              IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    PitInterface.pitAggregateStock.clearAll();
                    setState(() => _selectedTeam = null);
                  })
            ]),
            if (!snapshot.hasData)
              if (snapshot.hasError)
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                      const SizedBox(height: 20),
                      Text(snapshot.error.toString())
                    ]))
              else
                const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                  child: PageView.builder(
                      scrollBehavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: false,
                          overscroll: false,
                          dragDevices: PointerDeviceKind.values.toSet()),
                      itemCount: snapshot.data![1].length,
                      itemBuilder: (context, i) {
                        var item = snapshot.data![1].entries.elementAt(i);
                        var question = snapshot.data![0][item.key]!;
                        return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Material(
                                type: MaterialType.button,
                                borderRadius: BorderRadius.circular(4),
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(children: [
                                      Text(question,
                                          style: Theme.of(context).textTheme.titleSmall,
                                          textScaler: const TextScaler.linear(1.5)),
                                      const SizedBox(height: 16),
                                      Expanded(
                                          child: TextField(
                                              readOnly: true,
                                              expands: true,
                                              maxLines: null,
                                              controller: TextEditingController(text: item.value),
                                              textAlignVertical: TextAlignVertical.top,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer),
                                              decoration:
                                                  const InputDecoration(border: InputBorder.none)))
                                    ]))));
                      }))
          ]));
}
