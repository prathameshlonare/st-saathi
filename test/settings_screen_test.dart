import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:st_saathi/core/app_state.dart';
import 'package:st_saathi/core/localization/app_strings.dart';
import 'package:st_saathi/presentation/screens/settings_screen.dart';

/// Widget tests for the settings screen: rendering in both languages, the
/// dataset version read from preferences, and the destructive-action confirm
/// dialog added in Phase 1.
///
/// The body is a ListView, so items below the fold are not built until
/// scrolled to. [scrollTo] handles that.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap({required bool isMarathi}) {
    final appState = AppState()..setMarathi(isMarathi);
    return MaterialApp(
      home: SettingsScreen(
        appState: appState,
        onLanguageToggle: (_) {},
        onThemeModeChanged: (_) {},
        isActive: true,
      ),
    );
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('renders the settings title and check-updates button in English',
      (tester) async {
    await tester.pumpWidget(wrap(isMarathi: false));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.get('settings', false)), findsOneWidget);
    expect(find.text(AppStrings.get('language', false)), findsOneWidget);

    final checkUpdates = find.text(AppStrings.get('check_updates', false));
    await scrollTo(tester, checkUpdates);
    expect(checkUpdates, findsOneWidget);
  });

  testWidgets('renders in Marathi when the language flag is on', (tester) async {
    await tester.pumpWidget(wrap(isMarathi: true));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.get('settings', true)), findsOneWidget);

    final checkUpdates = find.text(AppStrings.get('check_updates', true));
    await scrollTo(tester, checkUpdates);
    expect(checkUpdates, findsOneWidget);
  });

  testWidgets('shows the stored dataset version', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ota_db_name_en': 'November 2026 Edition',
    });
    await tester.pumpWidget(wrap(isMarathi: false));
    await tester.pumpAndSettle();

    final version = find.textContaining('November 2026 Edition');
    await scrollTo(tester, version);
    expect(version, findsOneWidget);
  });

  testWidgets('clearing history asks for confirmation first', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_searches': ['1|Pune|2|Nashik'],
      'saved_bus_ids': ['10', '20'],
    });
    await tester.pumpWidget(wrap(isMarathi: false));
    await tester.pumpAndSettle();

    final clearButton = find.text('Clear History & Bookmarks');
    await scrollTo(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // The Phase 1 confirm dialog must appear before anything is deleted.
    expect(find.text('Clear all saved data?'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('recent_searches'), isNotNull);

    // Cancel keeps the data.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all saved data?'), findsNothing);
    expect((await SharedPreferences.getInstance()).getStringList('recent_searches'), isNotNull);
  });

  testWidgets('confirming the clear dialog deletes history and bookmarks',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_searches': ['1|Pune|2|Nashik'],
      'saved_bus_ids': ['10', '20'],
    });
    await tester.pumpWidget(wrap(isMarathi: false));
    await tester.pumpAndSettle();

    final clearButton = find.text('Clear History & Bookmarks');
    await scrollTo(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('recent_searches'), isFalse);
    expect(prefs.containsKey('saved_bus_ids'), isFalse);
  });
}
