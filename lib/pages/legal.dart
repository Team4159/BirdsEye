import 'package:birdseye/main.dart';
import 'package:flutter/material.dart';
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

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) => const Text.rich(TextSpan(
      text:
          """we collect data to ensure data integrity and application security
we do not sell data
email dev@team4159.org to request deletion, all data will be removed within 10 business days 
we collect data you provide: name, email, frc team number
we use cookies for authentication and caching but not tracking
we retain data as long as needed to provide our services
any changes to the policy will have 30 days' notice by email"""));
}

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) => const Text.rich(TextSpan(text: "be good"));
}
