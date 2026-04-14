import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';
import '../models/leave_balance.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'apply_leave_screen.dart';
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
  Timer? _workTimer;

  static const int _maxWorkHours = 12;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadWorkplaceInfo();
    _checkLocation();
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      final staffId = user['staffId'] as String? ?? '';
      setState(() => _staffId = staffId);
      _loadLeaveBalance(staffId);
      _loadTodayAttendance(staffId);
      _loadLeaveRequestsPreview(staffId);
    }
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
        if (_clockInTime != null && _clockOutTime == null) {
          _startWorkTimer();
        }
      } else {
        setState(() {
          _clockInTime = null;
          _clockOutTime = null;
        });
      }
    } catch (_) {}
  }

  void _startWorkTimer() {
    _workTimer?.cancel();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final elapsed = now.difference(_clockInTime!);
      if (elapsed.inHours >= _maxWorkHours) {
        _workTimer?.cancel();
        _doAutoClockOut();
      } else {
        setState(() {});
      }
    });
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

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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
    } catch (_) {}
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
        _workTimer?.cancel();
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
                const SizedBox(height: 8),
                const Text(
                  'Leave Dashboard',
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
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
                    ),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.accentBlue.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.timer, color: AppTheme.accentBlue, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatElapsed(DateTime.now().difference(_clockInTime!)),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentBlue,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    () {
                                      final elapsed = DateTime.now().difference(_clockInTime!);
                                      final remaining = const Duration(hours: _maxWorkHours) - elapsed;
                                      if (remaining.isNegative) return '';
                                      return '(${remaining.inHours}h ${remaining.inMinutes % 60}m left)';
                                    }(),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
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
                if (_staffId.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, color: AppTheme.accentBlue, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Staff ID', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                              Text(
                                _staffId,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
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
