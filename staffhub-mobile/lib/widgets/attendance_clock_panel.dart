import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app_theme.dart';

import '../l10n/l10n.dart';

import '../services/api_service.dart';

import '../services/auth_service.dart';

import '../services/biometric_service.dart';

import '../services/location_service.dart';

/// Geofenced clock in/out with map — reusable on staff home, admin & supervisor dashboards.

class AttendanceClockPanel extends StatefulWidget {

  const AttendanceClockPanel({

    super.key,

    this.staffId,

    this.showSectionTitle = true,

  });



  /// When omitted, loaded from [AuthService.getCurrentUser].

  final String? staffId;

  final bool showSectionTitle;



  @override

  State<AttendanceClockPanel> createState() => _AttendanceClockPanelState();

}



class _AttendanceClockPanelState extends State<AttendanceClockPanel> with L10nMixin {

  String _staffId = '';

  bool _isLoading = false;

  String? _message;

  bool _isSuccess = false;

  double? _distance;

  double? _workplaceLat;

  double? _workplaceLng;

  double? _userLat;

  double? _userLng;

  int _radiusMeters = 60;

  String _branchName = '';

  DateTime? _clockInTime;

  DateTime? _clockOutTime;



  static const int _maxWorkHours = 12;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) return;

      _initStaffId();

    });

  }



  Future<void> _initStaffId() async {

    final preset = widget.staffId?.trim();

    if (preset != null && preset.isNotEmpty) {

      setState(() => _staffId = preset);

      await _loadTodayAttendance(preset);

      await _loadWorkplaceInfo(staffId: preset);

      return;

    }

    final user = await AuthService.getCurrentUser();

    if (!mounted) return;

    final id = user?['staffId'] as String? ?? '';

    setState(() => _staffId = id);

    if (id.isNotEmpty) {

      await _loadTodayAttendance(id);

      await _loadWorkplaceInfo(staffId: id);

    }

  }



  Future<void> _loadTodayAttendance(String staffId) async {

    try {

      final result = await ApiService.getTodayAttendance(staffId);

      if (result['success'] != true || !mounted) return;

      final data = result['data'] as Map<String, dynamic>?;

      if (data != null) {

        final clockIn = data['clockIn'];

        final clockOut = data['clockOut'];

        setState(() {

          _clockInTime = clockIn != null ? DateTime.parse(clockIn.toString()) : null;

          _clockOutTime = clockOut != null ? DateTime.parse(clockOut.toString()) : null;

        });

      } else {

        setState(() {

          _clockInTime = null;

          _clockOutTime = null;

        });

      }

    } catch (_) {}

  }



  Future<void> _doAutoClockOut() async {

    if (_staffId.isEmpty) return;

    if (!mounted) return;

    setState(() => _isLoading = true);

    _clearMessage();

    try {

      final result = await ApiService.autoClockOut(_staffId);

      if (result['success'] == true && mounted) {

        _showMessage(tr('auto_clock_out', {'hours': '$_maxWorkHours'}), true);

        await _loadTodayAttendance(_staffId);

      } else {

        _showMessage(result['message'] ?? tr('auto_clock_out_failed'), false);

      }

    } catch (e) {

      final s = e.toString();

      _showMessage(

        s.contains('SocketException') || s.contains('TimeoutException')

            ? tr('api_unreachable_short')

            : tr('error_prefix', {'message': s}),

        false,

      );

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  Future<bool> _loadWorkplaceInfo({String? staffId}) async {

    try {

      final id = staffId ?? (_staffId.isNotEmpty ? _staffId : null);

      final result = await ApiService.getWorkplaceInfo(staffId: id);

      if (result['success'] == true && result['data'] != null && mounted) {

        final data = result['data'] as Map<String, dynamic>;

        final lat = (data['lat'] as num).toDouble();

        final lng = (data['lng'] as num).toDouble();

        final r = data['radiusMeters'];

        setState(() {

          _workplaceLat = lat;

          _workplaceLng = lng;

          _radiusMeters = r is int ? r : (r as num?)?.toInt() ?? 60;

          _branchName = data['branchName'] as String? ?? '';

        });

        await _checkLocation();

        return true;

      }

    } catch (_) {

      if (mounted) await _checkLocation();

    }

    return false;

  }



  Future<bool> _ensureWorkplaceReady() async {

    if (_workplaceLat != null && _workplaceLng != null) return true;

    if (await _loadWorkplaceInfo()) return true;

    if (!mounted) return false;

    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return false;

    return _loadWorkplaceInfo();

  }



  Future<void> _checkLocation() async {

    final position = await LocationService.getCurrentPosition();

    if (!mounted) return;

    if (position != null && _workplaceLat != null && _workplaceLng != null) {

      final dist = LocationService.getDistanceInMeters(

        position.latitude,

        position.longitude,

        _workplaceLat!,

        _workplaceLng!,

      );

      setState(() {

        _distance = dist;

        _userLat = position.latitude;

        _userLng = position.longitude;

      });

    } else if (position != null) {

      setState(() {

        _userLat = position.latitude;

        _userLng = position.longitude;

        _distance = null;

      });

    }

  }



  Future<bool> _verifyBiometric(String action) async {

    if (await AuthService.isDemoMode()) return true;

    final result = await BiometricService.authenticateForAttendance(action);

    if (result.success) return true;

    _showMessage(result.message ?? tr('biometric_failed'), false);

    return false;

  }



  Future<void> _clockIn() async {

    if (_staffId.isEmpty) {

      _showMessage(tr('user_not_found'), false);

      return;

    }

    setState(() => _isLoading = true);

    _clearMessage();

    try {

      final position = await LocationService.getCurrentPosition();

      if (position == null) {

        _showMessage(tr('gps_unavailable'), false);

        return;

      }

      if (!await _ensureWorkplaceReady() || _workplaceLat == null || _workplaceLng == null) {

        _showMessage(tr('workplace_load_failed'), false);

        return;

      }

      await _checkLocation();

      if (!LocationService.isWithinRadius(

        position.latitude,

        position.longitude,

        _workplaceLat!,

        _workplaceLng!,

        _radiusMeters,

      )) {

        _showMessage(

          tr('outside_geofence', {

            'radius': '$_radiusMeters',

            'distance': _distance?.toStringAsFixed(0) ?? '?',

          }),

          false,

        );

        return;

      }

      if (!await _verifyBiometric('clock in')) return;

      final result = await ApiService.clockIn(

        _staffId,

        position.latitude,

        position.longitude,

      );

      if (result['success'] == true) {

        _showMessage(tr('clock_in_success'), true);

        await _loadTodayAttendance(_staffId);

      } else {

        _showMessage(result['message'] ?? tr('clock_in_failed'), false);

      }

    } catch (e) {

      final s = e.toString();

      _showMessage(

        s.contains('SocketException') || s.contains('TimeoutException') || s.contains('Failed host lookup')

            ? tr('api_unreachable')

            : tr('error_prefix', {'message': s}),

        false,

      );

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  Future<void> _clockOut() async {

    if (_staffId.isEmpty) {

      _showMessage(tr('user_not_found'), false);

      return;

    }

    setState(() => _isLoading = true);

    _clearMessage();

    try {

      final position = await LocationService.getCurrentPosition();

      if (position == null) {

        _showMessage(tr('gps_unavailable'), false);

        return;

      }

      if (!await _ensureWorkplaceReady() || _workplaceLat == null || _workplaceLng == null) {

        _showMessage(tr('workplace_load_failed'), false);

        return;

      }

      await _checkLocation();

      if (!LocationService.isWithinRadius(

        position.latitude,

        position.longitude,

        _workplaceLat!,

        _workplaceLng!,

        _radiusMeters,

      )) {

        _showMessage(

          tr('outside_geofence', {

            'radius': '$_radiusMeters',

            'distance': _distance?.toStringAsFixed(0) ?? '?',

          }),

          false,

        );

        return;

      }

      if (!await _verifyBiometric('clock out')) return;

      final result = await ApiService.clockOut(

        _staffId,

        position.latitude,

        position.longitude,

      );

      if (result['success'] == true) {

        _showMessage(tr('clock_out_success'), true);

        await _loadTodayAttendance(_staffId);

      } else {

        _showMessage(result['message'] ?? tr('clock_out_failed'), false);

      }

    } catch (e) {

      final s = e.toString();

      _showMessage(

        s.contains('SocketException') || s.contains('TimeoutException') || s.contains('Failed host lookup')

            ? tr('api_unreachable')

            : tr('error_prefix', {'message': s}),

        false,

      );

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  void _showMessage(String msg, bool success) {

    if (!mounted) return;

    setState(() {

      _message = msg;

      _isSuccess = success;

    });

  }



  void _clearMessage() {

    if (!mounted) return;

    setState(() => _message = null);

  }



  @override

  Widget build(BuildContext context) {

    if (_staffId.isEmpty) {

      return const SizedBox.shrink();

    }



    final isWithinRange = _distance != null && _distance! <= _radiusMeters;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        if (widget.showSectionTitle) ...[

          Text(

            tr('attendance'),

            style: TextStyle(

              fontSize: 18,

              fontWeight: FontWeight.bold,

              color: context.appColors.textPrimary,

            ),

          ),

          if (_branchName.isNotEmpty)

            Padding(

              padding: const EdgeInsets.only(top: 6),

              child: Row(

                children: [

                  Icon(Icons.store_mall_directory_outlined, size: 16, color: context.appColors.accentBlue),

                  const SizedBox(width: 6),

                  Expanded(

                    child: Text(

                      tr('cawangan_colon', {'name': _branchName}),

                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),

                    ),

                  ),

                ],

              ),

            ),

          const SizedBox(height: 12),

        ],

        if (_workplaceLat != null && _workplaceLng != null)

          Container(

            height: 280,

            margin: const EdgeInsets.only(bottom: 16),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.5)),

              boxShadow: [

                BoxShadow(

                  color: context.appColors.primaryBlue.withValues(alpha: 0.2),

                  blurRadius: 12,

                  offset: const Offset(0, 4),

                ),

              ],

            ),

            clipBehavior: Clip.antiAlias,

            child: Stack(

              children: [

                GoogleMap(

                  initialCameraPosition: CameraPosition(

                    target: LatLng(_workplaceLat!, _workplaceLng!),

                    zoom: 17,

                  ),

                  liteModeEnabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,

                  circles: {

                    Circle(

                      circleId: const CircleId('workplace_radius'),

                      center: LatLng(_workplaceLat!, _workplaceLng!),

                      radius: _radiusMeters.toDouble(),

                      fillColor: context.appColors.accentBlue.withValues(alpha: 0.25),

                      strokeColor: context.appColors.accentBlue.withValues(alpha: 0.8),

                      strokeWidth: 2,

                    ),

                  },

                  markers: {

                    Marker(

                      markerId: const MarkerId('workplace'),

                      position: LatLng(_workplaceLat!, _workplaceLng!),

                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

                    ),

                    if (_userLat != null && _userLng != null)

                      Marker(

                        markerId: const MarkerId('user'),

                        position: LatLng(_userLat!, _userLng!),

                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),

                      ),

                  },

                  myLocationEnabled: true,

                  myLocationButtonEnabled: false,

                  mapToolbarEnabled: false,

                  zoomControlsEnabled: false,

                ),

                Positioned(

                  top: 8,

                  right: 8,

                  child: Material(

                    color: context.appColors.card.withValues(alpha: 0.9),

                    borderRadius: BorderRadius.circular(8),

                    child: IconButton(

                      icon: Icon(Icons.my_location, color: context.appColors.accentBlue, size: 24),

                      onPressed: _checkLocation,

                      tooltip: tr('refresh_location'),

                    ),

                  ),

                ),

                if (_clockInTime != null && _clockOutTime == null)

                  Positioned(

                    bottom: 8,

                    left: 8,

                    right: 8,

                    child: _WorkElapsedTicker(

                      clockInTime: _clockInTime!,

                      maxWorkHours: _maxWorkHours,

                      onExceededMaxHours: _doAutoClockOut,

                    ),

                  ),

              ],

            ),

          ),

        Container(

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(

            color: context.appColors.card,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.5)),

            boxShadow: [

              BoxShadow(

                color: context.appColors.primaryBlue.withValues(alpha: 0.15),

                blurRadius: 16,

                offset: const Offset(0, 6),

              ),

            ],

          ),

          child: Column(

            children: [

              Icon(

                isWithinRange ? Icons.location_on : Icons.location_off,

                size: 48,

                color: isWithinRange ? context.appColors.accentBlue : Colors.amber.shade400,

              ),

              const SizedBox(height: 8),

              Text(

                isWithinRange

                    ? tr('within_radius', {'radius': '$_radiusMeters'})

                    : tr('outside_radius', {'radius': '$_radiusMeters'}),

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w600,

                  color: isWithinRange ? context.appColors.accentBlue : Colors.amber.shade400,

                ),

              ),

              if (_distance != null)

                Text(

                  tr('distance_m', {'distance': _distance!.toStringAsFixed(0)}),

                  style: TextStyle(fontSize: 14, color: context.appColors.textSecondary),

                ),

              if (_distance != null && _distance! > 100000)

                Padding(

                  padding: const EdgeInsets.only(top: 10),

                  child: Text(

                    tr('gps_emulator_hint'),

                    style: TextStyle(fontSize: 12, height: 1.35, color: Colors.amber.shade200),

                  ),

                ),

            ],

          ),

        ),

        const SizedBox(height: 16),

        if (_message != null)

          Container(

            padding: const EdgeInsets.all(12),

            margin: const EdgeInsets.only(bottom: 16),

            decoration: BoxDecoration(

              color: _isSuccess

                  ? Colors.green.shade900.withValues(alpha: 0.3)

                  : Colors.red.shade900.withValues(alpha: 0.3),

              borderRadius: BorderRadius.circular(12),

              border: Border.all(

                color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,

              ),

            ),

            child: Row(

              children: [

                Icon(

                  _isSuccess ? Icons.check_circle : Icons.error,

                  color: _isSuccess ? Colors.greenAccent : Colors.redAccent,

                  size: 24,

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Text(

                    _message!,

                    style: TextStyle(color: _isSuccess ? Colors.greenAccent : Colors.redAccent),

                  ),

                ),

              ],

            ),

          ),

        SizedBox(

          width: double.infinity,

          height: 56,

          child: ElevatedButton.icon(

            onPressed: _isLoading ? null : _clockIn,

            icon: _isLoading

                ? const SizedBox(

                    width: 24,

                    height: 24,

                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),

                  )

                : const Icon(Icons.login),

            label: Text(tr('clock_in')),

            style: ElevatedButton.styleFrom(

              backgroundColor: context.appColors.primaryBlue,

              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

            ),

          ),

        ),

        const SizedBox(height: 12),

        SizedBox(

          width: double.infinity,

          height: 56,

          child: OutlinedButton.icon(

            onPressed: _isLoading ? null : _clockOut,

            icon: const Icon(Icons.logout),

            label: Text(tr('clock_out')),

            style: OutlinedButton.styleFrom(

              foregroundColor: context.appColors.accentBlue,

              side: BorderSide(color: context.appColors.accentBlue),

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

            ),

          ),

        ),

      ],

    );

  }

}



