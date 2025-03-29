import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StatChartData {
  final String label;
  final double size;
  final String hoverLabel;
  final Color color;

  StatChartData(this.label, this.size, this.color, [String? tooltip])
      : hoverLabel = tooltip ?? size.toStringAsFixed(2);
}

class StatChart extends StatefulWidget {
  final num radius;
  final List<StatChartData> data;
  const StatChart(this.data, {super.key, required this.radius});

  @override
  State<StatefulWidget> createState() => _StatChartState();
}

class _StatChartState extends State<StatChart> {
  int? _touched;
  _StatChartState();

  @override
  build(BuildContext context) => PieChart(
      PieChartData(
          centerSpaceRadius: widget.radius * 0.7,
          sections: widget.data.indexed
              .map((e) => PieChartSectionData(
                  radius: widget.radius * 0.3,
                  title: e.$2.label,
                  color: e.$2.color,
                  value: e.$2.size,
                  showTitle: true,
                  titleStyle: Theme.of(context).textTheme.labelSmall,
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  badgeWidget: _touched != e.$1
                      ? null
                      : Card.filled(
                          child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                              child: Text(e.$2.hoverLabel)))))
              .toList(),
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (e, r) => r?.touchedSection?.touchedSectionIndex == _touched
                ? null
                : setState(() => _touched =
                    !e.isInterestedForInteractions ? null : r?.touchedSection?.touchedSectionIndex),
          )),
      duration: Durations.extralong3,
      curve: Curves.easeInSine);
}
