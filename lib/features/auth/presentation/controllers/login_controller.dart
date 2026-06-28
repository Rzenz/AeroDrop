class LoginController {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'University email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+edu$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid university email address';
    }
    if (!value.endsWith('@uclm.edu')) {
      return 'Must be an official @uclm.edu address';
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
}
