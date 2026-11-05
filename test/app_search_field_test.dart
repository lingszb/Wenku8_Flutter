import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/app_search_field.dart';

void main() {
  testWidgets(
    'local search submits input and clears both controller and query',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              embedded: true,
              controller: controller,
              hint: '搜索本地书籍',
              onChanged: changes.add,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      );

      expect(find.byTooltip('清空搜索'), findsNothing);
      await tester.enterText(find.byType(TextField), '星空 #奇幻');
      await tester.pump();
      expect(changes.last, '星空 #奇幻');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, '星空 #奇幻');
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changes.last, isEmpty);
      expect(find.byTooltip('清空搜索'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
