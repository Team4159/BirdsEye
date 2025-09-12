import 'dart:collection';

import 'package:birdseye/usermetadata.dart' show UserMetadata;
import 'package:birdseye/util/common.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementQueuePage extends StatelessWidget {
  const AchievementQueuePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(primary: true, title: const Text("Achievement Queue")),

    body: SensibleFetcher<LinkedHashSet<AchievementApplication>>(
      getFuture: () => Supabase.instance.client
          .from("achievement_queue")
          .select(
            'achievements(id, name, description, requirements), season, event, users!achievement_queue_user_fkey(id, name, team), details, approved',
          )
          .eq('users.team', UserMetadata.of(context).team!)
          .isFilter('approved', null)
          .limit(30)
          .withConverter(
            (resp) => LinkedHashSet.of(
              resp.map(
                (record) => (
                  achid: record["achievements"]["id"] as int,
                  achname: record["achievements"]["name"] as String,
                  achdesc: record["achievements"]["description"] as String,
                  achreqs: record["achievements"]["requirements"] as String,
                  userid: record["users"]["id"] as String,
                  user: record["users"]["name"] as String,
                  season: record['season'] as int,
                  event: record['event'] as String,
                  details: (record["details"] as String?)?.trim() ?? "",
                  image: record["image"] == null ? null : NetworkImage(record["image"]),
                ),
              ),
            ),
          ),
      builtInRefresh: true,
      loadingIndicator: const CircularProgressIndicator(),
      child: Builder(
        builder: (context) {
          final snapshot = SensibleFetcher.of<LinkedHashSet<AchievementApplication>>(context).data!;
          if (snapshot.isEmpty) {
            return const CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 50, color: Colors.grey),
                      Text("No Queued Achievements", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            );
          }
          return _AchievementQueueList(snapshot);
        },
      ),
    ),
  );
}

class _AchievementQueueList extends StatefulWidget {
  final LinkedHashSet<AchievementApplication> snapshot;
  const _AchievementQueueList(this.snapshot);

  @override
  State<StatefulWidget> createState() => _AchievementQueueListState();
}

class _AchievementQueueListState extends State<_AchievementQueueList> {
  static Future<void> _update(
    int achievementid,
    String userid,
    int season,
    String event,
    bool approved,
  ) => Supabase.instance.client
      .from("achievement_queue")
      .update({"approved": approved})
      .eq('achievement', achievementid)
      .eq("user", userid)
      .eq("season", season)
      .eq("event", event)
      .then((_) {});

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: widget.snapshot.length,
    itemBuilder: (context, i) {
      var e = widget.snapshot.elementAt(i);
      bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return ExpansionTile(
        key: ObjectKey(e),
        title: Text(e.achname),
        subtitle: Text("${e.user} @ ${e.season}${e.event}"),
        leading: e.image == null
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                clipBehavior: Clip.hardEdge,
                child: GestureDetector(
                  child: Image(image: e.image!, isAntiAlias: false),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Image(image: e.image!, filterQuality: FilterQuality.medium),
                    ),
                  ),
                ),
              ),
        controlAffinity: ListTileControlAffinity.trailing,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        maintainState: true,
        children: [
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: Text(e.achdesc),
            subtitle: Text(e.achreqs),
            dense: true,
          ),
          ListTile(
            leading: const Icon(Icons.person_search_rounded),
            title: const Text("User Description"),
            subtitle: Text(e.details, softWrap: true),
            dense: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                for (final approve in const [false, true])
                  IconButton.filledTonal(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: approve
                            ? const Text("Approve Achievement?")
                            : const Text("Reject Achievement?"),
                        actions: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                          FilledButton(
                            onPressed: () => _update(e.achid, e.userid, e.season, e.event, approve)
                                .then((_) {
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  setState(() => widget.snapshot.remove(e));
                                })
                                .reportError(context),
                            child: const Text("Confirm"),
                          ),
                        ],
                      ),
                    ),
                    icon: approve
                        ? const Icon(Icons.check_rounded)
                        : const Icon(Icons.close_rounded),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        (approve ? Colors.green : Colors.red)[isDarkMode ? 700 : 300],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

typedef AchievementApplication = ({
  int achid,
  String achname,
  String achdesc,
  String achreqs,
  String userid,
  String user,
  int season,
  String event,
  String details,
  NetworkImage? image,
});
