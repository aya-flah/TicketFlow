import 'package:flutter/material.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/home_screen.dart';

/// Returns the correct home screen widget based on role.
Widget homeForRole({
  required String userName,
  required String role,
}) {
  if (role == 'customer') {
    return CustomerHomeScreen(userName: userName);
  }
  return HomeScreen(userName: userName, role: role);
}
