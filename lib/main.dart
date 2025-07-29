import 'package:birdseye/interfaces/sharedprefs.dart';
import 'package:birdseye/routing.dart' show appRouter;
import 'package:birdseye/usermetadata.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

const cardinalred = Color(0xffcf2e2e);
void main() async {
  await Future.wait([
    SharedPreferencesInterface.initialize(),
    Supabase.initialize(
      debug: false,
      url: 'https://zcckkiwosxzupxblocff.supabase.co',
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY2traXdvc3h6dXB4YmxvY2ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODY4NDk3MzMsImV4cCI6MjAwMjQyNTczM30.IVIT9yIxQ9JiwbDB6v10ZI8eP7c1oQhwoWZejoODllQ",
    ),
  ]);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    UserMetadataWrapper(
      child: MaterialApp.router(
        routerConfig: appRouter,
        title: "Bird's Eye",
        themeMode: ThemeMode.system,
        theme: ThemeData.from(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFFB91C21),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFFFDAD6),
            onPrimaryContainer: Color(0xFF410003),
            secondary: Color(0xFF5C53A7),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFE4DFFF),
            onSecondaryContainer: Color(0xFF170362),
            tertiary: Color(0xFF006C4E),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFF87F8C9),
            onTertiaryContainer: Color(0xFF002115),
            error: Color(0xFFBA1A1A),
            errorContainer: Color(0xFFFFDAD6),
            onError: Color(0xFFFFFFFF),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFFFFBFF),
            onSurface: Color(0xFF201A19),
            surfaceContainerHighest: Color(0xFFF5DDDB),
            onSurfaceVariant: Color(0xFF534342),
            outline: Color(0xFF857371),
            onInverseSurface: Color(0xFFFBEEEC),
            inverseSurface: Color(0xFF362F2E),
            inversePrimary: Color(0xFFFFB3AC),
            shadow: Color(0xFF000000),
            surfaceTint: Color(0xFFB91C21),
            outlineVariant: Color(0xFFD8C2BF),
            scrim: Color(0xFF000000),
          ),
          textTheme: Typography.englishLike2021
              .merge(Typography.blackHelsinki)
              .copyWith(
                titleLarge: const TextStyle(
                  inherit: true,
                  fontFamily: "Verdana",
                  fontWeight: FontWeight.bold,
                ),
                headlineLarge: const TextStyle(
                  fontFamily: "VarelaRound",
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                ),
              ),
        ),
        darkTheme: ThemeData.from(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFFFB3AC),
            onPrimary: Color(0xFF680008),
            primaryContainer: Color(0xFF930010),
            onPrimaryContainer: Color(0xFFFFDAD6),
            secondary: Color(0xFFC6BFFF),
            onSecondary: Color(0xFF2D2276),
            secondaryContainer: Color(0xFF443A8E),
            onSecondaryContainer: Color(0xFFE4DFFF),
            tertiary: Color(0xFF6ADBAE),
            onTertiary: Color(0xFF003827),
            tertiaryContainer: Color(0xFF00513A),
            onTertiaryContainer: Color(0xFF87F8C9),
            error: Color(0xFFFFB4AB),
            errorContainer: Color(0xFF93000A),
            onError: Color(0xFF690005),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF201A19),
            onSurface: Color(0xFFEDE0DE),
            surfaceContainerHighest: Color(0xFF534342),
            onSurfaceVariant: Color(0xFFD8C2BF),
            outline: Color(0xFFA08C8A),
            onInverseSurface: Color(0xFF201A19),
            inverseSurface: Color(0xFFEDE0DE),
            inversePrimary: Color(0xFFB91C21),
            shadow: Color(0xFF000000),
            surfaceTint: Color(0xFFFFB3AC),
            outlineVariant: Color(0xFF534342),
            scrim: Color(0xFF000000),
          ),
          textTheme: Typography.englishLike2021
              .merge(Typography.whiteHelsinki)
              .copyWith(
                titleLarge: const TextStyle(
                  inherit: true,
                  fontFamily: "Verdana",
                  fontWeight: FontWeight.bold,
                ),
                headlineLarge: const TextStyle(
                  fontFamily: "VarelaRound",
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                ),
              ),
        ),
      ),
    ),
  );
}
