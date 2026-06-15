export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
}

export interface AuthUser {
  id: string;
  staffId: string;
  name: string;
  email: string;
  role: "admin" | "staff" | "supervisor";
}

export interface StaffMember {
  staffId: string;
  name: string;
  email: string;
  phone?: string;
  department?: string;
  position?: string;
  salary?: number;
  role: "staff" | "supervisor";
  supervisorStaffId?: string;
  branchCode?: string;
}

export interface Branch {
  branchCode: string;
  name: string;
  address?: string;
  lat: number;
  lng: number;
  radiusMeters: number;
  isActive: boolean;
}

export interface AttendanceRecord {
  _id: string;
  staffId: string;
  staffName?: string;
  date: string;
  clockIn?: string;
  clockOut?: string;
  clockInLocation?: { lat: number; lng: number };
  clockOutLocation?: { lat: number; lng: number };
  status?: "on_time" | "late";
  clockInTime?: string;
  clockOutTime?: string;
}

export interface AttendanceReportStats {
  total: number;
  onTime: number;
  late: number;
}

export interface AttendanceReportResult {
  report: AttendanceRecord[];
  stats: AttendanceReportStats;
}

export interface LeaveRequest {
  _id: string;
  staffId: string;
  staffName?: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  totalDays: number;
  reason?: string;
  status: "pending" | "approved" | "rejected";
  adminComment?: string;
  hasMcLetter?: boolean;
  createdAt?: string;
}

export interface PayslipRecord {
  _id: string;
  staffId: string;
  year: number;
  month: number;
  grossPay?: number;
  netPay: number;
  remarks?: string;
}

export interface WarningLetter {
  _id: string;
  staffId: string;
  staffName?: string;
  category: string;
  notes?: string;
  issuedByAdminName?: string;
  createdAt?: string;
}

export interface DisciplineMetrics {
  lateCount: number;
  onTimeCount: number;
  onTimeRatio: number;
  rejectedLeaveCount: number;
  canIssueLateWarning: boolean;
  canIssueAttendanceWarning: boolean;
}

export interface StaffPerformanceAnalytics {
  staffId: string;
  staffName: string;
  role: string;
  department?: string;
  position?: string;
  supervisorStaffId?: string;
  periodDays: number;
  attendance: {
    total: number;
    onTime: number;
    late: number;
    rate: number;
  };
  leave: {
    approved: number;
    rejected: number;
    pending: number;
    daysApproved: number;
  };
  overtime: {
    approved: number;
    rejected: number;
    pending: number;
    hoursApproved: number;
  };
  warnings: { count: number };
  performanceScore: number;
  performanceGrade: string;
  onTimeRatio: number;
  eligibleLateWarning: boolean;
  eligibleUnsatisfactoryWarning: boolean;
}

export interface StaffPerformanceSummary {
  staffId: string;
  staffName: string;
  role: string;
  performanceScore: number;
  performanceGrade: string;
  attendance: {
    total: number;
    onTime: number;
    late: number;
    rate: number;
  };
}

export interface PerformanceOverview {
  periodDays: number;
  staff: StaffPerformanceSummary[];
}

export interface AccessLogEntry {
  _id: string;
  staffId: string;
  name: string;
  email: string;
  role: string;
  action: "login" | "logout" | "login_failed";
  platform: "cms" | "mobile" | "unknown";
  ipAddress?: string;
  userAgent?: string;
  success: boolean;
  createdAt: string;
}

export interface AccessLogResult {
  periodDays: number;
  total: number;
  logs: AccessLogEntry[];
}

export interface OvertimeRequest {
  _id: string;
  staffId: string;
  staffName?: string;
  otDate: string;
  hours: number;
  reason?: string;
  status: "pending" | "approved" | "rejected";
  flow?: Array<{ at: string; action: string; actorRole?: string; note?: string }>;
}
