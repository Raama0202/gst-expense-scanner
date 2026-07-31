import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gst_expense_scanner/features/auth/presentation/screens/login_screen.dart';
import 'package:gst_expense_scanner/core/theme/app_theme.dart';

void main() {
  testWidgets('Login screen shows mobile field and send OTP button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.textContaining('Mobile'), findsWidgets);
    expect(find.byType(FilledButton), findsWidgets);
  });
}
