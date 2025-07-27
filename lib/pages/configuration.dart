import 'package:birdseye/interfaces/sharedprefs.dart';
import 'package:birdseye/utils.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/supabase.dart';

class ConfigurationPage extends StatelessWidget {
  final _eventCarouselController = CarouselSliderController();
  final _carouselProgress = BinaryValueNotifier(0);
  ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppBar(title: const Text("Configuration")),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height / 8),
        child: SensibleFutureBuilder(
          future: SupabaseInterface.getAvailableSeasons(),
          builder: (context, data) {
            int index = data.indexWhere((element) => element == SharedPreferencesInterface.season);
            if (index < 0) index = data.length - 1;
            if (data[index] != SharedPreferencesInterface.season) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => SharedPreferencesInterface.season = data[index],
              );
            }
            return Padding(
              padding: MediaQuery.of(context).size.height > 500
                  ? const EdgeInsets.only(top: 24, bottom: 12)
                  : EdgeInsets.zero,
              child: CarouselSlider(
                items: data
                    .map(
                      (year) =>
                          Text(year.toString(), style: Theme.of(context).textTheme.headlineMedium),
                    )
                    .toList(growable: false),
                options: CarouselOptions(
                  aspectRatio: 12 / 1,
                  viewportFraction: 1 / 3,
                  enableInfiniteScroll: false,
                  initialPage: index,
                  onScrolled: (n) => _carouselProgress.value = n == null ? 0 : n % 1,
                  onPageChanged: (i, _) => SharedPreferencesInterface.season = data[i],
                ),
              ),
            );
          },
          progressIndicator: const LinearProgressIndicator(),
        ),
      ),
      Expanded(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: SharedPreferencesInterface.seasonListenable,
            builder: (context, child) => SensibleFutureBuilder(
              future: BlueAlliance.stock.get(
                TBAInfo(season: SharedPreferencesInterface.season),
              ), // TODO implement pull-to-refresh for the tba event data
              builder: (context, data) {
                List<MapEntry<String, String>> entries = data.entries.toList(growable: false);
                if (entries.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.yellow[600], size: 50),
                      const SizedBox(height: 20),
                      const Text("No Events Found"),
                    ],
                  );
                }
                String maybeEvent =
                    SharedPreferencesInterface.event ??
                    entries[entries.length ~/ 2].key; // TODO autofill event goes here
                int index = entries.indexWhere((element) => element.key == maybeEvent);
                if (index < 0) index = entries.length ~/ 2;
                SharedPreferencesInterface.event = entries[index].key;
                return ValueListenableBuilder(
                  valueListenable: _carouselProgress,
                  builder: (context, prog, child) =>
                      AnimatedOpacity(opacity: 1 - prog, duration: Durations.short1, child: child),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      CarouselSlider(
                        carouselController: _eventCarouselController,
                        items: entries
                            .asMap()
                            .entries
                            .map(
                              (enumeratedEntry) => ListTile(
                                visualDensity: VisualDensity.adaptivePlatformDensity,
                                title: Text(
                                  enumeratedEntry.value.value,
                                  overflow: kIsWeb ? TextOverflow.ellipsis : TextOverflow.fade,
                                  softWrap: false,
                                  maxLines: 1,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                                ),
                                trailing: IntrinsicWidth(
                                  child: Text(
                                    enumeratedEntry.value.key,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                onTap: () => _eventCarouselController
                                    .animateToPage(enumeratedEntry.key, curve: Curves.easeOutQuart)
                                    .then(
                                      (_) => BlueAlliance.batchFetch(
                                        SharedPreferencesInterface.season,
                                        enumeratedEntry.value.key,
                                      ),
                                    ),
                              ),
                            )
                            .toList(growable: false),
                        options: CarouselOptions(
                          enableInfiniteScroll: false,
                          aspectRatio: 1 / 5,
                          viewportFraction: 40 / (MediaQuery.of(context).size.height * 7 / 8),
                          scrollDirection: Axis.vertical,
                          initialPage: index,
                          onPageChanged: (i, _) =>
                              SharedPreferencesInterface.event = entries[i].key,
                        ),
                      ),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          child: IgnorePointer(
                            child: Container(
                              height: 35,
                              margin: const EdgeInsets.only(top: 12),
                              color: Colors.grey.withAlpha(100),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

/// A [ChangeNotifier] that holds a single double value.
///
/// When [value] is replaced with something that is not equal to the old
/// value as evaluated by the equality operator == and switches between
/// zero and nonzero, this class notifies its listeners.
@Deprecated('Unpragmatic. Bad UI')
class BinaryValueNotifier extends ChangeNotifier implements ValueListenable<double> {
  /// Creates a [ChangeNotifier] that wraps this value.
  BinaryValueNotifier(this._value) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced with something that is not equal to the old
  /// value as evaluated by the equality operator ==, this class notifies its
  /// listeners.
  @override
  double get value => _value;
  double _value;
  set value(double newValue) {
    if (_value == newValue) return;
    double oldValue = _value;
    _value = newValue;
    if (oldValue == 0 || newValue == 0) notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';
}
