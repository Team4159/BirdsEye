import 'dart:math';

import 'package:birdseye/pages/configuration.dart';

import '../types.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';
import '../pages/metadata.dart';
import '../utils.dart';

class AchievementsPage extends StatelessWidget {
  final NotifiableTextEditingController _searchedText = NotifiableTextEditingController();
  final LateValueNotifier<AchPlusApproval> _selectedAchievement = LateValueNotifier();
  final TextEditingController _detailsController = TextEditingController();
  final Future<List<AchPlusApproval>> _achievements;
  AchievementsPage({super.key, int? season, String? event})
      : _achievements = Future.wait([SupabaseInterface.achievements, _getQueueData(season, event)])
            .then((results) {
          final queuedata = results[1] as ({
            Map<int, AchievementApprovalStatus> approvals,
            Map<int, String> details
          });
          return (results[0] as Set<Achievement>?)
                  ?.where((ach) =>
                      (season == null || ach.season == null || ach.season == season) &&
                      (event == null || ach.event == null || ach.event == event))
                  .map((ach) => (
                        achievement: ach,
                        approved: queuedata.approvals[ach.id],
                        details: queuedata.details[ach.id]
                      ))
                  .toList() ??
              [];
        });

  static Future<({Map<int, AchievementApprovalStatus> approvals, Map<int, String> details})>
      _getQueueData(int? season, String? event) {
    var query = Supabase.instance.client
        .from("achievement_queue")
        .select("achievement, approved, details")
        .eq("user", UserMetadata.instance.id!);
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

  // fixme the on screen keyboard crunches the view too much and it hides the text box
  @override
  Widget build(BuildContext context) => Column(children: [
        AppBar(title: const Text("Achievements")),
        Expanded(
            child: FutureBuilder(future: _achievements.then((ach) {
          _selectedAchievement.value = ach.first;
          return ach;
        }), builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  const SizedBox(height: 20),
                  Text(snapshot.error.toString())
                ]);
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) {
            return Center(
                child: Text("No achievements available.",
                    style: Theme.of(context).textTheme.titleMedium));
          }
          return Column(children: [
            if (MediaQuery.of(context).size.height > 400)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                      controller: _searchedText,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: "Search"))),
            ListenableBuilder(
                listenable: _searchedText,
                builder: (context, _) {
                  List<AchPlusApproval> data = snapshot.data!
                      .where((achievement) => achievement.achievement.name
                          .toLowerCase()
                          .contains(_searchedText.text.toLowerCase()))
                      .toList(growable: false);
                  return CarouselSlider(
                    items: data
                        .map((achdata) => Card.filled(
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
                                                      child: Text(achdata.achievement.name,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .headlineMedium)))),
                                          const Flexible(
                                              flex: 1, fit: FlexFit.tight, child: SizedBox()),
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
                                                              .copyWith(color: Colors.grey)))))
                                        ]),
                                        const SizedBox(height: 12),
                                        Expanded(
                                            child: SingleChildScrollView(
                                                physics: const ClampingScrollPhysics(),
                                                child: Text(achdata.achievement.description,
                                                    style: Theme.of(context).textTheme.bodyLarge)))
                                      ]))
                            ])))
                        .toList(growable: false),
                    options: CarouselOptions(
                        viewportFraction: max(300 / MediaQuery.of(context).size.width, 0.6),
                        enlargeCenterPage: true,
                        enlargeFactor: 0.2,
                        height: min(MediaQuery.of(context).size.height / 3, 200),
                        enableInfiniteScroll: _searchedText.text.isEmpty,
                        onPageChanged: (i, _) {
                          if (_selectedAchievement.value.achievement.id == data[i].achievement.id) {
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
                      if (!_selectedAchievement.isInitialized) {
                        return const SizedBox();
                      }
                      return Column(children: [
                        const SizedBox(height: 12),
                        Text(_selectedAchievement.value.achievement.requirements,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey))
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
                  IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file_rounded)),
                  const Expanded(child: SizedBox()),
                  ListenableBuilder(
                      listenable: _selectedAchievement,
                      builder: (context, _) => FilledButton.icon(
                          onPressed: !_selectedAchievement.isInitialized ||
                                  _selectedAchievement.value.approved != null
                              ? null
                              : () {
                                  Supabase.instance.client.from("achievement_queue").insert({
                                    'achievement': _selectedAchievement.value.achievement.id,
                                    'details': _detailsController.text.isEmpty
                                        ? null
                                        : _detailsController.text,
                                    'season': Configuration.instance.season,
                                    'event': Configuration.event!
                                  }).then((_) {
                                    _detailsController.clear();
                                    _searchedText.notifyListeners();
                                    // should update card color
                                  }).reportError(context);
                                },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text("Submit")))
                ]))
          ]);
        })),
      ]);
}

enum AchievementApprovalStatus { approved, rejected, pending }

typedef AchPlusApproval = ({
  Achievement achievement,
  AchievementApprovalStatus? approved,
  String? details
});
