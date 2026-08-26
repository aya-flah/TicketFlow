import 'package:flutter/material.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';

/// Returns the correct home screen widget based on role.
Widget homeForRole({
  required String userName,
  required String role,
}) {
  if (role == 'customer') {
    return CustomerHomeScreen(userName: userName);
  }
  if (role == 'manager') {
    return DashboardScreen(userName: userName);
  }
  // agent (or empty/unknown role) → ticket list
  return HomeScreen(userName: userName, role: role);
}
