import 'package:birdseye/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

class LegalShell extends StatelessWidget {
  final Widget child;
  const LegalShell(this.child, {super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
        floatingActionButton: IconButton.filledTonal(
            onPressed: () => GoRouter.of(context).canPop()
                ? GoRouter.of(context).pop()
                : GoRouter.of(context).goNamed(RoutePaths.landing.name),
            icon: const Icon(Icons.arrow_back_rounded)),
      ));
}

class MarkdownWidget extends StatelessWidget {
  final String file;
  const MarkdownWidget(this.file, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: DefaultAssetBundle.of(context).loadString("assets/documents/$file.md"),
      builder: ((context, snapshot) => !snapshot.hasData
          ? const Center(child: CircularProgressIndicator())
          : Markdown(data: snapshot.data!, selectable: true)));
}
