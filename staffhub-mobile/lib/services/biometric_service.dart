import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool success;
  final bool skipped;
  final String? message;

  const BiometricAuthResult._({
    required this.success,
    this.skipped = false,
    this.message,
  });

  factory BiometricAuthResult.success() => const BiometricAuthResult._(success: true);

  factory BiometricAuthResult.skipped() => const BiometricAuthResult._(success: true, skipped: true);

  factory BiometricAuthResult.failed(String message) =>
      BiometricAuthResult._(success: false, message: message);
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (!await _auth.isDeviceSupported()) return false;
    if (!await _auth.canCheckBiometrics) return false;
    final types = await _auth.getAvailableBiometrics();
    return types.isNotEmpty;
  }

  static Future<String> preferredLabel() async {
    final types = await _auth.getAvailableBiometrics();
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometric';
  }

  /// Returns [BiometricAuthResult.skipped] only when the device has no biometric hardware.
  static Future<BiometricAuthResult> authenticateForAttendance(String action) async {
    final supported = await _auth.isDeviceSupported();
    if (!supported) {
      return BiometricAuthResult.skipped();
    }

    final types = await _auth.getAvailableBiometrics();
    if (types.isEmpty) {
      return BiometricAuthResult.failed(
        'Please set up fingerprint or Face ID in your phone settings to clock in/out.',
      );
    }

    final label = await preferredLabel();
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Verify your $label to $action',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (ok) return BiometricAuthResult.success();
      return BiometricAuthResult.failed('$label verification cancelled');
    } catch (e) {
      return BiometricAuthResult.failed('$label verification failed');
    }
  }
}
