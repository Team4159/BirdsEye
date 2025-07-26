import 'package:birdseye/routing.dart';
import 'package:birdseye/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/widget/markdown.dart';

class LegalShell extends StatelessWidget {
  final Widget child;
  const LegalShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(minimum: const EdgeInsets.all(16), child: child),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
        floatingActionButton: IconButton.filledTonal(
            onPressed: () => GoRouter.of(context).canPop()
                ? GoRouter.of(context).pop()
                : const LandingRoute().go(context),
            icon: const Icon(Icons.arrow_back_rounded)),
      );
}

class MarkdownPage extends StatelessWidget {
  final String file;
  const MarkdownPage(this.file, {super.key});

  @override
  Widget build(BuildContext context) => SensibleFutureBuilder(
      future: DefaultAssetBundle.of(context).loadString("assets/documents/$file.md"),
      builder: (context, snapshot) => MarkdownWidget(data: snapshot.data!));
}
