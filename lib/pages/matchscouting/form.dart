import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/supabase.dart' show SupabaseInterface;
import 'package:birdseye/types.dart';
import 'package:birdseye/utils.dart';
import 'package:flutter/material.dart';

part 'components.dart';

class MatchScoutForm extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final Map<String, dynamic> _fields = {};
  final ScrollController _scrollController = ScrollController();
  MatchScoutForm(this.season, {this.reset, required this.submit, super.key});
  final Future Function()? reset;
  final Future Function(Map<String, dynamic> fields) submit;
  final int season;

  @override
  Widget build(BuildContext context) => SensibleFutureBuilder(
      future: SupabaseInterface.matchscoutStock.get(season),
      builder: (context, snapshot) => CustomScrollView(cacheExtent: double.infinity, slivers: [
              SliverCrossAxisGroup(slivers: [
                SliverFillRemaining(hasScrollBody: false),
                SliverConstrainedCrossAxis(
                    maxExtent: 500,
                    sliver: Form(
                        key: _formKey,
                        child: SliverMainAxisGroup(slivers: [
                          for (var MapEntry(key: section, value: contents)
                              in snapshot.data!.entries) ...[
                            SliverAppBar(
                                primary: false,
                                excludeHeaderSemantics: true,
                                automaticallyImplyLeading: false,
                                centerTitle: true,
                                stretch: false,
                                title: Text(section,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                    textScaler: const TextScaler.linear(1.5))),
                            SliverPadding(
                                padding: const EdgeInsets.only(
                                    bottom: 12, left: 6, right: 6),
                                sliver: SliverGrid.count(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        MediaQuery.of(context).size.width > 450
                                            ? 3
                                            : 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 12,
                                    children: [
                                      for (var MapEntry(key: field, value: type)
                                          in contents.entries)
                                        switch (type) {
                                          MatchScoutQuestionTypes.text =>
                                            CustomTextFormField(
                                              labelText: field
                                                  .split("_")
                                                  .map((s) =>
                                                      s[0].toUpperCase() +
                                                      s.substring(1))
                                                  .join(" "),
                                              onSaved: (i) =>
                                                  _fields["${section}_$field"] =
                                                      i,
                                            ),
                                          MatchScoutQuestionTypes.counter =>
                                            CounterFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) =>
                                                        s[0].toUpperCase() +
                                                        s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields[
                                                    "${section}_$field"] = i,
                                                season: season),
                                          MatchScoutQuestionTypes.slider =>
                                            RatingFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) =>
                                                        s[0].toUpperCase() +
                                                        s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields[
                                                    "${section}_$field"] = i),
                                          MatchScoutQuestionTypes.toggle =>
                                            ToggleFormField(
                                                labelText: field
                                                    .split("_")
                                                    .map((s) =>
                                                        s[0].toUpperCase() +
                                                        s.substring(1))
                                                    .join(" "),
                                                onSaved: (i) => _fields[
                                                    "${section}_$field"] = i),
                                          MatchScoutQuestionTypes.error =>
                                            Material(
                                                type: MaterialType.button,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .errorContainer,
                                                child:
                                                    Center(child: Text(field)))
                                        }
                                    ])),
                            SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverToBoxAdapter(
                                    child: Row(children: [
                                  Expanded(
                                      child: FilledButton(
                                          onPressed: () async {
                                            _fields.clear();
                                            _formKey.currentState!.save();
                                            await submit(_fields);
                                            _formKey.currentState!.reset();
                                            await _scrollController.animateTo(0,
                                                duration:
                                                    const Duration(seconds: 1),
                                                curve: Curves.easeOutBack);
                                          },
                                          child: const Text("Submit"))),
                                  const SizedBox(width: 10),
                                  DeleteConfirmation(
                                      context: context,
                                      reset: () async {
                                        _formKey.currentState!.reset();
                                        if (reset != null) await reset!();
                                        await _scrollController.animateTo(0,
                                            duration: const Duration(
                                                milliseconds: 1500),
                                            curve: Curves.easeOutBack);
                                      })
                                ])))
                          ]
                        ])))
              ])
            ]));
}
