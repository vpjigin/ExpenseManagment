import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/quick_add_expense_screen.dart';

/// App router configuration using go_router
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/quick-add',
      name: 'quick-add',
      builder: (context, state) {
        final amount = state.uri.queryParameters['amount'];
        final smsBody = state.uri.queryParameters['smsBody'];
        return QuickAddExpenseScreen(
          prefilledAmount: amount != null ? double.tryParse(amount) : null,
          smsBody: smsBody,
        );
      },
    ),
  ],
);
