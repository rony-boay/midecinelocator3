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

  // Test Login Flow
  testWidgets('Test login button click', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage()));

    // Enter text in email and password fields
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');

    // Tap the login button
    await tester.tap(find.text('Login'));
    await tester.pump();

    // You can check if navigation or login was called
    // This depends on your navigation logic
  });

  // Test Sign-up Toggle
  testWidgets('Test toggle between login and sign-up', (WidgetTester tester) async {
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

  // Test Location Selection
  testWidgets('Test select location', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage()));

    // Switch to sign-up form
    await tester.tap(find.text('Don\'t have an account? Sign up'));
    await tester.pump();

    // Tap the select location button
    await tester.tap(find.text('Select Location'));
    await tester.pump();

    // Check if snackbar was shown (mocking location can be complex)
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
