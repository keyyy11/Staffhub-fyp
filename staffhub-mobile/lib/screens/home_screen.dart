import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';
import '../models/leave_balance.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'apply_leave_screen.dart';
import 'apply_overtime_screen.dart';
import 'attendance_history_screen.dart';
import 'payslip_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'work_schedule_screen.dart';
import '../widgets/staffhub_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _staffId = '';
  String _staffName = '';
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;
  double? _distance;
  double? _workplaceLat;
  double? _workplaceLng;
  double? _userLat;
  double? _userLng;
  int _radiusMeters = 60;
  DateTime? _clockInTime;
  DateTime? _clockOutTime;
  List<LeaveBalance> _leaveBalances = [];
  List<Map<String, dynamic>> _leaveRequestsPreview = [];
  List<Map<String, dynamic>> _otRequestsPreview = [];

  static const int _maxWorkHours = 12;

  @override
  void initState() {
    super.initState();
    // Defer work until after first frame so the shell can paint (reduces ANR risk with Maps + GPS on emulator).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUser();
      _loadWorkplaceInfo();
      // Do not call _checkLocation() here: _loadWorkplaceInfo already awaits _checkLocation() after coords load.
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      final staffId = user['staffId'] as String? ?? '';
      final name = (user['name'] as String?)?.trim() ?? '';
      setState(() {
        _staffId = staffId;
        _staffName = name;
      });
      _loadLeaveBalance(staffId);
      _loadTodayAttendance(staffId);
      // Defer previews so Maps + GPS finish first (reduces emulator ANR / "System UI not responding").
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || staffId.isEmpty) return;
        _loadLeaveRequestsPreview(staffId);
        _loadOvertimePreview();
      });
    }
  }

  Future<void> _loadOvertimePreview() async {
    if (await AuthService.isDemoMode()) return;
    try {
      final result = await ApiService.getMyOvertimeRequests();
      if (result['success'] == true && result['data'] != null && mounted) {
        final list = List<Map<String, dynamic>>.from(result['data'] as List);
        setState(() {
          _otRequestsPreview = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  String _shortDate(dynamic d) {
    if (d == null) return '-';
    final date = DateTime.parse(d.toString());
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _loadLeaveRequestsPreview(String staffId) async {
    if (staffId.isEmpty) return;
    if (await AuthService.isDemoMode()) return;
    try {
      final result = await ApiService.getMyLeaveRequests(staffId);
      if (result['success'] == true && result['data'] != null && mounted) {
        final list = List<Map<String, dynamic>>.from(result['data'] as List);
        setState(() {
          _leaveRequestsPreview = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  Color _leaveStatusColor(String? s) {
    switch (s) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  String _leaveStatusLabel(String? s) {
    switch (s) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
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
        if (!mounted) return;
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
        _showMessage('Auto clock out after $_maxWorkHours hours', true);
        await _loadTodayAttendance(_staffId);
      } else {
        _showMessage(result['message'] ?? 'Auto clock out failed', false);
      }
    } catch (e) {
      final s = e.toString();
      _showMessage(
        s.contains('SocketException') || s.contains('TimeoutException')
            ? 'Cannot reach API. Check base URL and that staffhub-api is running.'
            : 'Error: $s',
        false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLeaveBalance([String? staffId]) async {
    final id = staffId ?? _staffId;
    if (id.isEmpty) return;
    try {
      final result = await ApiService.getLeaveBalance(id);
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _leaveBalances = [
            LeaveBalance.fromJson('medical', 'Medical Leave', 'medical_services', data['medicalLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('annual', 'Annual Leave', 'event_available', data['annualLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('unpaid', 'Unpaid Leave', 'money_off', data['unpaidLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('other', 'Other Leave', 'more_horiz', data['otherLeave'] as Map<String, dynamic>? ?? {}),
          ];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _leaveBalances = [
            LeaveBalance(type: 'medical', label: 'Medical Leave', iconData: Icons.medical_services, total: 14, used: 2, remaining: 12),
            LeaveBalance(type: 'annual', label: 'Annual Leave', iconData: Icons.event_available, total: 14, used: 5, remaining: 9),
            LeaveBalance(type: 'unpaid', label: 'Unpaid Leave', iconData: Icons.money_off, total: 0, used: 0, remaining: 0),
            LeaveBalance(type: 'other', label: 'Other Leave', iconData: Icons.more_horiz, total: 5, used: 1, remaining: 4),
          ];
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Loads workplace circle from API. Returns false if coords could not be set (never use 0,0 as fallback).
  Future<bool> _loadWorkplaceInfo() async {
    try {
      final result = await ApiService.getWorkplaceInfo();
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        final lat = (data['lat'] as num).toDouble();
        final lng = (data['lng'] as num).toDouble();
        final r = data['radiusMeters'];
        setState(() {
          _workplaceLat = lat;
          _workplaceLng = lng;
          _radiusMeters = r is int ? r : (r as num?)?.toInt() ?? 60;
        });
        await _checkLocation();
        return true;
      }
    } catch (_) {
      // API unreachable: still try location so the screen can show user coords without map center.
      if (mounted) await _checkLocation();
    }
    return false;
  }

  /// Ensures workplace lat/lng are loaded before geofence checks (avoids treating null as 0,0 → bogus ~13,000 km distance).
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

  Future<void> _clockIn() async {
    if (_staffId.isEmpty) {
      _showMessage('User data not found. Please log in again.', false);
      return;
    }

    setState(() => _isLoading = true);
    _clearMessage();

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showMessage('Unable to get location. Please enable GPS.', false);
        return;
      }

      if (!await _ensureWorkplaceReady() || _workplaceLat == null || _workplaceLng == null) {
        _showMessage(
          'Could not load workplace location. Check API connection (same Wi‑Fi / API_BASE_URL), then try again.',
          false,
        );
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
          'You are outside the ${_radiusMeters}m radius. Distance: ${_distance?.toStringAsFixed(0) ?? "?"}m',
          false,
        );
        return;
      }

      final result = await ApiService.clockIn(
        _staffId,
        position.latitude,
        position.longitude,
      );

      if (result['success'] == true) {
        _showMessage('Clock in successful', true);
        await _loadTodayAttendance(_staffId);
      } else {
        _showMessage(result['message'] ?? 'Clock in failed', false);
      }
    } catch (e) {
      final s = e.toString();
      _showMessage(
        s.contains('SocketException') || s.contains('TimeoutException') || s.contains('Failed host lookup')
            ? 'Cannot reach API. Set API URL (Android emulator: 10.0.2.2:3000/api). Ensure staffhub-api is running on your PC.'
            : 'Error: $s',
        false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clockOut() async {
    if (_staffId.isEmpty) {
      _showMessage('User data not found. Please log in again.', false);
      return;
    }

    setState(() => _isLoading = true);
    _clearMessage();

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showMessage('Unable to get location. Please enable GPS.', false);
        return;
      }

      if (!await _ensureWorkplaceReady() || _workplaceLat == null || _workplaceLng == null) {
        _showMessage(
          'Could not load workplace location. Check API connection (same Wi‑Fi / API_BASE_URL), then try again.',
          false,
        );
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
          'You are outside the ${_radiusMeters}m radius. Distance: ${_distance?.toStringAsFixed(0) ?? "?"}m',
          false,
        );
        return;
      }

      final result = await ApiService.clockOut(
        _staffId,
        position.latitude,
        position.longitude,
      );

      if (result['success'] == true) {
        _showMessage('Clock out successful', true);
        await _loadTodayAttendance(_staffId);
      } else {
        _showMessage(result['message'] ?? 'Clock out failed', false);
      }
    } catch (e) {
      final s = e.toString();
      _showMessage(
        s.contains('SocketException') || s.contains('TimeoutException') || s.contains('Failed host lookup')
            ? 'Cannot reach API. Set API URL (Android emulator: 10.0.2.2:3000/api). Ensure staffhub-api is running on your PC.'
            : 'Error: $s',
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
    setState(() {
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWithinRange = _distance != null && _distance! <= _radiusMeters;

    return Scaffold(
      backgroundColor: context.appColors.background,
      drawer: Drawer(
        backgroundColor: context.appColors.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: context.appColors.primaryBlue.withOpacity(0.15),
                  border: Border(bottom: BorderSide(color: context.appColors.borderBlue.withOpacity(0.3))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const StaffHubLogo(height: 58),
                    SizedBox(height: 12),
                    if (_staffId.isNotEmpty)
                      Text(
                        'ID: $_staffId',
                        style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home_outlined, color: context.appColors.accentBlue),
                title: Text('Home', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_outlined, color: context.appColors.accentBlue),
                title: Text('Work schedule', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkScheduleScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long_outlined, color: context.appColors.accentBlue),
                title: Text('Payslip', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayslipScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: context.appColors.accentBlue),
                title: Text('Attendance history', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.event_available_outlined, color: context.appColors.accentBlue),
                title: Text('Apply leave', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.more_time_rounded, color: context.appColors.accentBlue),
                title: Text('Apply overtime (OT)', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ApplyOvertimeScreen()))
                      .then((_) {
                        if (mounted) _loadOvertimePreview();
                      });
                },
              ),
              Divider(color: context.appColors.borderBlue),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
                title: Text('Settings', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline, color: context.appColors.accentBlue),
                title: Text('Profile', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text('Log out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: StaffHubLogo(height: 36),
        ),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: context.appColors.accentBlue),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: context.appColors.accentBlue),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.appColors.surface,
              context.appColors.background,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _staffName.isNotEmpty ? _staffName : 'Staff',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                if (_staffId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Staff ID: $_staffId',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                    ),
                  ),
                SizedBox(height: 24),
                Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                if (_workplaceLat != null && _workplaceLng != null)
                  Container(
                    height: 300,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: context.appColors.primaryBlue.withOpacity(0.2),
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
                              fillColor: context.appColors.accentBlue.withOpacity(0.25),
                              strokeColor: context.appColors.accentBlue.withOpacity(0.8),
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
                            color: context.appColors.card.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              icon: Icon(Icons.my_location, color: context.appColors.accentBlue, size: 24),
                              onPressed: _checkLocation,
                              tooltip: 'Refresh location',
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
                    border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: context.appColors.primaryBlue.withOpacity(0.15),
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
                        color: isWithinRange
                            ? context.appColors.accentBlue
                            : Colors.amber.shade400,
                      ),
                      SizedBox(height: 8),
                      Text(
                        isWithinRange
                            ? 'Within ${_radiusMeters}m radius'
                            : 'Outside ${_radiusMeters}m radius',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isWithinRange ? context.appColors.accentBlue : Colors.amber.shade400,
                        ),
                      ),
                      if (_distance != null)
                        Text(
                          'Distance: ${_distance!.toStringAsFixed(0)}m',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      if (_distance != null && _distance! > 100000)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'This usually means your GPS is far from the workplace (common on emulators: default US vs Malaysia site). Set a mock location near the blue pin, or use a real device at the office.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.amber.shade200,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.red.shade900.withOpacity(0.3),
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
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                            ),
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
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.login),
                    label: Text('Clock In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _clockOut,
                    icon: Icon(Icons.logout),
                    label: Text('Clock Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.accentBlue,
                      side: BorderSide(color: context.appColors.accentBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'Leave',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                if (_leaveBalances.isNotEmpty)
                  SizedBox(
                    height: 128,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _leaveBalances.length,
                      itemBuilder: (context, index) {
                        final leave = _leaveBalances[index];
                        return _LeaveCard(leave: leave);
                      },
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appColors.card.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appColors.borderBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.accentBlue),
                        ),
                        SizedBox(width: 12),
                        Text('Loading leave balance...', style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                SizedBox(height: 12),
                if (_leaveRequestsPreview.isNotEmpty) ...[
                  Text(
                    'Leave request responses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._leaveRequestsPreview.map((r) {
                    final st = r['status'] as String? ?? 'pending';
                    final stColor = _leaveStatusColor(st);
                    final start = r['startDate'] != null ? DateTime.tryParse(r['startDate'].toString()) : null;
                    final end = r['endDate'] != null ? DateTime.tryParse(r['endDate'].toString()) : null;
                    final range = (start != null && end != null)
                        ? '${start.day}/${start.month}–${end.day}/${end.month}'
                        : '';
                    final note = (r['adminComment'] as String?)?.trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: stColor.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  range,
                                  style: TextStyle(color: context.appColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if (note != null && note.isNotEmpty)
                                  Text(
                                    'Admin: $note',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _leaveStatusLabel(st),
                              style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
                        )
                        .then((_) {
                          if (mounted) _loadLeaveRequestsPreview(_staffId);
                        }),
                    icon: Icon(Icons.add_circle_outline, size: 20),
                    label: Text('Apply Leave'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.accentBlue,
                      side: BorderSide(color: context.appColors.accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'Overtime (OT)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your recent OT requests and status (supervisor approval).',
                  style: TextStyle(fontSize: 13, color: context.appColors.textSecondary.withValues(alpha: 0.95)),
                ),
                SizedBox(height: 12),
                if (_otRequestsPreview.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.card.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'No OT requests yet. Submit one to see it here.',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                    ),
                  )
                else
                  ..._otRequestsPreview.map((r) {
                    final st = r['status'] as String? ?? 'pending';
                    final stColor = _leaveStatusColor(st);
                    final hours = r['hours'];
                    final hLabel = hours is num ? '${hours.toString()} h' : '${hours ?? '-'} h';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: stColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.more_time_rounded, size: 22, color: stColor.withValues(alpha: 0.9)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_shortDate(r['otDate'])} · $hLabel',
                                  style: TextStyle(color: context.appColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if ((r['reason'] as String?)?.trim().isNotEmpty == true)
                                  Text(
                                    r['reason'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _leaveStatusLabel(st),
                              style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(builder: (_) => const ApplyOvertimeScreen()),
                        )
                        .then((_) {
                          if (mounted) _loadOvertimePreview();
                        }),
                    icon: Icon(Icons.add_circle_outline, size: 20),
                    label: Text('Apply OT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.accentBlue,
                      side: BorderSide(color: context.appColors.accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Updates every second **only this overlay**, not the whole [HomeScreen] (avoids rebuilding [GoogleMap] each tick).
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

class _WorkElapsedTickerState extends State<_WorkElapsedTicker> {
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
          SizedBox(width: 12),
          Text(
            _formatElapsed(elapsed),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.appColors.accentBlue,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            remaining.isNegative ? '' : '(${remaining.inHours}h ${remaining.inMinutes % 60}m left)',
            style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveBalance leave;

  const _LeaveCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: context.appColors.primaryBlue.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(leave.iconData, color: context.appColors.accentBlue, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  leave.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${leave.remaining}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.appColors.accentBlue,
              height: 1.2,
            ),
          ),
          Text(
            'remaining / ${leave.total} days',
            style: TextStyle(
              fontSize: 11,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
