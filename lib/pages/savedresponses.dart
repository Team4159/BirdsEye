import 'package:birdseye/interfaces/localstore.dart';
import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';

class SavedResponsesPage extends StatelessWidget {
  const SavedResponsesPage({super.key});

  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, _) => const [
      SliverAppBar(primary: true, pinned: true, title: Text("Saved Responses")),
    ],
    body: SensibleFetcher<List<String>>(
      getFuture: () => LocalStoreInterface.getAll.then((v) => v.toList()),
      builtInRefresh: true,
      loadingIndicator: const CircularProgressIndicator(),
      child: Builder(
        builder: (context) {
          final snapshot = SensibleFetcher.of<List<String>>(context);

          if (snapshot.data!.isEmpty) {
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
                      Text("No Saved Responses", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            );
          }

          Future<void> remove(String id) =>
              LocalStoreInterface.remove(id).then((_) => snapshot.refresh());

          return ListView.builder(
            itemCount: snapshot.data?.length ?? 0,
            itemBuilder: (context, i) {
              String id = snapshot.data![i];
              return SwipeActionCell(
                key: ValueKey(id),
                leadingActions: [
                  SwipeAction(
                    nestedAction: SwipeNestedAction(title: "Confirm"),
                    color: Colors.red,
                    widthSpace: 40,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onTap: (handler) => remove(id).then((_) => handler(true)),
                  ),
                  SwipeAction(
                    color: Colors.grey,
                    widthSpace: 60,
                    title: "Cancel",
                    onTap: (handler) => handler(false),
                  ),
                ],
                trailingActions: [
                  SwipeAction(
                    color: Colors.blue,
                    widthSpace: 60,
                    icon: const Icon(Icons.send_rounded),
                    performsFirstActionWithFullSwipe: true,
                    onTap: (handler) async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _submit(id);
                        await remove(id);
                        handler(true);
                      } catch (e) {
                        handler(false);
                        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: SizedBox(
                    height: 30,
                    child: Text(
                      id,
                      style: Theme.of(context).textTheme.titleSmall,
                      textScaler: const TextScaler.linear(1.5),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  static Future<void> _submit(String id) => switch (id.split("-").first) {
    "pit" => LocalStoreInterface.getPit(id).then((resp) {
      if (resp == null) return Future.error(Exception("Failed to Fetch"));
      return PitInterface.pitResponseSubmit(resp.key, resp.data);
    }),
    "match" => LocalStoreInterface.getMatch(id).then((resp) {
      if (resp == null) return Future.error(Exception("Failed to Fetch"));
      return SupabaseInterface.matchResponseSubmit(resp.key, resp.data);
    }),
    _ => Future.error(Exception("Invalid LocalStore ID: $id")),
  };
}
