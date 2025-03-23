import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/localstore.dart';
import '../interfaces/mixed.dart';
import '../interfaces/supabase.dart'; // solely for .clearAchievements
import '../pages/configuration.dart';
import '../utils.dart';

class SavedResponsesPage extends StatelessWidget {
  final _list = _WrappedList([]);
  SavedResponsesPage({super.key});

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
      child: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverAppBar(primary: true, pinned: true, title: const Text("Saved Responses"), actions: [
          Padding(
              padding: const EdgeInsets.all(8),
              child: FloatingActionButton.extended(
                  onPressed: () => showModalBottomSheet(
                      context: context,
                      constraints: BoxConstraints.loose(const Size.fromHeight(140)),
                      enableDrag: false,
                      builder: (context) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CacheAddWidget(),
                                const VerticalDivider(),
                                DeleteConfirmation(
                                    reset: () {
                                      SupabaseInterface.clearAchievements();
                                      SupabaseInterface.matchscoutStock.clearAll();
                                      PitInterface.pitscoutStock.clearAll();
                                      BlueAlliance.stockSoT.deleteAll();
                                    },
                                    context: context,
                                    toConfirm: "clear the cache")
                              ]))),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: const Text("Cache")))
        ]),
        SliverSafeArea(
            sliver: FutureBuilder(
                future: _list.sync(),
                builder: (context, snapshot) => !snapshot.hasData
                    ? SliverToBoxAdapter(
                        child: snapshot.hasError
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                                    const SizedBox(height: 20),
                                    Text(snapshot.error.toString())
                                  ])
                            : const Center(child: CircularProgressIndicator()))
                    : SliverPadding(
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 24),
                        sliver: _RespList(snapshot.data!))))
      ]),
      onRefresh: () => _list.sync());
}

class _WrappedList extends ChangeNotifier {
  List<String> _list;
  _WrappedList(this._list);

  bool get isEmpty => _list.isEmpty;
  int get length => _list.length;
  String operator [](int index) => _list[index];

  Future<bool> remove(String id, {bool dontUpdate = false}) =>
      LocalStoreInterface.remove(id).then((_) => _list.remove(id)).then((updated) {
        if (updated && !dontUpdate) notifyListeners();
        return updated;
      });

  Future<_WrappedList> sync() => LocalStoreInterface.getAll.then((value) {
        _list = value.toList();
        notifyListeners();
        return this;
      });
}

class _RespList extends StatelessWidget {
  final _WrappedList dataList;
  const _RespList(this.dataList);

  @override
  Widget build(BuildContext context) => dataList.isEmpty
      ? const SliverFillRemaining(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Icon(Icons.article_outlined, size: 50, color: Colors.grey),
              Text("No Saved Responses", style: TextStyle(color: Colors.grey))
            ]))
      : ListenableBuilder(
          listenable: dataList,
          builder: (context, _) => SliverList.builder(
              itemCount: dataList.length,
              itemBuilder: (context, i) {
                String id = dataList[i];
                return SwipeActionCell(
                    key: ValueKey(id),
                    leadingActions: [
                      SwipeAction(
                          nestedAction: SwipeNestedAction(title: "Confirm"),
                          color: Colors.red,
                          widthSpace: 40,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onTap: (handler) => handler(true).then((_) => dataList.remove(id))),
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
                          onTap: (CompletionHandler handler) => Future.wait({
                                dataList.remove(id, dontUpdate: true),
                                handler(true),
                                switch (id.split("-").first) {
                                  "pit" => LocalStoreInterface.getPit(id).then((resp) {
                                      if (resp == null) return handler(false);
                                      MixedInterfaces.submitPitResponse(resp.key, resp.data);
                                    }),
                                  "match" => LocalStoreInterface.getMatch(id).then((resp) {
                                      if (resp == null) return handler(false);
                                      MixedInterfaces.submitMatchResponse(resp.key, resp.data);
                                    }),
                                  _ => throw Exception("Invalid LocalStore ID: $id")
                                }
                              }).then((_) => dataList.sync()))
                    ],
                    child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: SizedBox(
                            height: 30,
                            child: Text(id,
                                style: Theme.of(context).textTheme.titleSmall,
                                textScaler: const TextScaler.linear(1.5)))));
              }));
}

class CacheAddWidget extends StatelessWidget {
  final ValueNotifier<String?> _dropdownValue = ValueNotifier(Configuration.event);
  final ValueNotifier<String> _cacheStatus = ValueNotifier("Cache Event");
  CacheAddWidget({super.key});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListenableBuilder(
            listenable: _cacheStatus, builder: (context, _) => Text(_cacheStatus.value)),
        const SizedBox(height: 8),
        FutureBuilder(
            future: BlueAlliance.stock.get(TBAInfo(season: Configuration.instance.season)).then(
                (events) => events.keys
                    .map((eventcode) => DropdownMenuItem(value: eventcode, child: Text(eventcode)))
                    .toList(growable: false)),
            builder: (context, snapshot) => ListenableBuilder(
                listenable: _dropdownValue,
                builder: (context, _) => Row(children: [
                      DropdownButton<String>(
                          value: _dropdownValue.value,
                          items: snapshot.data,
                          onChanged: (val) => _dropdownValue.value = val),
                      IconButton(
                          icon: const Icon(Icons.add_box_rounded),
                          onPressed: !BlueAlliance.dirtyConnected ||
                                  _dropdownValue.value == null ||
                                  _cacheStatus.value != "Cache Event"
                              ? null
                              : () {
                                  String event = _dropdownValue.value!;
                                  _dropdownValue.value = null;
                                  _cacheStatus.value = "Fetching $event";
                                  BlueAlliance.batchFetch(Configuration.instance.season, event)
                                      .then((_) => _cacheStatus.value = "Cache Event")
                                      .catchError((e) => _cacheStatus.value = e.toString());
                                })
                    ])))
      ]);
}
