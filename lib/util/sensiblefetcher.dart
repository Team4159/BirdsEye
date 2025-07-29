import 'package:flutter/material.dart';

class SensibleFetcher<T extends Object> extends StatefulWidget {
  final Future<T> Function() getFuture;
  final Widget child;

  /// The loading indicator to display while waiting for data. A value of null will cause the child to be used during loading.
  final ProgressIndicator? loadingIndicator;

  /// Whether to wrap the child in a [RefreshIndicator] linked with the refresh function.
  final bool builtInRefresh;

  const SensibleFetcher({
    super.key,
    this.loadingIndicator,
    this.builtInRefresh = false,
    required this.getFuture,
    required this.child,
  });

  static SensibleFetcherResult<T> of<T>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<SensibleFetcherResult<T>>();

    if (widget == null) {
      throw FlutterError(
        'SensibleFetcher.of<$T>() was called with a context that does not contain a SensibleFetcherResult<$T> widget.\n'
        'The context used was:\n'
        '  $context',
      );
    }

    return widget;
  }

  @override
  State<SensibleFetcher> createState() => _SensibleFetcherState<T>();
}

class _SensibleFetcherState<T extends Object> extends State<SensibleFetcher<T>> {
  T? data;
  Object? error;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant SensibleFetcher<T> old) {
    super.didUpdateWidget(old);
    if (old.getFuture == widget.getFuture) return;
    _subscribe();
  }

  Future<void> _subscribe() => widget
      .getFuture()
      .then((value) {
        setState(() {
          data = value;
          error = null;
        });
      })
      .onError((err, stack) {
        setState(() {
          error = err;
        });
      });

  @override
  Widget build(BuildContext context) => SensibleFetcherResult<T>(
    data: data,
    error: error,
    refresh: _subscribe,
    child: () {
      if (error != null) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
            Text(error!.toString()),
          ],
        );
      }
      if (data == null && widget.loadingIndicator != null) {
        return Center(child: widget.loadingIndicator);
      }
      return widget.builtInRefresh
          ? RefreshIndicator(onRefresh: _subscribe, child: widget.child)
          : widget.child;
    }(),
  );
}

class SensibleFetcherResult<T> extends InheritedWidget {
  final T? data;
  final Object? error;
  final Future<void> Function() refresh;

  const SensibleFetcherResult({
    super.key,
    this.data,
    this.error,
    required this.refresh,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant SensibleFetcherResult<T> old) =>
      old.data != data || old.error != error;
}
