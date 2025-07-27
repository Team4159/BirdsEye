import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';
import '../pages/metadata.dart';
import '../types.dart' show Achievement;
import '../utils.dart' show SensibleFutureBuilder, ErrorReportingFuture;

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
    setState(() {
      _achievementsFuture = _loadAchievements();
    });
  }

  Future<List<AchPlusApproval>> _loadAchievements() async {
    final results = await Future.wait([
      SupabaseInterface.achievements,
      _getQueueData(widget.season, widget.event),
    ]);
    final queuedata =
        results[1] as ({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details});
    return (results[0] as Set<Achievement>?)
            ?.where(
              (ach) =>
                  (ach.season == null || ach.season == widget.season) &&
                  (ach.event == null || ach.event == widget.event),
            )
            .map(
              (ach) => (
                achievement: ach,
                approved: queuedata.approvals[ach.id],
                details: queuedata.details[ach.id],
              ),
            )
            .toList() ??
        [];
  }

  Future<({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details})> _getQueueData(
    int season,
    String event,
  ) => Supabase.instance.client
      .from("achievement_queue")
      .select("achievement, approved, details")
      .eq("user", UserMetadata.id!)
      .eq("season", season)
      .eq("event", event)
      .withConverter(
        (resp) => (
          approvals: Map.fromEntries(
            resp.map(
              (record) => MapEntry(
                record["achievement"] as int,
                AchievementApprovalStatus.fromSqlValue(record["approved"]),
              ),
            ),
          ),
          details: Map.fromEntries(
            resp
                .where((r) => r["details"] != null)
                .map(
                  (record) => MapEntry(record["achievement"] as int, record["details"] as String),
                ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: const Text("Achievements"),
        actions: [IconButton(onPressed: _refresh, icon: Icon(Icons.refresh))],
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchedText,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search_rounded),
            hintText: "Search",
          ),
        ),
      ),
      SensibleFutureBuilder(
        future: _achievementsFuture ??= _loadAchievements(),
        builder: (context, data) => ListenableBuilder(
          listenable: _searchedText,
          builder: (context, _) {
            List<AchPlusApproval> filteredData = data
                .where(
                  (achievement) => achievement.achievement.name.toLowerCase().contains(
                    _searchedText.text.toLowerCase(),
                  ),
                )
                .toList();

            if (filteredData.isEmpty) {
              return const Center(child: Text("No achievements found"));
            }

            return CarouselSlider.builder(
              itemCount: filteredData.length,
              itemBuilder: (context, i, realIndex) => _AchievementCard(
                filteredData[i],
                refresh: _refresh,
                season: widget.season,
                event: widget.event,
              ),
              options: CarouselOptions(
                viewportFraction: 0.6,
                enlargeCenterPage: true,
                enlargeFactor: 0.2,
                height: 200,
                enableInfiniteScroll: _searchedText.text.isEmpty,
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _AchievementCard extends StatelessWidget {
  final AchPlusApproval achievement;
  final VoidCallback refresh;
  final int season;
  final String event;
  const _AchievementCard(
    this.achievement, {
    required this.refresh,
    required this.season,
    required this.event,
  });

  @override
  Widget build(BuildContext context) => Card.filled(
    shape: achievement.approved == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: achievement.approved!.color,
              width: 4,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
    clipBehavior: Clip.hardEdge,
    child: GestureDetector(
      onTap: achievement.approved == null
          ? () =>
                showDialog(
                      context: context,
                      builder: (context) => _AchievementSubmitDialog(
                        achievement: achievement.achievement,
                        season: season,
                        event: event,
                      ),
                    )
                    .then((res) {
                      /// Dialog dismissed
                      if (res == null) return;

                      /// Success
                      if (res == true) return refresh();

                      /// Error
                      throw res;
                    })
                    .reportError(context)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                  flex: 5,
                  fit: FlexFit.tight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        achievement.achievement.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 2,
                  fit: FlexFit.tight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      child: Text(
                        "${achievement.achievement.points} pts",
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Text(
                  achievement.achievement.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AchievementSubmitDialog extends StatefulWidget {
  final int season;
  final String event;
  final Achievement achievement;
  const _AchievementSubmitDialog({
    required this.achievement,
    required this.season,
    required this.event,
  });

  @override
  State<_AchievementSubmitDialog> createState() => _AchievementSubmitDialogState();
}

class _AchievementSubmitDialogState extends State<_AchievementSubmitDialog> {
  final TextEditingController _commentsController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(_submitting ? "Submitting.." : widget.achievement.name),
    ),
    titleTextStyle: Theme.of(context).textTheme.headlineMedium,

    content: ConstrainedBox(
      constraints: BoxConstraints(minWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Requirements: ${widget.achievement.requirements}",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: !_submitting,
            controller: _commentsController,
            maxLength: 250,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: "Comments",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actions: [
      IconButton(onPressed: _submitting ? null : () {}, icon: const Icon(Icons.attach_file)),
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
                      'season': widget.season,
                      'event': widget.event,
                      'details': _commentsController.text.isEmpty ? null : _commentsController.text,
                      'user': UserMetadata.id!,
                    })
                    .then((_) => nav.pop(true))
                    .catchError((e) => nav.pop(e));
              },
      ),
    ],
  );
}

enum AchievementApprovalStatus {
  approved(Colors.green),
  rejected(Colors.red),
  pending(Colors.grey);

  final Color color;
  const AchievementApprovalStatus(this.color);

  static final sqlValues = <bool?, AchievementApprovalStatus>{
    true: approved,
    false: rejected,
    null: pending,
  };
  factory AchievementApprovalStatus.fromSqlValue(bool? sqlValue) => sqlValues[sqlValue]!;
}

typedef AchPlusApproval = ({
  Achievement achievement,
  AchievementApprovalStatus? approved,
  String? details,
});
