import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';
import '../pages/configuration.dart';

class AchievementsPage extends StatelessWidget {
  final TextEditingController _searchedText = TextEditingController();
  final ValueNotifier<Achievement?> _selectedAchievement = ValueNotifier(null);
  final TextEditingController _detailsController = TextEditingController();
  AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        AppBar(title: const Text("Achievements")),
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: _searchedText,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: "Search"))),
        FutureBuilder(
            future: SupabaseInterface
                .achievements, // , Supabase.instance.client.from("achievement_queue").select("*")]
            builder: (context, snapshot) => Column(children: [
                  ListenableBuilder(
                      listenable: _searchedText,
                      builder: (context, _) {
                        List<Achievement> data = snapshot.data == null
                            ? []
                            : snapshot.data!
                                .where((achievement) => achievement.name
                                    .toLowerCase()
                                    .contains(_searchedText.text.toLowerCase()))
                                .toList();
                        return CarouselSlider(
                          items: data.map((achievement) {
                            var autoscrollcontroller = ScrollController();
                            autoscrollcontroller.addListener(() => autoscrollcontroller.offset >=
                                    autoscrollcontroller.position.maxScrollExtent
                                ? autoscrollcontroller.jumpTo(0)
                                : autoscrollcontroller.position.pixels == 0
                                    ? autoscrollcontroller.animateTo(
                                        autoscrollcontroller.position.maxScrollExtent,
                                        duration: const Duration(seconds: 3),
                                        curve: Curves.linear)
                                    : null);
                            return Card(
                                surfaceTintColor: (achievement.season != null &&
                                            achievement.season != Configuration.instance.season) ||
                                        (achievement.event != null &&
                                            achievement.event != Configuration.event)
                                    ? Theme.of(context).colorScheme.surfaceVariant
                                    : null // TODO: yellow if awaiting approval, green if approved, red if rejected
                                ,
                                child: Padding(
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
                                                        child: Text(achievement.name,
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
                                                        child: Text("${achievement.points} pts",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .headlineSmall!
                                                                .copyWith(color: Colors.grey)))))
                                          ]),
                                          const SizedBox(height: 12),
                                          Expanded(
                                              child: SingleChildScrollView(
                                                  physics: const ClampingScrollPhysics(
                                                      parent: NeverScrollableScrollPhysics()),
                                                  controller: autoscrollcontroller,
                                                  child: Text(achievement.description,
                                                      style:
                                                          Theme.of(context).textTheme.bodyLarge)))
                                        ])));
                          }).toList(),
                          options: CarouselOptions(
                              viewportFraction: max(300 / MediaQuery.of(context).size.width, 0.6),
                              enlargeCenterPage: true,
                              enlargeFactor: 0.2,
                              height: 200,
                              enableInfiniteScroll: _searchedText.text.isEmpty,
                              onPageChanged: (i, _) {
                                if (_selectedAchievement.value?.id == data[i].id) return;
                                _detailsController.clear();
                                _selectedAchievement.value = data[i];
                              }),
                        );
                      }),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListenableBuilder(
                          listenable: _selectedAchievement,
                          builder: (context, _) {
                            if (_selectedAchievement.value == null) {
                              _selectedAchievement.value = snapshot.data?.first;
                              if (_selectedAchievement.value == null) return const SizedBox();
                            }
                            return Column(children: [
                              const SizedBox(height: 12),
                              Text(_selectedAchievement.value!.requirements,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(color: Colors.grey))
                            ]);
                          }))
                ])),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                    minLines: null,
                    maxLines: null,
                    maxLength: 250,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelText: "Details (Optional)",
                        border: OutlineInputBorder()),
                    controller: _detailsController))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file_rounded)),
              const Expanded(child: SizedBox()),
              FilledButton.icon(
                  onPressed: () {
                    if (_selectedAchievement.value == null) return;
                    Supabase.instance.client.from("achievement_queue").insert({
                      'achievement': _selectedAchievement.value!.id,
                      'details': _detailsController.text.isEmpty ? null : _detailsController.text,
                      'season': Configuration.instance.season,
                      'event': Configuration.event
                    }).then((_) {
                      _detailsController.clear();
                      // this needs to trigger a rebuild of the achievement list
                    }).catchError((e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    });
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("Submit"))
            ]))
      ]));
}
