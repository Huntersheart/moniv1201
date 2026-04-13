import 'package:get/get.dart';

import '../middleware/auth_middleware.dart';
import '../bindings/add_dog_binding.dart';
import '../bindings/select_module_binding.dart';
import '../bindings/session_live_binding.dart';
import '../bindings/session_summary_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/dashboard_binding.dart';
import '../bindings/onboarding_binding.dart';
import '../bindings/splash_binding.dart';
import '../../ui/views/auth/create_password_view.dart';
import '../../ui/views/auth/forgot_password_view.dart';
import '../../ui/views/auth/login_view.dart';
import '../../ui/views/auth/verify_code_view.dart';
import '../../ui/views/add_dog_view.dart';
import '../../ui/views/select_module_view.dart';
import '../../ui/views/session_live_view.dart';
import '../../ui/views/session_summary_view.dart';
import '../../ui/views/dashboard_view.dart';
import '../../ui/views/onboarding_view.dart';
import '../../ui/views/splash_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRoutes.splash,
      page: SplashView.new,
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: OnboardingView.new,
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: LoginView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: ForgotPasswordView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.verifyCode,
      page: VerifyCodeView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.createPassword,
      page: CreatePasswordView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: DashboardView.new,
      binding: DashboardBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.addDog,
      page: AddDogView.new,
      binding: AddDogBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.selectModule,
      page: SelectModuleView.new,
      binding: SelectModuleBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.sessionLive,
      page: SessionLiveView.new,
      binding: SessionLiveBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.sessionSummary,
      page: SessionSummaryView.new,
      binding: SessionSummaryBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
