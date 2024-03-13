import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';
import '../pages/configuration.dart';
import '../pages/metadata.dart';
import '../utils.dart';

Future<({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details})>
    _getQueueData() => Supabase.instance.client
        .from("achievement_queue")
        .select("achievement, approved, details")
        .eq("user", UserMetadata.instance.id!)
        .eq("season", Configuration.instance.season)
        .eq("event", Configuration.event!)
        .withConverter((resp) => (
              approvals: Map.fromEntries(resp.map((record) => MapEntry(
                  record["achievement"] as int,
                  {
                    null: AchievementApprovalStatus.pending,
                    true: AchievementApprovalStatus.approved,
                    false: AchievementApprovalStatus.rejected
                  }[record["approved"] as bool?]!))),
              details: Map.fromEntries(resp.where((r) => r["details"] != null).map(
                  (record) => MapEntry(record["achievement"] as int, record["details"] as String)))
            ));

class AchievementsPage extends StatelessWidget {
  final NotifiableTextEditingController _searchedText = NotifiableTextEditingController();
  final LateValueNotifier<AchPlusApproval> _selectedAchievement = LateValueNotifier();
  final TextEditingController _detailsController = TextEditingController();
  AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        AppBar(title: const Text("Achievements")),
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: _searchedText,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: "Search"))),
        Expanded(
            child: FutureBuilder(
                future:
                    Future.wait([SupabaseInterface.achievements, _getQueueData()]).then((results) {
                  var queuedata = results[1] as ({
                    Map<int, AchievementApprovalStatus> approvals,
                    Map<int, String> details
                  });
                  return (results[0] as Set<Achievement>?)
                      ?.where((ach) =>
                          (ach.season == null || ach.season == Configuration.instance.season) &&
                          (ach.event == null || ach.event == Configuration.event!))
                      .map((ach) {
                    var r = (
                      achievement: ach,
                      approved: queuedata.approvals[ach.id],
                      details: queuedata.details[ach.id]
                    );
                    if (!_selectedAchievement.isInitialized) _selectedAchievement.value = r;
                    return r;
                  });
                }),
                builder: (context, snapshot) => Column(children: [
                      !snapshot.hasData
                          ? const SizedBox(
                              height: 200, child: Center(child: CircularProgressIndicator()))
                          : ListenableBuilder(
                              listenable: _searchedText,
                              builder: (context, _) {
                                List<AchPlusApproval> data = snapshot.data == null
                                    ? []
                                    : snapshot.data!
                                        .where((achievement) => achievement.achievement.name
                                            .toLowerCase()
                                            .contains(_searchedText.text.toLowerCase()))
                                        .toList(growable: false);
                                return CarouselSlider(
                                  items: data.map((achdata) {
                                    var autoscrollcontroller = ScrollController();
                                    autoscrollcontroller.addListener(() =>
                                        autoscrollcontroller.offset >=
                                                autoscrollcontroller.position.maxScrollExtent
                                            ? autoscrollcontroller.jumpTo(0)
                                            : autoscrollcontroller.position.pixels == 0
                                                ? autoscrollcontroller.animateTo(
                                                    autoscrollcontroller.position.maxScrollExtent,
                                                    duration: const Duration(seconds: 3),
                                                    curve: Curves.linear)
                                                : null);
                                    return Card(
                                        clipBehavior: Clip.hardEdge,
                                        child: Stack(fit: StackFit.expand, children: [
                                          if (achdata.approved != null)
                                            ColoredBox(
                                                color: {
                                              AchievementApprovalStatus.approved: Colors.green,
                                              AchievementApprovalStatus.rejected: Colors.red,
                                              AchievementApprovalStatus.pending: Colors.grey
                                            }[achdata.approved]!
                                                    .withAlpha(128)),
                                          Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(mainAxisSize: MainAxisSize.max, children: [
                                                      Flexible(
                                                          flex: 5,
                                                          fit: FlexFit.tight,
                                                          child: Align(
                                                              alignment: Alignment.centerLeft,
                                                              child: FittedBox(
                                                                  fit: BoxFit.scaleDown,
                                                                  child: Text(
                                                                      achdata.achievement.name,
                                                                      style: Theme.of(context)
                                                                          .textTheme
                                                                          .headlineMedium)))),
                                                      const Flexible(
                                                          flex: 1,
                                                          fit: FlexFit.tight,
                                                          child: SizedBox()),
                                                      Flexible(
                                                          flex: 2,
                                                          fit: FlexFit.tight,
                                                          child: Align(
                                                              alignment: Alignment.centerRight,
                                                              child: FittedBox(
                                                                  child: Text(
                                                                      "${achdata.achievement.points} pts",
                                                                      style: Theme.of(context)
                                                                          .textTheme
                                                                          .headlineSmall!
                                                                          .copyWith(
                                                                              color:
                                                                                  Colors.grey)))))
                                                    ]),
                                                    const SizedBox(height: 12),
                                                    Expanded(
                                                        child: SingleChildScrollView(
                                                            physics: const ClampingScrollPhysics(
                                                                parent:
                                                                    NeverScrollableScrollPhysics()),
                                                            controller: autoscrollcontroller,
                                                            child: Text(
                                                                achdata.achievement.description,
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyLarge)))
                                                  ]))
                                        ]));
                                  }).toList(growable: false),
                                  options: CarouselOptions(
                                      viewportFraction:
                                          max(300 / MediaQuery.of(context).size.width, 0.6),
                                      enlargeCenterPage: true,
                                      enlargeFactor: 0.2,
                                      height: 200,
                                      enableInfiniteScroll: _searchedText.text.isEmpty,
                                      onPageChanged: (i, _) {
                                        if (_selectedAchievement.value.achievement.id ==
                                            data[i].achievement.id) {
                                          return;
                                        }
                                        _detailsController.text = data[i].details ?? "";
                                        _selectedAchievement.value = data[i];
                                      }),
                                );
                              }),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ListenableBuilder(
                              listenable: _selectedAchievement,
                              builder: (context, _) {
                                if (!_selectedAchievement.isInitialized) return const SizedBox();
                                return Column(children: [
                                  const SizedBox(height: 12),
                                  Text(_selectedAchievement.value.achievement.requirements,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.grey))
                                ]);
                              })),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: ListenableBuilder(
                                  listenable: _selectedAchievement,
                                  builder: (context, _) => TextField(
                                      readOnly: !_selectedAchievement.isInitialized ||
                                          _selectedAchievement.value.approved != null,
                                      minLines: null,
                                      maxLines: null,
                                      maxLength: 250,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: const InputDecoration(
                                          floatingLabelBehavior: FloatingLabelBehavior.always,
                                          labelText: "Details (Optional)",
                                          border: OutlineInputBorder()),
                                      controller: _detailsController)))),
                      SafeArea(
                          minimum: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                          child: Row(children: [
                            IconButton(
                                onPressed: () {}, icon: const Icon(Icons.attach_file_rounded)),
                            const Expanded(child: SizedBox()),
                            ListenableBuilder(
                                listenable: _selectedAchievement,
                                builder: (context, _) => FilledButton.icon(
                                    onPressed: !_selectedAchievement.isInitialized ||
                                            _selectedAchievement.value.approved != null
                                        ? null
                                        : () {
                                            Supabase.instance.client
                                                .from("achievement_queue")
                                                .insert({
                                              'achievement':
                                                  _selectedAchievement.value.achievement.id,
                                              'details': _detailsController.text.isEmpty
                                                  ? null
                                                  : _detailsController.text,
                                              'season': Configuration.instance.season,
                                              'event': Configuration.event
                                            }).then((_) {
                                              _detailsController.clear();
                                              _searchedText.notifyListeners();
                                            }).catchError((e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())));
                                            });
                                          },
                                    icon: const Icon(Icons.send_rounded),
                                    label: const Text("Submit")))
                          ]))
                    ]))),
      ]);
}

enum AchievementApprovalStatus { approved, rejected, pending }

typedef AchPlusApproval = ({
  Achievement achievement,
  AchievementApprovalStatus? approved,
  String? details
});
