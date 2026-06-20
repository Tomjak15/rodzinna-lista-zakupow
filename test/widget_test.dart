import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/screens/onboarding_screen.dart';

void main() {
  testWidgets('pokazuje ekran startowy rodziny', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Rodzinna Lista Zakupów'), findsOneWidget);
    expect(find.text('Utwórz rodzinę'), findsWidgets);
    expect(find.text('Dołącz do rodziny'), findsWidgets);
  });
}
