import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smart_money/widgets/action_button.dart';
import 'package:smart_money/widgets/animated_tab_bar.dart';
import 'package:smart_money/widgets/custom_card.dart';

void main() {
  group('AnimatedTabBar Component Tests', () {
    testWidgets('renders default 2 icon tabs correctly', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              activeIndex: activeIndex,
              onTabChanged: (idx) => activeIndex = idx,
            ),
          ),
        ),
      );

      expect(find.byIcon(Ionicons.list), findsOneWidget);
      expect(find.byIcon(Ionicons.images), findsOneWidget);

      await tester.tap(find.byIcon(Ionicons.images));
      await tester.pumpAndSettle();
      expect(activeIndex, 1);
    });

    testWidgets('renders 3 text tabs and responds to selection', (tester) async {
      int activeIndex = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              width: 320,
              activeIndex: activeIndex,
              onTabChanged: (idx) => activeIndex = idx,
              tabs: const [
                TabItem(key: 'income', label: 'Income'),
                TabItem(key: 'expense', label: 'Expense'),
                TabItem(key: 'transfer', label: 'Transfer'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(activeIndex, 0);

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(activeIndex, 2);
    });
  });

  group('ActionButton Component Tests', () {
    testWidgets('renders title and triggers callback when pressed', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              title: 'Simpan',
              onPress: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Simpan'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(pressed, true);
    });

    testWidgets('displays loading indicator and blocks taps when isLoading', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              title: 'Simpan',
              isLoading: true,
              onPress: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);

      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(pressed, false);
    });

    testWidgets('blocks interaction when disabled is true', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              title: 'Hapus',
              disabled: true,
              onPress: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Hapus'));
      await tester.pump();
      expect(pressed, false);
    });
  });

  group('CustomCard Component Tests', () {
    testWidgets('renders child content and responds to onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomCard(
              onTap: () => tapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      await tester.pump();
      expect(tapped, true);
    });
  });
}
