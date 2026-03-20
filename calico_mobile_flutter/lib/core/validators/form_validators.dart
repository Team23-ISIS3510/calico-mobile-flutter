/// All client-side form validation rules in one place.
/// Every method returns null when the value is valid, or a human-readable error string when it is not.
abstract final class FormValidators {

  static String? fullName(String? value) {
// ----- Full Name Validation -----
    final v = value?.trim() ?? '';

    if (v.isEmpty) return 'Please enter your full name.';

    if (v.length < 2) return 'Name must be at least 2 characters.';

    if (v.length > 60) return 'Name must be 60 characters or fewer.';

    // Digits are not allowed in a person's name.
    if (v.contains(RegExp(r'[0-9]'))) {
      return 'Name must not contain numbers.';
    }

    // Only letters (including accented), spaces, hyphens and apostrophes.
    // Covers names like: María José, O'Brien, García-López.
    if (!v.contains(RegExp(r"^[a-zA-ZÀ-ÿ\s'\-]+$"))) {
      return 'Name must contain only letters, spaces, hyphens or apostrophes.';
    }

    return null;
  }

// ----- Email Validation -----

  static String? email(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) return 'Please enter your email address.';

    // Standard email regex: local@domain.tld
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(v)) {
      return 'Enter a valid email address (e.g. name@domain.com).';
    }

    return null;
  }

// ----- Password Validation -----

  static String? password(String? value) {
    final v = value ?? '';

    if (v.isEmpty) return 'Please enter a password.';

    if (v.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    if (!v.contains(RegExp(r'[A-Z]'))) {
      return 'Password must include at least one uppercase letter (A–Z).';
    }

    if (!v.contains(RegExp(r'[a-z]'))) {
      return 'Password must include at least one lowercase letter (a–z).';
    }

    if (!v.contains(RegExp(r'[0-9]'))) {
      return 'Password must include at least one number (0–9).';
    }

    if (v.contains(' ')) {
      return 'Password must not contain spaces.';
    }

    return null;
  }

// ----- Phone Validation -----

  static String? phone(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) return 'Please enter your phone number.';

    // Accepts: +57 300 123 4567 / 3001234567 / (300) 123-4567
    if (!v.contains(RegExp(r'^[\+\d\s\(\)\-]{7,20}$'))) {
      return 'Enter a valid phone number.';
    }

    return null;
  }
}
