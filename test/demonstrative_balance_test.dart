import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitlab_mobile2/models/user_model.dart';
import 'package:fitlab_mobile2/utils/subscription_plan.dart';
import 'package:fitlab_mobile2/providers/user_provider.dart';
import 'package:fitlab_mobile2/screens/subscription_screen.dart';
import 'package:fitlab_mobile2/widgets/coach_dashboard.dart';

void main() {
  test(
    'catalog resolves athlete and trainer plans using their persisted IDs',
    () {
      final catalog = [
        {'id': 73, 'nome': 'Elite'},
        {'id': 219, 'nome': 'Coach Elite'},
        {'id': 83, 'nome': 'Free'},
      ];
      expect(subscriptionPlanId(catalog, 'Atleta Elite'), 73);
      expect(subscriptionPlanId(catalog, 'Coach Elite'), 219);
      expect(subscriptionPlanId(catalog, 'Free'), 83);
      expect(() => subscriptionPlanId(catalog, 'Pro'), throwsFormatException);
      expect(
        () => subscriptionPlanId([...catalog, catalog.first], 'Elite'),
        throwsFormatException,
      );
    },
  );
  test('API decimal and integer balances keep the numeric JSON contract', () {
    for (final number in [27.97, 0, 55.94]) {
      final user = UserModel.fromJson(
        jsonDecode('{"saldoFinanceiro":$number}'),
      );
      expect(user.saldoFinanceiro, number.toDouble());
      expect(user.toJson()['saldoFinanceiro'], isA<num>());
    }
    expect(UserModel.fromJson({}).saldoFinanceiro, 0);
  });

  testWidgets(
    'balance is explicitly demonstrative without a transfer promise',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
          child: const MaterialApp(home: Scaffold(body: CoachDashboard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SALDO DEMONSTRATIVO'), findsOneWidget);
      expect(
        find.text('Saldo demonstrativo — sem transferência financeira'),
        findsOneWidget,
      );
      expect(find.text('SALDO A RECEBER'), findsNothing);
    },
  );

  testWidgets('subscription is identified as simulated without real billing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Assinatura simulada — sem cobrança real'),
      findsOneWidget,
    );
    expect(
      find.text('Demonstração acadêmica — sem cobrança real'),
      findsOneWidget,
    );
    expect(find.text('Cobrança processada via FitLab Pay'), findsNothing);
  });
}
