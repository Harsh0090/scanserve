class ApiConfig {
  static String get baseUrl {
    // Default to the production backend for all platforms to match the website.
    // Use 'http://10.0.2.2:5000' for Android Emulator local testing if needed.
    return 'https://scanserve.in';
    // return 'https://zpjn3sn1-5000.inc1.devtunnels.ms';
  }

  // If moving to production later, this should be swapped:
  // static const String baseUrl = 'https://restaurant-model-backend.onrender.com';
}
