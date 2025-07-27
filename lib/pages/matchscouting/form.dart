import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/supabase.dart' show SupabaseInterface;
import 'package:birdseye/types.dart';
import 'package:birdseye/utils.dart';
import 'package:flutter/material.dart';

part 'components.dart';

class MatchScoutForm extends StatelessWidget {
  final Map<String, dynamic> _fields = {};
  MatchScoutForm(this.season, {this.reset, required this.submit, super.key});
  final Future Function()? reset;
  final Future Function(Map<String, dynamic> fields) submit;
  final int season;

  @override
  Widget build(BuildContext context) => Form(
    child: SensibleFutureBuilder(
      future: SupabaseInterface.matchscoutStock.get(season),
      builder: (context, data) => CustomScrollView(
        cacheExtent: double.infinity,
        slivers: [
          SliverCenteredConstrainedCrossAxis(
            maxExtent: 500,
            sliver: SliverMainAxisGroup(
              slivers: [
                for (var MapEntry(key: section, value: contents) in data.entries) ...[
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
                      children: contents.entries.map((e) {
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
                      }).toList(),
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
        ],
      ),
    ),
  );
}
