import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:birdseye/interfaces/sharedprefs.dart';
import 'package:birdseye/interfaces/supabase.dart';
import 'package:birdseye/util/sensiblefetcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final _eventCarouselController = CarouselSliderController();
  final _carouselProgress = ValueNotifier(0.0);

  late final String? _oldEvent;

  @override
  void initState() {
    super.initState();
    _oldEvent = SharedPreferencesInterface.event;
  }

  @override
  void dispose() {
    _carouselProgress.dispose();
    final event = SharedPreferencesInterface.event;

    /// On exit, prefetch the information for the event if it's changed
    if (event != null && event != _oldEvent) {
      BlueAlliance.batchFetch(SharedPreferencesInterface.season, event);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppBar(title: Text("Configuration")),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height / 8),
        child: SensibleFetcher<List<int>>(
          getFuture: SupabaseInterface.getAvailableSeasons,
          loadingIndicator: const LinearProgressIndicator(),
          builtInRefresh: false,
          child: Builder(
            builder: (context) {
              final result = SensibleFetcher.of<List<int>>(context);
              if (result.data == null) return const SizedBox();

              final seasons = result.data!;
              int index = seasons.indexOf(SharedPreferencesInterface.season);
              if (index < 0) index = seasons.length - 1;

              /// Synchronize state
              if (SharedPreferencesInterface.season != seasons[index]) {
                SharedPreferencesInterface.season = seasons[index];
              }

              return Padding(
                padding: MediaQuery.of(context).size.height > 500
                    ? const EdgeInsets.only(top: 24, bottom: 12)
                    : EdgeInsets.zero,
                child: CarouselSlider(
                  items: seasons
                      .map(
                        (year) => Text(
                          year.toString(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      )
                      .toList(growable: false),
                  options: CarouselOptions(
                    aspectRatio: 12 / 1,
                    viewportFraction: 1 / 3,
                    enableInfiniteScroll: false,
                    initialPage: index,
                    onScrolled: (n) => _carouselProgress.value = n == null ? 0 : n % 1,
                    onPageChanged: (i, _) => SharedPreferencesInterface.season = seasons[i],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Expanded(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: SharedPreferencesInterface.seasonListenable,
            builder: (context, child) => SensibleFetcher<Map<String, String>>(
              getFuture: () =>
                  BlueAlliance.stock.get(TBAInfo(season: SharedPreferencesInterface.season)),
              // lowpriority rework ui & enable this
              builtInRefresh: false,
              loadingIndicator: const CircularProgressIndicator(),
              child: Builder(
                builder: (context) {
                  final snapshot = SensibleFetcher.of<Map<String, String>>(context);
                  if (snapshot.data!.isEmpty) {
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

                  final entries = snapshot.data!.entries.toList(growable: false);
                  String? currentEvent = SharedPreferencesInterface.event;
                  int index = currentEvent != null
                      ? entries.indexWhere((e) => e.key == currentEvent)
                      : -1;
                  if (index < 0) index = entries.length ~/ 2;

                  /// Synchronize state
                  if (SharedPreferencesInterface.event != entries[index].key) {
                    SharedPreferencesInterface.event = entries[index].key;
                  }

                  return ValueListenableBuilder<double>(
                    valueListenable: _carouselProgress,
                    builder: (context, prog, child) => AnimatedOpacity(
                      opacity: 1 - prog,
                      duration: Durations.short1,
                      child: child,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        CarouselSlider.builder(
                          carouselController: _eventCarouselController,
                          itemCount: entries.length,
                          itemBuilder: (context, index, _) {
                            final entry = entries[index];
                            return ListTile(
                              visualDensity: VisualDensity.adaptivePlatformDensity,
                              title: Text(
                                entry.value,
                                overflow: kIsWeb ? TextOverflow.ellipsis : TextOverflow.fade,
                                softWrap: false,
                                maxLines: 1,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                              ),
                              trailing: IntrinsicWidth(
                                child: Text(
                                  entry.key,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              onTap: () {
                                _eventCarouselController.animateToPage(
                                  index,
                                  curve: Curves.easeOutQuart,
                                );
                                SharedPreferencesInterface.event = entry.key;
                              },
                            );
                          },
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
      ),
    ],
  );
}
