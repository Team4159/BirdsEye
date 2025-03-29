import 'package:flutter/material.dart';

import '../../interfaces/mixed.dart';
import '../../interfaces/supabase.dart';
import '../../utils.dart';
import 'graphs/eventinseason.dart';
import 'graphs/teamatevent.dart';
import 'graphs/teaminseason.dart';

class StatGraphPage extends StatelessWidget {
  final AnalysisInfo info = AnalysisInfo();
  StatGraphPage({super.key});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppBar(title: const Text("Statistic Graphs"), actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                MixedInterfaces.matchAggregateStock.clearAll();
                SupabaseInterface.eventAggregateStock.clearAll();
                SupabaseInterface.distinctStock.clearAll();
              })
        ]),
        Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: AnalysisInfoFields(info)),
        Expanded(
            child: SafeArea(
                minimum: const EdgeInsets.all(24),
                child: ListenableBuilder(
                    listenable: info,
                    builder: (context, _) {
                      if (info.season != null && info.event != null && info.team != null) {
                        return TeamAtEventGraph(
                            season: info.season!, event: info.event!, team: info.team!);
                      }
                      if (info.season != null && info.team != null) {
                        return TeamInSeasonGraph(season: info.season!, team: info.team!);
                      }
                      if (info.season != null && info.event != null) {
                        return EventInSeasonRankings(season: info.season!, event: info.event!);
                      }
                      return const Center(child: Text("Not implemented"));
                    })))
      ]);
}

/// Manages dynamic competition analysis data loading and state management for
/// a Flutter application using the ChangeNotifier pattern. Handles cascading
/// data dependencies between seasons, events, and teams, coordinating with a
/// Supabase backend to fetch filtered data sets.
///
/// When values are set through the public interfaces, dependent data is
/// automatically refreshed and listeners are notified of changes.
///
/// {@category Data Management}
///
/// ## Public Properties
/// - [seasons] → `Future<List<int>?>`: Available competition seasons/years
/// - [eventsNotifier] → `ValueNotifier<List<String?>?>`: Observable list of events
/// - [teamsNotifier] → `ValueNotifier<List<String?>?>`: Observable list of teams
/// - [season] ↔ `int?`: Currently selected season (setter triggers events load)
/// - [event] ↔ `String?`: Currently selected event (setter triggers teams load)
/// - [team] ↔ `String?`: Currently selected team (uppercase formatted)
///
/// ## Data Flow
/// 1. Setting [season] → loads events via [_events] → updates [eventsNotifier]
/// 2. Setting [event] → loads teams via [_fetchTeams] → updates [teamsNotifier]
/// 3. Setting [team] → finalizes filter selection
///
/// ## Implementation Details
/// - Integrates with [SupabaseInterface] for database operations
/// - Maintains sorted lists (natural order for seasons/events, numerical for teams)
/// - Automatically converts [event] to lowercase and [team] to uppercase
/// - Uses [ValueNotifier] for observable collections and [ChangeNotifier] for
///   state propagation
class AnalysisInfo extends ChangeNotifier {
  final Future<List<int>?> seasons = SupabaseInterface.getAvailableSeasons().nullifyErrors;

  int? _season;
  int? get season => _season;
  set season(int? s) {
    _season = s;
    _fetchEvents().then((_) => _fetchTeams()).then((_) => notifyListeners());
  }

  ValueNotifier<List<String>?> eventsNotifier = ValueNotifier(null);

  Future<List<String>?> _fetchEvents() => (_season == null
              ? Future.value(null)
              : SupabaseInterface.distinctStock
                  .get((season: _season!, event: null, team: _team)).then(
                      (e) => e.events.toList()..sort()))
          .then((v) {
        if (v == null || !v.contains(event)) event = null;
        return v;
      }).then((v) => eventsNotifier.value = v);

  String? _event;
  String? get event => _event;
  set event(String? e) {
    if (e == _event) return;
    _event = e?.toLowerCase();
    _fetchTeams().then((_) => notifyListeners());
  }

  ValueNotifier<List<String>?> teamsNotifier = ValueNotifier(null);

  Future<List<String>?> _fetchTeams() => (_season == null
              ? Future.value(null)
              : SupabaseInterface.distinctStock
                  .get((season: season!, event: event, team: null)).then((t) => t.teams.toList()
                    ..sort((a, b) => (int.tryParse(a) ?? 0) - (int.tryParse(b) ?? 0))))
          .then((v) {
        if (v == null || !v.contains(team)) team = null;
        return v;
      }).then((v) => teamsNotifier.value = v);

  String? _team;
  String? get team => _team;
  set team(String? t) {
    if (t == _team) return;
    _team = t?.toUpperCase();
    notifyListeners();
  }
}

/// A widget cluster that displays interactive filter controls for competition
/// analysis data, synchronized with an [AnalysisInfo] state manager.
///
/// {@category UI Components}
///
/// ## Usage
/// Provides three cascading dropdown filters in a horizontal layout:
/// 1. Season selection (populated asynchronously)
/// 2. Event selection (dependent on season)
/// 3. Team selection (dependent on event)
///
/// Maintains automatic data refresh through [ValueListenableBuilder] and
/// [FutureBuilder] integrations with the provided [AnalysisInfo] instance.
///
/// ## Public Properties
/// - [info] → [AnalysisInfo]: Required state management controller handling
///   data loading and value synchronization
///
/// ## Behavior
/// - Seasons dropdown initializes first with future-based loading
/// - Event and Team dropdowns update reactively when parent values change
/// - Selection changes propagate back to [AnalysisInfo], triggering:
///   - Dependent data loading (events → teams)
///   - Value formatting (lowercase events, uppercase teams)
///   - Listener notifications for UI updates
class AnalysisInfoFields extends StatelessWidget {
  final AnalysisInfo info;
  AnalysisInfoFields(this.info, {super.key}) {
    info.addListener(() {
      eventCtrller.currentState!.value = info.event;
      teamCtrller.currentState!.value = info.team;
    });
  }

  final GlobalKey<SensibleDropdownState<String>> teamCtrller = GlobalKey(),
      eventCtrller = GlobalKey();

  @override
  Widget build(BuildContext context) => Row(children: [
        FutureBuilder(
            future: info.seasons,
            builder: (context, snapshot) => SensibleDropdown<int>(snapshot.data,
                width: 90, label: "Season", onChanged: (s) => info.season = s)),
        const SizedBox(width: 8),
        ValueListenableBuilder(
            valueListenable: info.eventsNotifier,
            builder: (context, events, _) => SensibleDropdown<String>(events,
                width: 90, label: "Event", onChanged: (e) => info.event = e, key: eventCtrller)),
        const SizedBox(width: 8),
        ValueListenableBuilder(
            valueListenable: info.teamsNotifier,
            builder: (context, teams, _) => SensibleDropdown<String>(teams,
                width: 90, label: "Team", onChanged: (t) => info.team = t, key: teamCtrller)),
      ]);
}
