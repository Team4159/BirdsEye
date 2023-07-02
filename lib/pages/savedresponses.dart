import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';

import './matchscout.dart' as matchscout;
import './pitscout.dart' as pitscout;
import '../interfaces/localstore.dart';

class SavedResponsesPage extends StatelessWidget {
  final _list = _WrappedList([]);
  SavedResponsesPage({super.key});

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
      child: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        const SliverAppBar(
            primary: true, pinned: true, title: Text("Saved Responses")),
        FutureBuilder(
            future: _list.sync(),
            builder: (context, snapshot) => !snapshot.hasData
                ? SliverToBoxAdapter(
                    child: snapshot.hasError
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Icon(Icons.warning_rounded,
                                    color: Colors.red[700], size: 50),
                                const SizedBox(height: 20),
                                Text(snapshot.error.toString())
                              ])
                        : const Center(child: CircularProgressIndicator()))
                : SliverPadding(
                    padding:
                        const EdgeInsets.only(left: 12, right: 12, top: 24),
                    sliver: _RespAnimList(snapshot.data!)))
      ]),
      onRefresh: () => _list.sync());
}

class _WrappedList {
  List<String> _list;
  _WrappedList(this._list);

  bool get isEmpty => _list.isEmpty;
  int get length => _list.length;
  String operator [](int index) => _list[index];

  Future<bool> remove(String id) =>
      LocalStoreInterface.remove(id).then((_) => _list.remove(id));

  Future<_WrappedList> sync() => Future.wait(
              {LocalStoreInterface.getMatches(), LocalStoreInterface.getPits()})
          .then((s) => s.reduce((a, b) => a.union(b)).toList())
          .then((value) {
        _list = value;
        return this;
      });
}

class _RespAnimList extends StatefulWidget {
  final _WrappedList dataList;
  const _RespAnimList(this.dataList);

  @override
  State<_RespAnimList> createState() => __RespAnimListState();
}

class __RespAnimListState extends State<_RespAnimList> {
  @override
  Widget build(BuildContext context) => widget.dataList.isEmpty
      ? const SliverFillRemaining(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Icon(Icons.article_outlined, size: 50, color: Colors.grey),
              Text("No Saved Responses", style: TextStyle(color: Colors.grey))
            ]))
      : SliverList.builder(
          itemCount: widget.dataList.length,
          itemBuilder: (context, i) {
            String id = widget.dataList[i];
            return SwipeActionCell(
                key: ValueKey(id),
                leadingActions: [
                  SwipeAction(
                      nestedAction: SwipeNestedAction(title: "Confirm"),
                      color: Colors.red,
                      widthSpace: 40,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onTap: (CompletionHandler handler) async {
                        await handler(true);
                        widget.dataList.remove(id);
                        setState(() {});
                      }),
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
                        Map<String, dynamic>? data =
                            await LocalStoreInterface.get(id);
                        if (data == null) return handler(false);
                        await Future.wait({
                          widget.dataList.remove(id),
                          handler(true),
                          (id.startsWith("match")
                              ? matchscout.submitInfo(data,
                                  season: data.remove('season'))
                              : id.startsWith("pit")
                                  ? pitscout.submitInfo(data,
                                      season: data.remove('season'))
                                  : throw Exception(
                                      "Invalid LocalStore ID: $id"))
                        });
                        await widget.dataList.sync();
                        setState(() {});
                      })
                ],
                child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: SizedBox(
                        height: 30,
                        child: Text(id,
                            style: Theme.of(context).textTheme.titleSmall,
                            textScaleFactor: 1.5))));
          });
}
