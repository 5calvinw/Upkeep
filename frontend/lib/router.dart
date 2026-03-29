import 'package:go_router/go_router.dart';
import 'data/services/auth_service.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/unauthorized_screen.dart';
import 'presentation/screens/ticket_detail_screen.dart';
import 'presentation/screens/tenant/dashboard_screen.dart';
import 'presentation/screens/tenant/new_ticket_screen.dart';
import 'presentation/screens/manager/dashboard_screen.dart';
import 'presentation/screens/manager/ticket_detail_screen.dart';
import 'presentation/screens/manager/active_tickets_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthService.currentUser,
  redirect: (context, state) {
    final user = AuthService.currentUser.value;
    final path = state.matchedLocation;

    // Public routes — always allow through.
    if (path == '/login' || path.startsWith('/register') || path == '/unauthorized') {
      // If already authenticated, skip login/register.
      if (user != null && (path == '/login' || path.startsWith('/register'))) {
        return user.role == 'manager' ? '/manager/dashboard' : '/dashboard';
      }
      return null;
    }

    // Protected routes — must be authenticated.
    if (user == null) return '/login';

    // Role enforcement.
    if (user.role == 'tenant' && path.startsWith('/manager')) {
      return '/unauthorized';
    }
    if (user.role == 'manager' &&
        (path == '/dashboard' ||
            path == '/tickets/new' ||
            path.startsWith('/tickets/'))) {
      return '/manager/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => RegisterScreen(
        inviteToken: state.uri.queryParameters['token'],
      ),
    ),
    GoRoute(
      path: '/unauthorized',
      builder: (context, state) => const UnauthorizedScreen(),
    ),
    // Tenant routes
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const TenantDashboardScreen(),
    ),
    GoRoute(
      path: '/tickets/new',
      builder: (context, state) => const NewTicketScreen(),
    ),
    GoRoute(
      path: '/tickets/:id',
      builder: (context, state) =>
          TicketDetailScreen(ticketId: state.pathParameters['id']!),
    ),
    // Manager routes
    GoRoute(
      path: '/manager/dashboard',
      builder: (context, state) => const ManagerDashboardScreen(),
    ),
    GoRoute(
      path: '/manager/tickets',
      builder: (context, state) => const ManagerActiveTicketsScreen(),
    ),
    GoRoute(
      path: '/manager/tickets/:id',
      builder: (context, state) =>
          ManagerTicketDetailScreen(ticketId: state.pathParameters['id']!),
    ),
  ],
);
