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
      _showMessage('Error: Please ensure API is running', false);
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

  Future<void> _loadWorkplaceInfo() async {
    try {
      final result = await ApiService.getWorkplaceInfo();
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() {
          _workplaceLat = (result['data']['lat'] as num).toDouble();
          _workplaceLng = (result['data']['lng'] as num).toDouble();
          _radiusMeters = result['data']['radiusMeters'] ?? 60;
        });
        await _checkLocation();
      }
    } catch (_) {
      // API unreachable: still try location so the screen can show user coords without map center.
      if (mounted) await _checkLocation();
    }
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

      await _checkLocation();

      if (!LocationService.isWithinRadius(
        position.latitude,
        position.longitude,
        _workplaceLat ?? 0,
        _workplaceLng ?? 0,
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
      _showMessage('Error: Please ensure API is running and connection is OK', false);
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

      await _checkLocation();

      if (!LocationService.isWithinRadius(
        position.latitude,
        position.longitude,
        _workplaceLat ?? 0,
        _workplaceLng ?? 0,
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
      _showMessage('Error: Please ensure API is running and connection is OK', false);
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
      backgroundColor: AppTheme.backgroundBlack,
      drawer: Drawer(
        backgroundColor: AppTheme.surfaceDark,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.15),
                  border: Border(bottom: BorderSide(color: AppTheme.borderBlue.withOpacity(0.3))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const StaffHubLogo(height: 48),
                    const SizedBox(height: 12),
                    if (_staffId.isNotEmpty)
                      Text(
                        'ID: $_staffId',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined, color: AppTheme.accentBlue),
                title: const Text('Home', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, color: AppTheme.accentBlue),
                title: const Text('Work schedule', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkScheduleScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppTheme.accentBlue),
                title: const Text('Payslip', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayslipScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: AppTheme.accentBlue),
                title: const Text('Attendance history', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined, color: AppTheme.accentBlue),
                title: const Text('Apply leave', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_time_rounded, color: AppTheme.accentBlue),
                title: const Text('Apply overtime (OT)', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ApplyOvertimeScreen()))
                      .then((_) {
                        if (mounted) _loadOvertimePreview();
                      });
                },
              ),
              const Divider(color: AppTheme.borderBlue),
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppTheme.accentBlue),
                title: const Text('Profile', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
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
          child: StaffHubLogo(height: 28),
        ),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppTheme.accentBlue),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.accentBlue),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceDark,
              AppTheme.backgroundBlack,
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
                const SizedBox(height: 4),
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _staffName.isNotEmpty ? _staffName : 'Staff',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_staffId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Staff ID: $_staffId',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_workplaceLat != null && _workplaceLng != null)
                  Container(
                    height: 300,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
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
                              fillColor: AppTheme.accentBlue.withOpacity(0.25),
                              strokeColor: AppTheme.accentBlue.withOpacity(0.8),
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
                            color: AppTheme.cardDark.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              icon: const Icon(Icons.my_location, color: AppTheme.accentBlue, size: 24),
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
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.15),
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
                            ? AppTheme.accentBlue
                            : Colors.amber.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isWithinRange
                            ? 'Within ${_radiusMeters}m radius'
                            : 'Outside ${_radiusMeters}m radius',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isWithinRange ? AppTheme.accentBlue : Colors.amber.shade400,
                        ),
                      ),
                      if (_distance != null)
                        Text(
                          'Distance: ${_distance!.toStringAsFixed(0)}m',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        const SizedBox(width: 12),
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
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Clock In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    label: const Text('Clock Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: const BorderSide(color: AppTheme.accentBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Leave',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
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
                      color: AppTheme.cardDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
                        ),
                        SizedBox(width: 12),
                        Text('Loading leave balance...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (_leaveRequestsPreview.isNotEmpty) ...[
                  const Text(
                    'Leave request responses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        color: AppTheme.cardDark,
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
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if (note != null && note.isNotEmpty)
                                  Text(
                                    'Admin: $note',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                  const SizedBox(height: 8),
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
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Apply Leave'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: const BorderSide(color: AppTheme.accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Overtime (OT)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your recent OT requests and status (supervisor approval).',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.95)),
                ),
                const SizedBox(height: 12),
                if (_otRequestsPreview.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      'No OT requests yet. Submit one to see it here.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: stColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.more_time_rounded, size: 22, color: stColor.withValues(alpha: 0.9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_shortDate(r['otDate'])} · $hLabel',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if ((r['reason'] as String?)?.trim().isNotEmpty == true)
                                  Text(
                                    r['reason'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                const SizedBox(height: 10),
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
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Apply OT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: const BorderSide(color: AppTheme.accentBlue),
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
        color: AppTheme.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: AppTheme.accentBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            _formatElapsed(elapsed),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentBlue,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            remaining.isNegative ? '' : '(${remaining.inHours}h ${remaining.inMinutes % 60}m left)',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.1),
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
              Icon(leave.iconData, color: AppTheme.accentBlue, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leave.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${leave.remaining}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentBlue,
              height: 1.2,
            ),
          ),
          Text(
            'remaining / ${leave.total} days',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
