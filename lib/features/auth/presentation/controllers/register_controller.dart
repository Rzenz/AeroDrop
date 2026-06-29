import '../../../../core/models/user_model.dart';

class RegisterController {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Display name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateEmail(String? value, UserRole role) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
  if (role == UserRole.facultyStaff && !value.toLowerCase().endsWith('@uclm.edu')) {
  return 'Faculty/Staff must use a @uclm.edu address';
}
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
