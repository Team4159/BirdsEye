import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';
import '../pages/metadata.dart';
import '../types.dart' show Achievement;
import '../utils.dart';

class AchievementsPage extends StatefulWidget {
  final int season;
  final String event;
  const AchievementsPage({super.key, required this.season, required this.event});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final TextEditingController _searchedText = TextEditingController();
  Future<List<AchPlusApproval>>? _achievementsFuture;

  void _refresh() {
    SupabaseInterface.clearAchievements();
    setState(() => _achievementsFuture = _loadAchievements());
  }

  Future<List<AchPlusApproval>> _loadAchievements() async {
    final results = await Future.wait(
        [SupabaseInterface.achievements, _getQueueData(widget.season, widget.event)]);
    final queuedata =
        results[1] as ({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details});
    return (results[0] as Set<Achievement>?)
            ?.where((ach) =>
                (ach.season == null || ach.season == widget.season) &&
                (ach.event == null || ach.event == widget.event))
            .map((ach) => (
                  achievement: ach,
                  approved: queuedata.approvals[ach.id],
                  details: queuedata.details[ach.id]
                ))
            .toList() ??
        [];
  }

  Future<({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details})> _getQueueData(
      int? season, String? event) {
    var query = Supabase.instance.client
        .from("achievement_queue")
        .select("achievement, approved, details")
        .eq("user", UserMetadata.id!);
    if (season != null) query = query.eq("season", season);
    if (event != null) query = query.eq("event", event);
    return query.withConverter((resp) => (
          approvals: Map.fromEntries(resp.map((record) => MapEntry(
              record["achievement"] as int,
              {
                null: AchievementApprovalStatus.pending,
                true: AchievementApprovalStatus.approved,
                false: AchievementApprovalStatus.rejected
              }[record["approved"] as bool?]!))),
          details: Map.fromEntries(resp
              .where((r) => r["details"] != null)
              .map((record) => MapEntry(record["achievement"] as int, record["details"] as String)))
        ));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        AppBar(
            title: const Text("Achievements"),
            actions: [IconButton(onPressed: _refresh, icon: Icon(Icons.refresh))]),
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: _searchedText,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: "Search"))),
        SensibleFutureBuilder(
            future: _achievementsFuture ??= _loadAchievements(),
            builder: (context, snapshot) => ListenableBuilder(
                listenable: _searchedText,
                builder: (context, _) {
                  List<AchPlusApproval> filteredData = snapshot.data!
                      .where((achievement) => achievement.achievement.name
                          .toLowerCase()
                          .contains(_searchedText.text.toLowerCase()))
                      .toList();

                  if (filteredData.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text("No achievements found")),
                    );
                  }

                  return CarouselSlider.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (context, i, realIndex) =>
                        _AchievementCard(filteredData[i], refresh: _refresh),
                    options: CarouselOptions(
                        viewportFraction: 0.6,
                        enlargeCenterPage: true,
                        enlargeFactor: 0.2,
                        height: 200,
                        enableInfiniteScroll: _searchedText.text.isEmpty),
                  );
                }))
      ]);
}

class _AchievementCard extends StatelessWidget {
  final AchPlusApproval achievement;
  final VoidCallback refresh;
  const _AchievementCard(this.achievement, {required this.refresh});

  @override
  Widget build(BuildContext context) => Card.filled(
      surfaceTintColor: {
        AchievementApprovalStatus.approved: Colors.green,
        AchievementApprovalStatus.rejected: Colors.red,
        AchievementApprovalStatus.pending: Colors.grey
      }[achievement.approved]!
          .withAlpha(128),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
          onTap: () => showDialog(
                  context: context,
                  builder: (context) =>
                      _AchievementSubmitDialog(achievement: achievement.achievement)).then((res) {
                /// Dialog dismissed
                if (res == null) return;

                /// Success
                if (res == true) return refresh();

                /// Error
                throw res;
              }).reportError(context),
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(mainAxisSize: MainAxisSize.max, children: [
                  Flexible(
                      flex: 5,
                      fit: FlexFit.tight,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(achievement.achievement.name,
                                  style: Theme.of(context).textTheme.headlineMedium)))),
                  const Spacer(),
                  Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                              child: Text("${achievement.achievement.points} pts",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall!
                                      .copyWith(color: Colors.grey)))))
                ]),
                const SizedBox(height: 12),
                Expanded(
                    child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Text(achievement.achievement.description,
                            style: Theme.of(context).textTheme.bodyLarge)))
              ]))));
}

class _AchievementSubmitDialog extends StatefulWidget {
  final Achievement achievement;
  const _AchievementSubmitDialog({required this.achievement});

  @override
  State<_AchievementSubmitDialog> createState() => _AchievementSubmitDialogState();
}

class _AchievementSubmitDialogState extends State<_AchievementSubmitDialog> {
  final TextEditingController _commentsController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(_submitting ? "Submitting.." : "Submit Achievement"),
        content: Column(children: [
          Text(widget.achievement.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(
            height: 4,
          ),
          Text("Requirements: ${widget.achievement.requirements}",
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(
            height: 8,
          ),
          TextField(
              enabled: !_submitting,
              controller: _commentsController,
              maxLength: 250,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Comments",
                border: OutlineInputBorder(),
              ))
        ]),
        actions: [
          IconButton(
            onPressed: _submitting ? null : () {},
            icon: const Icon(Icons.attach_file),
          ),
          const Spacer(),
          FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("Submit"),
              onPressed: _submitting
                  ? null
                  : () {
                      final nav = Navigator.of(context);
                      setState(() => _submitting = true);
                      Supabase.instance.client
                          .from("achievement_queue")
                          .insert({
                            'achievement': widget.achievement.id,
                            'season': widget.achievement.season,
                            'event': widget.achievement.event,
                            'details':
                                _commentsController.text.isEmpty ? null : _commentsController.text,
                            'user': UserMetadata.id!,
                          })
                          .then((_) => nav.pop(true))
                          .catchError((e) => nav.pop(e));
                    })
        ]);
  }
}

enum AchievementApprovalStatus { approved, rejected, pending }

typedef AchPlusApproval = ({
  Achievement achievement,
  AchievementApprovalStatus? approved,
  String? details
});
