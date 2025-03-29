import 'package:flutter/material.dart';

import '../../../interfaces/supabase.dart' show EventAggregateMethod, SupabaseInterface;
import '../../../utils.dart' show SliverAnimatedInList;

class EventInSeasonRankings extends StatelessWidget {
  final int season;
  final String event;
  EventInSeasonRankings({super.key, required this.season, required this.event});

  final ValueNotifier<EventAggregateMethod> method = ValueNotifier(EventAggregateMethod.defense);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: method,
      builder: (context, _) => CustomScrollView(slivers: [
            SliverPadding(
                padding: const EdgeInsets.only(bottom: 12),
                sliver: SliverToBoxAdapter(
                    child: Row(children: [
                  const Expanded(child: SizedBox()),
                  Text("Sort: ", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 12),
                  SegmentedButton(
                      segments: EventAggregateMethod.values
                          .map((method) => ButtonSegment(value: method, label: Text(method.name)))
                          .toList(),
                      selected: {method.value},
                      onSelectionChanged: (value) => method.value = value.single)
                ]))),
            FutureBuilder(
                future: SupabaseInterface.eventAggregateStock
                    .get((season: season, event: event, method: method.value)),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                          Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                          const SizedBox(height: 20),
                          Text(snapshot.error.toString())
                        ]));
                  }
                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                        hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
                  }
                  return SliverAnimatedInList(snapshot.data!.entries.toList(),
                      key: GlobalObjectKey(snapshot.data!),
                      builder: (context, e) => ListTile(
                          title: Text(e.key, style: Theme.of(context).textTheme.bodyLarge),
                          trailing: Text(e.value.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.bodyMedium),
                          dense: true));
                })
          ]));
}