class _WorkElapsedTicker extends StatefulWidget {

  const _WorkElapsedTicker({

    required this.clockInTime,

    required this.maxWorkHours,

    required this.onExceededMaxHours,

  });



  final DateTime clockInTime;

  final int maxWorkHours;

  final VoidCallback onExceededMaxHours;



  @override

  State<_WorkElapsedTicker> createState() => _WorkElapsedTickerState();

}



class _WorkElapsedTickerState extends State<_WorkElapsedTicker> with L10nMixin {

  Timer? _timer;



  static String _formatElapsed(Duration d) {

    final h = d.inHours.toString().padLeft(2, '0');

    final m = (d.inMinutes % 60).toString().padLeft(2, '0');

    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$h:$m:$s';

  }



  @override

  void initState() {

    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {

      if (!mounted) return;

      final elapsed = DateTime.now().difference(widget.clockInTime);

      if (elapsed >= Duration(hours: widget.maxWorkHours)) {

        _timer?.cancel();

        widget.onExceededMaxHours();

      } else {

        setState(() {});

      }

    });

  }



  @override

  void dispose() {

    _timer?.cancel();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final elapsed = DateTime.now().difference(widget.clockInTime);

    final remaining = Duration(hours: widget.maxWorkHours) - elapsed;

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(

        color: context.appColors.card.withValues(alpha: 0.95),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: context.appColors.accentBlue.withValues(alpha: 0.5)),

      ),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(Icons.timer, color: context.appColors.accentBlue, size: 24),

          const SizedBox(width: 12),

          Text(

            _formatElapsed(elapsed),

            style: TextStyle(

              fontSize: 24,

              fontWeight: FontWeight.bold,

              color: context.appColors.accentBlue,

              letterSpacing: 2,

            ),

          ),

          const SizedBox(width: 12),

          Text(

            remaining.isNegative

                ? ''

                : tr('time_left', {

                    'hours': '${remaining.inHours}',

                    'minutes': '${remaining.inMinutes % 60}',

                  }),

            style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),

          ),

        ],

      ),

    );

  }

}


