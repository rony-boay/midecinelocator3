import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midecinelocator3/auth_page.dart';

void main() {
  // Test Initialization and UI Elements
  testWidgets('Test initial UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage()));

    // Check for email, password fields, and login button
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  // Test Sign-up Toggle
  testWidgets('Test toggle between login and sign-up',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage()));

    // Initially, it should show the login button
    expect(find.text('Login'), findsOneWidget);

    // Tap the 'Sign up' link
    await tester.tap(find.text('Don\'t have an account? Sign up'));
    await tester.pump();

    // Now it should show the sign-up form fields
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Pharmacy Name'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
