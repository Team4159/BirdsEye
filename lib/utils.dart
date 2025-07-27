import 'dart:math' show max;

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class DeleteConfirmation extends IconButton {
  DeleteConfirmation({
    super.key,
    required void Function()? reset,
    required BuildContext context,
    String toConfirm = "reset",
  }) : super(
         icon: Icon(Icons.delete, color: Colors.red[800]),
         tooltip: toConfirm,
         onPressed: reset == null
             ? null
             : () => showDialog(
                 context: context,
                 builder: (BuildContext context) => AlertDialog(
                   title: Text("Confirm ${toConfirm[0].toUpperCase()}${toConfirm.substring(1)}"),
                   content: Text("Are you sure you want to $toConfirm?"),
                   actions: [
                     OutlinedButton(
                       onPressed: () => GoRouter.of(context).pop(),
                       child: const Text("Cancel"),
                     ),
                     FilledButton(
                       onPressed: () {
                         GoRouter.of(context).pop();
                         reset();
                       },
                       child: const Text("Confirm"),
                     ),
                   ],
                 ),
               ),
       );
}

extension ErrorReportingFuture<T> on Future<T> {
  Future<T> reportError(BuildContext context, {bool stillThrow = false}) => catchError((e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    if (stillThrow) throw e;
  });

  Future<T?> get nullifyErrors => catchError(() => null);
}

extension GrayLuminance on Color {
  /// A crappy approximation for a real luminance value, much faster.
  double get grayLuminance => (r + g + b) / 3;
}

class NotifiableChangeNotifier extends ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

class SensibleDropdown<T> extends StatefulWidget {
  final String? label;
  final double? width;

  final List<T>? values;
  final T? initial;
  final void Function(T?)? onChanged;
  final DropdownMenuItem<T> Function(T value)? itemBuilder;
  const SensibleDropdown(
    this.values, {
    super.key,
    this.width,
    this.label,
    this.initial,
    this.onChanged,
    this.itemBuilder,
  });

  @override
  State<StatefulWidget> createState() => SensibleDropdownState<T>();
}

class SensibleDropdownState<T> extends State<SensibleDropdown<T>> {
  T? value;

  @override
  void initState() {
    value = widget.initial;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SensibleDropdown<T> oldWidget) {
    value = widget.initial;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) => ButtonTheme(
    alignedDropdown: true,
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 60,
      child: DropdownButton<T?>(
        alignment: Alignment.bottomRight,
        menuWidth: widget.width,
        padding: const EdgeInsets.all(0),
        borderRadius: BorderRadius.circular(4),
        focusColor: Colors.transparent,
        isExpanded: false,
        hint: widget.label == null ? null : Text(widget.label!),
        value: widget.values == null ? null : value,
        items: widget.values == null
            ? null
            : [
                const DropdownMenuItem(value: null, child: SizedBox()),
                for (final v in widget.values!)
                  (widget.itemBuilder == null
                      ? DropdownMenuItem(
                          value: v,
                          alignment: Alignment.center,
                          child: Text(v.toString(), overflow: TextOverflow.ellipsis),
                        )
                      : widget.itemBuilder!(v)),
              ],
        onChanged: (v) {
          setState(() => value = v);
          if (widget.onChanged != null) widget.onChanged!(v);
        },
      ),
    ),
  );
}

class SensibleFutureBuilder<T> extends FutureBuilder<T> {
  SensibleFutureBuilder({
    super.key,
    required super.future,
    required Widget Function(BuildContext context, T data) builder,
    ProgressIndicator progressIndicator = const CircularProgressIndicator(),
  }) : super(
         builder: (context, snapshot) {
           if (snapshot.hasError) {
             return Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.center,
               children: [
                 Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                 Text(snapshot.error?.toString() ?? "No Data"),
               ],
             );
           }
           if (!snapshot.hasData) return Center(child: progressIndicator);
           return builder(context, snapshot.data as T);
         },
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
