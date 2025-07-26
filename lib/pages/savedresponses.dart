import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';

import '../interfaces/localstore.dart';
import '../interfaces/mixed.dart';

class SavedResponsesPage extends StatefulWidget {
  const SavedResponsesPage({super.key});

  @override
  State<StatefulWidget> createState() => _SavedResponsesPageState();
}

class _SavedResponsesPageState extends State<SavedResponsesPage> {
  List<String>? _values;
  Object? _error;

  @override
  void initState() {
    reload();
    super.initState();
  }

  Future<void> reload() => LocalStoreInterface.getAll
      .then((v) => setState(() => _values = v.toList()))
      .catchError((e) => setState(() => _error = e));

  @override
  Widget build(BuildContext context) {
    remove(String id) => LocalStoreInterface.remove(id).then((_) => reload());

    return RefreshIndicator.adaptive(
        onRefresh: reload,
        child: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          const SliverAppBar(pinned: true, title: Text("Saved Responses")),
          SliverSafeArea(
              sliver: _values != null && _values!.isNotEmpty
                  ? SliverPadding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 24),
                      sliver: SliverList.builder(
                          itemCount: _values!.length,
                          itemBuilder: (context, i) {
                            String id = _values![i];
                            return SwipeActionCell(
                                key: ValueKey(id),
                                leadingActions: [
                                  SwipeAction(
                                      nestedAction: SwipeNestedAction(title: "Confirm"),
                                      color: Colors.red,
                                      widthSpace: 40,
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onTap: (handler) => remove(id).then((_) => handler(true))),
                                  SwipeAction(
                                      color: Colors.grey,
                                      widthSpace: 60,
                                      title: "Cancel",
                                      onTap: (handler) => handler(false))
                                ],
                                trailingActions: [
                                  SwipeAction(
                                      color: Colors.blue,
                                      widthSpace: 60,
                                      icon: const Icon(Icons.send_rounded),
                                      performsFirstActionWithFullSwipe: true,
                                      onTap: (CompletionHandler handler) async {
                                        try {
                                          await _submit(id);
                                          await remove(id);
                                          handler(true);
                                        } catch (_) {
                                          handler(false);
                                        }
                                      })
                                ],
                                child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: SizedBox(
                                        height: 30,
                                        child: Text(id,
                                            style: Theme.of(context).textTheme.titleSmall,
                                            textScaler: const TextScaler.linear(1.5)))));
                          }))
                  : SliverToBoxAdapter(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          if (_error != null) ...[
                            Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                            const SizedBox(height: 20),
                            Text(_error.toString())
                          ] else if (_values != null && _values!.isEmpty) ...[
                            Icon(Icons.article_outlined, size: 50, color: Colors.grey),
                            Text("No Saved Responses", style: TextStyle(color: Colors.grey))
                          ] else
                            CircularProgressIndicator()
                        ])))
        ]));
  }

  Future<void> _submit(String id) => switch (id.split("-").first) {
        "pit" => LocalStoreInterface.getPit(id).then((resp) {
            if (resp == null) return Future.error(Exception("Failed to Fetch"));
            return MixedInterfaces.submitPitResponse(resp.key, resp.data);
          }),
        "match" => LocalStoreInterface.getMatch(id).then((resp) {
            if (resp == null) return Future.error(Exception("Failed to Fetch"));
            return MixedInterfaces.submitMatchResponse(resp.key, resp.data);
          }),
        _ => Future.error(Exception("Invalid LocalStore ID: $id"))
      };
}
