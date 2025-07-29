import 'dart:math' show min;

import 'package:birdseye/interfaces/supabase.dart' show SupabaseInterface;
import 'package:birdseye/usermetadata.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:birdseye/util/common.dart' show ErrorReportingFuture;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementsPage extends StatelessWidget {
  final int season;
  final String event;
  AchievementsPage({super.key, required this.season, required this.event});

  final TextEditingController _searchedText = TextEditingController();

  Future<List<AchPlusApproval>> _reload(String id) async {
    final [achievements, queuedata] = await Future.wait([
      SupabaseInterface.achievements,
      _getQueueData(id),
    ]);
    achievements as Set<Achievement>?;
    queuedata as ({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details});
    return achievements
            ?.where(
              (ach) =>
                  (ach.season == null || ach.season == season) &&
                  (ach.event == null || ach.event == event),
            )
            .map(
              (ach) => (
                achievement: ach,
                approved: queuedata.approvals[ach.id],
                details: queuedata.details[ach.id],
              ),
            )
            .toList(growable: false) ??
        [];
  }

  Future<({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details})> _getQueueData(
    String id,
  ) => Supabase.instance.client
      .from("achievement_queue")
      .select("achievement, approved, details")
      .eq("user", id)
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
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, _) => const [
      SliverAppBar(primary: true, pinned: true, title: Text("Achievements")),
    ],
    body: SensibleFetcher<List<AchPlusApproval>>(
      getFuture: () => _reload(UserMetadata.of(context).id!),
      builtInRefresh: true,
      loadingIndicator: const CircularProgressIndicator(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchedText,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: "Search",
                ),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _searchedText,
            builder: (context, searchedText, _) => _AchievevmentsPageInternal(
              season: season,
              event: event,
              searchedText: searchedText.text,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AchievevmentsPageInternal extends StatelessWidget {
  final int season;
  final String event;
  final String searchedText;
  const _AchievevmentsPageInternal({
    this.searchedText = "",
    required this.season,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = SensibleFetcher.of<List<AchPlusApproval>>(context);

    List<AchPlusApproval> filteredData = snapshot.data!
        .where(
          (achievement) =>
              achievement.achievement.name.toLowerCase().contains(searchedText.toLowerCase()),
        )
        .toList(growable: false);

    if (filteredData.isEmpty) {
      return const Center(child: Text("No achievements found"));
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: CarouselSlider.builder(
          itemCount: filteredData.length,
          itemBuilder: (context, i, realIndex) => _AchievementCard(
            filteredData[i],
            refresh: snapshot.refresh,
            season: season,
            event: event,
          ),
          options: CarouselOptions(
            viewportFraction: min(0.8, 600 / constraints.crossAxisExtent),
            enlargeCenterPage: true,
            enlargeFactor: 0.2,
            height: min(
              300,
              constraints.viewportMainAxisExtent - constraints.precedingScrollExtent,
            ),
            enableInfiniteScroll: searchedText.isEmpty,
          ),
        ),
      ),
    );
  }
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
          mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: TextField(
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

                      /// Let the backend default the value to our id
                      'user': null,
                    })
                    .then((_) => nav.pop(true))
                    .onError((e, _) => nav.pop(e));
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

typedef Achievement = ({
  int id,
  String name,
  String description,
  String requirements,
  int points,
  int? season,
  String? event,
});

typedef AchPlusApproval = ({
  Achievement achievement,
  AchievementApprovalStatus? approved,
  String? details,
});
