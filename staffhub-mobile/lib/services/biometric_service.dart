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

  static bool _hasFingerprint(List<BiometricType> types) =>
      types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong);

  /// Face unlock on Android is often reported as [BiometricType.weak], not [BiometricType.face].
  static bool _hasFace(List<BiometricType> types) =>
      types.contains(BiometricType.face) || types.contains(BiometricType.weak);

  static Future<bool> isAvailable() async {
    if (!await _auth.isDeviceSupported()) return false;
    return _auth.canCheckBiometrics;
  }

  static Future<String> preferredLabel() async {
    final types = await _auth.getAvailableBiometrics();
    if (_hasFingerprint(types)) return 'Fingerprint';
    if (_hasFace(types)) return 'Face ID';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometric';
  }

  static String _reasonFor(List<BiometricType> types, String action) {
    if (_hasFingerprint(types)) return 'Verify your fingerprint to $action';
    if (_hasFace(types)) return 'Verify your Face ID to $action';
    return 'Verify your identity to $action';
  }

  /// Returns [BiometricAuthResult.skipped] only when the device has no secure auth at all.
  ///
  /// Priority: fingerprint → Face ID → device PIN/password (fallback for tablets that
  /// hide face unlock from apps or only expose "weak" biometrics).
  static Future<BiometricAuthResult> authenticateForAttendance(String action) async {
    if (!await _auth.isDeviceSupported()) {
      return BiometricAuthResult.skipped();
    }

    final canCheck = await _auth.canCheckBiometrics;
    final types = await _auth.getAvailableBiometrics();

    if (!canCheck && types.isEmpty) {
      return BiometricAuthResult.failed(
        'Please set up fingerprint, Face ID, or a screen lock in your phone settings to clock in/out.',
      );
    }

    final hasFingerprint = _hasFingerprint(types);
    final hasFace = _hasFace(types);

    // Fingerprint devices: biometric-only first.
    if (hasFingerprint) {
      final fpResult = await _tryAuthenticate(
        reason: 'Verify your fingerprint to $action',
        biometricOnly: true,
      );
      if (fpResult != null) return fpResult;

      // Fingerprint failed/cancelled — fall back to Face ID or PIN if available.
      final fallback = await _tryAuthenticate(
        reason: hasFace ? 'Verify your Face ID to $action' : 'Verify with Face ID or PIN to $action',
        biometricOnly: !hasFace,
      );
      if (fallback != null) return fallback;

      return BiometricAuthResult.failed('Fingerprint verification cancelled');
    }

    // Face-only / tablet: many Android devices report empty or weak types — still prompt.
    if (hasFace || types.isEmpty) {
      final faceResult = await _tryAuthenticate(
        reason: 'Verify your Face ID to $action',
        biometricOnly: false,
      );
      if (faceResult != null) return faceResult;

      return BiometricAuthResult.failed(
        'Face ID verification failed. Enable face unlock or a screen lock in Settings.',
      );
    }

    // Iris or other biometrics.
    final other = await _tryAuthenticate(
      reason: _reasonFor(types, action),
      biometricOnly: true,
    );
    if (other != null) return other;

    final pinFallback = await _tryAuthenticate(
      reason: 'Verify with biometrics or device PIN to $action',
      biometricOnly: false,
    );
    if (pinFallback != null) return pinFallback;

    return BiometricAuthResult.failed('Verification cancelled');
  }

  /// Returns success/failed result, or null if user cancelled (try next method).
  static Future<BiometricAuthResult?> _tryAuthenticate({
    required String reason,
    required bool biometricOnly,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
        ),
      );
      if (ok) return BiometricAuthResult.success();
      return null;
    } catch (_) {
      return null;
    }
  }
}
