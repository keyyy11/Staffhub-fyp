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
  date: string;
  clockIn?: string;
  clockOut?: string;
  clockInLocation?: { lat: number; lng: number };
  clockOutLocation?: { lat: number; lng: number };
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
