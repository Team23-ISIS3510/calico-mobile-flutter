import 'package:calico_mobile_flutter/core/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SectionHeader renders its title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader('Courses'),
        ),
      ),
    );

    expect(find.text('Courses'), findsOneWidget);
  });
}
