import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/widgets/custom_pie_chart.dart';

void main() {
  group('CustomPieChart Animation Tests', () {
    final sampleStats = [
      CategoryStatModel(
        categoryId: 'cat_food',
        categoryName: 'Makanan',
        category: CategoryModel(
          id: 'cat_food',
          name: 'Makanan',
          type: 'expense',
          icon: 'food',
          color: '#FF5722',
        ),
        amount: 60000,
        percent: 60.0,
      ),
      CategoryStatModel(
        categoryId: 'cat_transport',
        categoryName: 'Transportasi',
        category: CategoryModel(
          id: 'cat_transport',
          name: 'Transportasi',
          type: 'expense',
          icon: 'car',
          color: '#2196F3',
        ),
        amount: 40000,
        percent: 40.0,
      ),
    ];

    testWidgets('Renders empty placeholder when stats list is empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomPieChart(stats: []),
          ),
        ),
      );

      expect(find.text('Belum atau tidak ada data'), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets(
        'Animates circularly from 0% to 100% on initial mount and replays on trigger',
        (tester) async {
      int trigger = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    CustomPieChart(
                      stats: sampleStats,
                      animationTrigger: trigger,
                    ),
                    TextButton(
                      onPressed: () => setState(() => trigger++),
                      child: const Text('Replay'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(CustomPieChart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Step through the 900ms animation
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Trigger replay (simulating navigating into StatsScreen tab)
      await tester.tap(find.text('Replay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    });

    testWidgets('Handles single-category 100% pie animation without error',
        (tester) async {
      final singleStat = [
        CategoryStatModel(
          categoryId: 'cat_food',
          categoryName: 'Makanan',
          category: CategoryModel(
            id: 'cat_food',
            name: 'Makanan',
            type: 'expense',
            icon: 'food',
            color: '#4CAF50',
          ),
          amount: 100000,
          percent: 100.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPieChart(stats: singleStat),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPieChart), findsOneWidget);
    });
  });
}
