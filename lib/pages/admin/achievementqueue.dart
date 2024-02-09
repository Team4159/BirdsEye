import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pages/metadata.dart';

class AchievementQueuePage extends StatelessWidget {
  final UniqueNotifyingList<
      ({
        int achid,
        String achname,
        String achdesc,
        String achreqs,
        String userid,
        String user,
        int season,
        String event,
        String details,
        NetworkImage? image
      })> _items = UniqueNotifyingList();
  AchievementQueuePage({super.key}) {
    _fetch();
  }

  Future<void> _fetch() => Supabase.instance.client
      .from("achievement_queue")
      .select(
          'achievements(id, name, description, requirements), season, event, users!inner(id, name, team), details, approved')
      .eq('users.team', UserMetadata.instance.team!)
      .isFilter('approved', null)
      .limit(30)
      .withConverter((resp) => LinkedHashSet.of(resp.map((record) => (
            achid: record["achievements"]["id"] as int,
            achname: record["achievements"]["name"] as String,
            achdesc: record["achievements"]["description"] as String,
            achreqs: record["achievements"]["requirements"] as String,
            userid: record["users"]["id"] as String,
            user: record["users"]["name"] as String,
            season: record['season'] as int,
            event: record['event'] as String,
            details: (record["details"] as String).trim(),
            image: record["image"] == null ? null : NetworkImage(record["image"])
          ))))
      .then((items) => _items.setAll(items));

  Future<void> _update(int achievementid, String userid, int season, String event, bool approved) =>
      Supabase.instance.client
          .from("achievement_queue")
          .update({"approved": approved})
          .eq('achievement', achievementid)
          .eq("user", userid)
          .eq("season", season)
          .eq("event", event)
          .then((_) {});

  @override
  Widget build(BuildContext context) => NestedScrollView(
      headerSliverBuilder: (context, _) => [
            SliverAppBar(
              primary: true,
              floating: true,
              snap: true,
              title: const Text("Achievement Queue"),
              actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch)],
            ),
          ],
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: _fetch,
              child: ListenableBuilder(
                  listenable: _items,
                  builder: (context, child) => _items.isEmpty
                      ? Center(
                          child: Text("No pending achievements for your team!",
                              style: Theme.of(context).textTheme.titleMedium))
                      : ListView.builder(
                          primary: false,
                          physics:
                              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            var e = _items[i];
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
                                          child: Image(
                                            image: e.image!,
                                            isAntiAlias: false,
                                          ),
                                          onTap: () => showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                  child: Image(
                                                      image: e.image!,
                                                      filterQuality: FilterQuality.medium))),
                                        )),
                                controlAffinity: ListTileControlAffinity.trailing,
                                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                childrenPadding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                maintainState: true,
                                children: [
                                  ListTile(
                                      leading: const Icon(Icons.checklist_rounded),
                                      title: Text(e.achdesc),
                                      subtitle: Text(e.achreqs),
                                      dense: true),
                                  ListTile(
                                    leading: const Icon(Icons.person_search_rounded),
                                    title: const Text("User Description"),
                                    subtitle: Text(e.details, softWrap: true),
                                    dense: true,
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton.filledTonal(
                                              onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                          title: const Text("Reject Achievement?"),
                                                          actions: [
                                                            OutlinedButton(
                                                                onPressed: () =>
                                                                    GoRouter.of(context).pop(),
                                                                child: const Text("Cancel")),
                                                            FilledButton(
                                                                onPressed: () => _update(
                                                                            e.achid,
                                                                            e.userid,
                                                                            e.season,
                                                                            e.event,
                                                                            false)
                                                                        .then((_) {
                                                                      GoRouter.of(context).pop();
                                                                      _items.remove(e);
                                                                    }).catchError((e) {
                                                                      ScaffoldMessenger.of(context)
                                                                          .showSnackBar(SnackBar(
                                                                              content: Text(
                                                                                  e.toString())));
                                                                    }),
                                                                child: const Text("Confirm"))
                                                          ])),
                                              icon: const Icon(Icons.close_rounded),
                                              style: ButtonStyle(
                                                  backgroundColor: MaterialStatePropertyAll(
                                                      Colors.red[isDarkMode ? 700 : 300]))),
                                          const SizedBox(width: 8),
                                          IconButton.filledTonal(
                                            onPressed: () => showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                        title: const Text("Approve Achievement?"),
                                                        actions: [
                                                          OutlinedButton(
                                                              onPressed: () =>
                                                                  GoRouter.of(context).pop(),
                                                              child: const Text("Cancel")),
                                                          FilledButton(
                                                              onPressed: () => _update(
                                                                          e.achid,
                                                                          e.userid,
                                                                          e.season,
                                                                          e.event,
                                                                          true)
                                                                      .then((_) {
                                                                    GoRouter.of(context).pop();
                                                                    _items.remove(e);
                                                                  }).catchError((e) {
                                                                    ScaffoldMessenger.of(context)
                                                                        .showSnackBar(SnackBar(
                                                                            content: Text(
                                                                                e.toString())));
                                                                  }),
                                                              child: const Text("Confirm"))
                                                        ])),
                                            icon: const Icon(Icons.check_rounded),
                                            style: ButtonStyle(
                                                backgroundColor: MaterialStatePropertyAll(
                                                    Colors.green[isDarkMode ? 700 : 300])),
                                          )
                                        ]),
                                  )
                                ]);
                          })))));
}

class UniqueNotifyingList<E> extends ChangeNotifier {
  LinkedHashSet<E> _internal = LinkedHashSet.identity();

  void setAll(Set<E> items) {
    _internal = items is LinkedHashSet<E> ? items : LinkedHashSet<E>.of(items);
    notifyListeners();
  }

  bool remove(E item) {
    if (_internal.remove(item)) {
      notifyListeners();
      return true;
    }
    return false;
  }

  E operator [](int i) => _internal.elementAt(i);
  get length => _internal.length;
  get isEmpty => _internal.isEmpty;
}
