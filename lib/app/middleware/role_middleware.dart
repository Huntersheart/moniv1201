import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../ui/controllers/auth_controller.dart';
import '../routes/app_routes.dart';

/// Protects admin-only routes.
/// Redirects to /home if the current user does not have the 'admin' role.
class RoleMiddleware extends GetMiddleware {
  final String requiredRole;

  RoleMiddleware({this.requiredRole = 'admin'});

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthController>()) {
      return const RouteSettings(name: AppRoutes.home);
    }
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) {
      return const RouteSettings(name: AppRoutes.login);
    }
    if (requiredRole == 'admin' && !user.isAdmin) {
      return const RouteSettings(name: AppRoutes.home);
    }
    return null;
  }
}
