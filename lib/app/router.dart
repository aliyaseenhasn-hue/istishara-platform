import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../core/navigation/app_navigation.dart';
import '../features/authentication/presentation/pages/login_page.dart';
import '../features/authentication/presentation/pages/signup_page.dart';
import '../features/authentication/presentation/pages/otp_page.dart';
import '../features/authentication/presentation/pages/complete_profile_page.dart';
import '../features/authentication/presentation/pages/lawyer_onboarding_page.dart';
import '../features/authentication/presentation/pages/account_unavailable_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_reviews_page.dart';
import '../features/admin/presentation/pages/admin_users_page.dart';
import '../features/admin/presentation/pages/lawyer_verification_page.dart';
import '../features/admin/presentation/pages/payment_management_page.dart';
import '../features/admin/presentation/pages/specialization_change_requests_page.dart';
import '../features/admin/presentation/pages/cancellation_requests_page.dart';
import '../features/admin/presentation/pages/no_show_reviews_page.dart';
import '../features/admin/presentation/pages/financial_management_page.dart';
import '../features/home/presentation/pages/landing_page.dart';
import '../features/home/presentation/pages/public_info_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/lawyers/presentation/pages/lawyers_list_page.dart';
import '../features/lawyers/presentation/pages/lawyer_details_page.dart';
import '../features/lawyers/presentation/pages/legal_categories_page.dart';
import '../features/lawyers/presentation/pages/lawyer_setup_page.dart';
import '../features/lawyers/presentation/pages/lawyer_pending_page.dart';
import '../features/lawyers/presentation/pages/lawyer_dashboard_page.dart';
import '../features/lawyers/presentation/pages/lawyer_profile_edit_page.dart';
import '../features/lawyers/presentation/pages/lawyer_availability_page.dart';
import '../features/lawyers/presentation/pages/specialization_change_page.dart';
import '../features/lawyers/presentation/pages/lawyer_wallet_page.dart';
import '../features/bookings/presentation/pages/create_booking_page.dart';
import '../features/bookings/presentation/pages/bookings_list_page.dart';
import '../features/bookings/presentation/pages/archived_bookings_page.dart';
import '../features/bookings/presentation/pages/booking_cancellation_overlay.dart';
import '../features/bookings/presentation/pages/booking_notification_target_page.dart';
import '../features/bookings/presentation/pages/manual_payment_page.dart';
import '../features/bookings/presentation/pages/manual_payment_required_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/chat/presentation/pages/conversations_page.dart';
import '../features/payments/presentation/pages/payment_upload_page.dart';
import '../features/payments/presentation/pages/payment_result_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/profile/presentation/pages/notification_settings_page.dart';
import '../features/profile/presentation/pages/notifications_page.dart';
import '../features/profile/presentation/pages/payment_methods_page.dart';
import '../features/profile/presentation/pages/help_center_page.dart';
import '../features/bookings/domain/entities/booking.dart';
import '../features/lawyers/domain/entities/lawyer_profile.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../shared/widgets/app_shell.dart';
part 'router.g.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateChangesProvider);
  return GoRouter(
    navigatorKey: AppNavigation.navigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).authStateChanges(),
    ),
    redirect: (context, state) async {
      var user = authState.valueOrNull;
      if (user == null && SupabaseConfig.client.auth.currentUser != null) {
        try {
          user = await ref.read(authRepositoryProvider).getCurrentUser();
        } catch (_) {}
      }

      final location = state.matchedLocation;
      final login = location == '/login' || location == '/admin-login';
      final signup = location == '/signup';
      final otp = location == '/otp';
      final complete = location == '/complete-profile';
      final onboarding = location == '/lawyer-onboarding';
      final pending = location == '/lawyer-pending';
      final unavailable = location == '/account-unavailable';
      final paymentResult = location == '/payment-result';
      final admin = location.startsWith('/admin') && location != '/admin-login';
      final publicRoute = location == '/' ||
          location == '/how-it-works' ||
          location == '/privacy' ||
          location == '/terms' ||
          location == '/contact' ||
          location == '/faq' ||
          location == '/lawyers' ||
          location == '/legal-categories' ||
          location == '/help-center';
      final lawyerProfileRoute = location.startsWith('/lawyers/') ||
          location.startsWith('/lawyer-details/');
      final isClient = user?.role == 'user' || user?.role == 'client';

      if (paymentResult) return null;

      if (user == null) {
        if (lawyerProfileRoute) {
          final returnTo = state.uri.toString();
          return '/login?returnTo=${Uri.encodeComponent(returnTo)}';
        }
        return (login || signup || otp || publicRoute) ? null : '/login';
      }

      String? accountStatus;
      try {
        final authUser = SupabaseConfig.client.auth.currentUser;
        if (authUser != null) {
          final profile = await SupabaseConfig.client
              .from('profiles')
              .select('status')
              .eq('auth_id', authUser.id)
              .maybeSingle();
          accountStatus = profile?['status']?.toString();
        }
      } catch (_) {}

      if (accountStatus != null && accountStatus != 'active') {
        return unavailable ? null : '/account-unavailable';
      }
      if (unavailable) {
        if (user.role == 'admin') return '/admin';
        return user.role == 'lawyer' && user.isVerified ? '/lawyer-home' : '/home';
      }

      if (user.role == 'admin') {
        if (complete || onboarding || login || signup) return '/admin';
        return admin ? null : '/admin';
      }
      if (!user.isOnboardingComplete) {
        return (complete || onboarding) ? null : '/complete-profile';
      }
      if (admin && user.role != 'admin') return '/';
      if (location == '/create-booking' && !isClient) {
        return user.role == 'lawyer' ? '/lawyer-home' : '/';
      }
      if (user.role == 'lawyer') {
        if (!user.isVerified) {
          return location == '/lawyer-setup' || pending
              ? null
              : '/lawyer-pending';
        }
        if (location == '/lawyers' ||
            location.startsWith('/lawyer-details/') ||
            location.startsWith('/lawyers/')) {
          return '/lawyer-home';
        }
      }

      if (login || signup || otp || (complete && user.isOnboardingComplete)) {
        final returnTo = state.uri.queryParameters['returnTo'];
        if (returnTo != null &&
            returnTo.isNotEmpty &&
            returnTo.startsWith('/')) {
          return returnTo;
        }
        return user.role == 'lawyer' && user.isVerified
            ? '/lawyer-home'
            : '/home';
      }
      if (location == '/' && user.role == 'lawyer' && user.isVerified) {
        return '/lawyer-home';
      }
      if (location == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LandingPage()),
      GoRoute(
        path: '/how-it-works',
        builder: (c, s) => PublicInfoPage.howItWorks(),
      ),
      GoRoute(path: '/privacy', builder: (c, s) => PublicInfoPage.privacy()),
      GoRoute(path: '/terms', builder: (c, s) => PublicInfoPage.terms()),
      GoRoute(path: '/contact', builder: (c, s) => PublicInfoPage.contact()),
      GoRoute(path: '/faq', builder: (c, s) => PublicInfoPage.faq()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(
        path: '/admin-login',
        builder: (c, s) => const LoginPage(isAdminLogin: true),
      ),
      GoRoute(path: '/signup', builder: (c, s) => const SignupPage()),
      GoRoute(
        path: '/complete-profile',
        builder: (c, s) => const CompleteProfilePage(),
      ),
      GoRoute(
        path: '/lawyer-onboarding',
        builder: (c, s) {
          final e = s.extra as Map<String, dynamic>? ?? {};
          return LawyerOnboardingPage(
            fullName: e['fullName'] ?? '',
            email: e['email'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (c, s) => OtpPage(phone: s.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/account-unavailable',
        builder: (c, s) => const AccountUnavailablePage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomePage()),
          GoRoute(
            path: '/lawyers',
            builder: (c, s) => const LawyersListPage(),
          ),
          GoRoute(
            path: '/lawyers/:id',
            builder: (c, s) =>
                LawyerDetailsPage(profileId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/legal-categories',
            builder: (c, s) => const LegalCategoriesPage(),
          ),
          GoRoute(
            path: '/lawyer-home',
            builder: (c, s) => const LawyerDashboardPage(),
          ),
          GoRoute(
            path: '/lawyer-profile-edit',
            builder: (c, s) => const LawyerProfileEditPage(),
          ),
          GoRoute(
            path: '/lawyer-availability',
            builder: (c, s) => const LawyerAvailabilityPage(),
          ),
          GoRoute(
            path: '/lawyer-specialization-change',
            builder: (c, s) => const SpecializationChangePage(),
          ),
          GoRoute(
            path: '/lawyer-wallet',
            builder: (c, s) => const LawyerWalletPage(),
          ),
          GoRoute(
            path: '/lawyer-setup',
            builder: (c, s) => const LawyerSetupPage(),
          ),
          GoRoute(
            path: '/lawyer-details/:id',
            builder: (c, s) =>
                LawyerDetailsPage(profileId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/create-booking',
            builder: (c, s) {
              final e = s.extra as Map<String, dynamic>?;
              final lawyer = e?['lawyer'] as LawyerProfile?;
              if (lawyer == null) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'تعذر فتح صفحة الحجز. يرجى العودة إلى ملف المحامي والمحاولة مرة أخرى.',
                    ),
                  ),
                );
              }
              return CreateBookingPage(
                lawyer: lawyer,
                service: e?['service'],
                isCustom: e?['isCustom'] == true,
              );
            },
          ),
          GoRoute(
            path: '/bookings',
            builder: (c, s) => const BookingsListPage(),
          ),
          GoRoute(
            path: '/archived-bookings',
            builder: (c, s) => const ArchivedBookingsPage(),
          ),
          GoRoute(
            path: '/chats',
            builder: (c, s) => const ConversationsPage(),
          ),
          GoRoute(
            path: '/booking-details',
            builder: (c, s) {
              final b = s.extra as Booking?;
              if (b != null) {
                return BookingDetailsWithCancellation(booking: b);
              }
              final bookingId = s.uri.queryParameters['booking_id']?.trim();
              if (bookingId != null && bookingId.isNotEmpty) {
                return BookingNotificationTargetPage(bookingId: bookingId);
              }
              return const BookingsListPage();
            },
          ),
          GoRoute(
            path: '/manual-payment-required',
            builder: (c, s) => const ManualPaymentRequiredPage(),
          ),
          GoRoute(
            path: '/manual-payment',
            builder: (c, s) {
              final b = s.extra as Booking?;
              return b == null
                  ? const ManualPaymentRequiredPage()
                  : ManualPaymentPage(booking: b);
            },
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (c, s) =>
                ChatPage(conversationId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/upload-payment',
            builder: (c, s) {
              final b = s.extra as Booking?;
              return b == null
                  ? const BookingsListPage()
                  : PaymentUploadPage(booking: b);
            },
          ),
          GoRoute(
            path: '/payment-result',
            builder: (c, s) => PaymentResultPage(
              status: s.uri.queryParameters['status'],
              bookingId: s.uri.queryParameters['booking_id'],
            ),
          ),
          GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
          GoRoute(
            path: '/notifications',
            builder: (c, s) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/notification-settings',
            builder: (c, s) => const NotificationSettingsPage(),
          ),
          GoRoute(
            path: '/payment-methods',
            builder: (c, s) => const PaymentMethodsPage(),
          ),
          GoRoute(
            path: '/app-settings',
            builder: (c, s) => const ProfilePage(),
          ),
          GoRoute(
            path: '/help-center',
            builder: (c, s) => const HelpCenterPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (c, s) => const AdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'reviews',
            builder: (c, s) => const AdminReviewsPage(),
          ),
          GoRoute(
            path: 'no-show-reviews',
            builder: (c, s) => const NoShowReviewsPage(),
          ),
          GoRoute(
            path: 'users',
            builder: (c, s) => const AdminUsersPage(),
          ),
          GoRoute(
            path: 'lawyer-verifications',
            builder: (c, s) => const LawyerVerificationPage(),
          ),
          GoRoute(
            path: 'payments',
            builder: (c, s) => const PaymentManagementPage(),
          ),
          GoRoute(
            path: 'financial',
            builder: (c, s) => const FinancialManagementPage(),
          ),
          GoRoute(
            path: 'specialization-change-requests',
            builder: (c, s) => const SpecializationChangeRequestsPage(),
          ),
          GoRoute(
            path: 'cancellation-requests',
            builder: (c, s) => const CancellationRequestsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/lawyer-pending',
        builder: (c, s) => const LawyerPendingPage(),
      ),
    ],
  );
}
