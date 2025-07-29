import 'dart:collection' show LinkedHashMap;
import 'dart:math' show max;

import 'package:birdseye/interfaces/supabase.dart' show SupabaseInterface;
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:birdseye/util/common.dart';
import 'package:flutter/material.dart';

part 'components.dart';

class MatchScoutForm extends StatelessWidget {
  final int season;
  final Future Function(Map<String, dynamic> fields) submit;
  final Future Function()? reset;

  MatchScoutForm(this.season, {this.reset, required this.submit, super.key});

  final Map<String, dynamic> _fields = {};

  @override
  Widget build(BuildContext context) => SensibleFetcher<MatchScoutQuestionSchema>(
    getFuture: () => SupabaseInterface.matchSchemaStock.get(season),
    loadingIndicator: const CircularProgressIndicator(),
    child: Form(
      child: CustomScrollView(
        cacheExtent: double.infinity,
        slivers: [
          SliverCenteredConstrainedCrossAxis(
            maxExtent: 500,
            sliver: Builder(
              builder: (context) => SliverMainAxisGroup(
                slivers: [
                  for (var MapEntry(key: section, value: contents)
                      in SensibleFetcher.of<MatchScoutQuestionSchema>(context).data!.entries) ...[
                    SliverAppBar(
                      primary: false,
                      excludeHeaderSemantics: true,
                      automaticallyImplyLeading: false,
                      centerTitle: true,
                      stretch: false,
                      title: Text(
                        section,
                        style: Theme.of(context).textTheme.headlineLarge,
                        textScaler: const TextScaler.linear(1.5),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                      sliver: SliverGrid.count(
                        crossAxisCount: 2,
                        childAspectRatio: MediaQuery.of(context).size.width > 450 ? 3 : 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 12,
                        children: contents.entries
                            .map((e) {
                              final field = e.key;
                              final labelText = field
                                  .split("_")
                                  .map((s) => s[0].toUpperCase() + s.substring(1))
                                  .join(" ");
                              onSaved(i) => _fields["${section}_$field"] = i;
                              return switch (e.value) {
                                MatchScoutQuestionTypes.text => CustomTextFormField(
                                  labelText: labelText,
                                  onSaved: onSaved,
                                ),
                                MatchScoutQuestionTypes.counter => CounterFormField(
                                  labelText: labelText,
                                  onSaved: onSaved,
                                  season: season,
                                ),
                                MatchScoutQuestionTypes.slider => RatingFormField(
                                  labelText: labelText,
                                  onSaved: onSaved,
                                ),
                                MatchScoutQuestionTypes.toggle => ToggleFormField(
                                  labelText: labelText,
                                  onSaved: onSaved,
                                ),
                                MatchScoutQuestionTypes.error => Material(
                                  type: MaterialType.button,
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  child: Center(child: Text(field)),
                                ),
                              };
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final form = Form.of(context);
                                _fields.clear();
                                form.save();
                                await submit(_fields);
                                form.reset();
                              },
                              child: const Text("Submit"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DeleteConfirmation(
                            context: context,
                            reset: () {
                              Form.of(context).reset();
                              if (reset != null) reset!();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SliverCenteredConstrainedCrossAxis extends SliverLayoutBuilder {
  SliverCenteredConstrainedCrossAxis({required Widget sliver, required double maxExtent, super.key})
    : super(
        builder: (context, constraints) => SliverPadding(
          padding: EdgeInsets.only(left: max(0, (constraints.crossAxisExtent - maxExtent) / 2)),
          sliver: SliverConstrainedCrossAxis(maxExtent: maxExtent, sliver: sliver),
        ),
      );
}

typedef MatchScoutQuestionSchema =
    LinkedHashMap<String, LinkedHashMap<String, MatchScoutQuestionTypes>>;
