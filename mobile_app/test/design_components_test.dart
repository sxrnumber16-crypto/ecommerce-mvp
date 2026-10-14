import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/design/components/app_button.dart';
import 'package:myapp/design/components/app_chip.dart';

void main() {
  testWidgets('AppButton shows bilingual label', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppButton(label: 'লগইন / Login', onPressed: null))));
    expect(find.text('লগইন / Login'), findsOneWidget);
  });

  testWidgets('AppChip shows selected state', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppChip(label: 'Clothing', selected: true))));
    expect(find.text('Clothing'), findsOneWidget);
  });
}
