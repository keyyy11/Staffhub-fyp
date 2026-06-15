import { clearAuth, getToken } from "./auth";
import type {
  ApiResponse,
  AttendanceRecord,
  AttendanceReportResult,
  AttendanceReportStats,
  AuthUser,
  Branch,
  DisciplineMetrics,
  StaffPerformanceAnalytics,
  PerformanceOverview,
  AccessLogResult,
  LeaveRequest,
  OvertimeRequest,
  PayslipRecord,
  StaffMember,
  WarningLetter,
} from "./types";

function resolveApiBase(): string {
  const configured = (process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000/api").replace(/\/$/, "");
  // Browser local dev: same-origin proxy (see next.config.ts rewrites) avoids PNA errors.
  if (typeof window !== "undefined" && process.env.NODE_ENV === "development") {
    return "/api-backend";
  }
  return configured;
}

const API_BASE = resolveApiBase();

async function request<T>(
  method: string,
  path: string,
  body?: Record<string, unknown>,
  auth = true,
): Promise<ApiResponse<T>> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(15000),
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes("abort") || msg.includes("timeout")) {
      return {
        success: false,
        message: `Cannot reach API at ${API_BASE}. Start staffhub-api (npm run dev) and try again.`,
      };
    }
    return {
      success: false,
      message: `Cannot reach API at ${API_BASE}. Start staffhub-api (npm run dev) and try again.`,
    };
  }

  let data: ApiResponse<T>;
  try {
    data = await res.json();
  } catch {
    return { success: false, message: `Non-JSON response (HTTP ${res.status})` };
  }

  if (res.status === 401 && auth) {
    clearAuth();
    if (typeof window !== "undefined") window.location.href = "/login";
  }

  return data;
}

export const api = {
  health: () => request<{ status: string }>("GET", "/health", undefined, false),

  login: (email: string, password: string) =>
    request<{ token: string; user: AuthUser }>("POST", "/auth/login", { email, password, platform: "cms" }, false),

  logoutAccess: () => request("POST", "/auth/logout", { platform: "cms" }),

  registerAdmin: (payload: {
    name: string;
    email: string;
    password: string;
    adminSecret: string;
    autoStaffId?: boolean;
  }) => request("POST", "/auth/register-admin", payload, false),

  getMe: () => request<AuthUser>("GET", "/admin/me"),
  updateMe: (body: Record<string, unknown>) => request("PUT", "/admin/me", body),

  getStaffList: () => request<StaffMember[]>("GET", "/admin/staff-list"),
  registerStaff: (body: Record<string, unknown>) => request("POST", "/admin/register-staff", body),
  updateStaff: (staffId: string, body: Record<string, unknown>) =>
    request("PUT", `/admin/staff/${encodeURIComponent(staffId)}`, body),
  updateSalary: (staffId: string, salary: number) =>
    request("PUT", `/admin/staff/${encodeURIComponent(staffId)}/salary`, { salary }),
  assignSupervisor: (staffId: string, supervisorStaffId: string) =>
    request("PUT", `/admin/staff/${encodeURIComponent(staffId)}/supervisor`, { supervisorStaffId }),
  promoteSupervisor: (staffId: string, newStaffId?: string) =>
    request("PUT", `/admin/staff/${encodeURIComponent(staffId)}/promote-supervisor`, {
      newStaffId: newStaffId || "auto",
    }),

  getBranches: () => request<Branch[]>("GET", "/admin/branches"),
  createBranch: (body: Record<string, unknown>) => request("POST", "/admin/branches", body),
  updateBranch: (branchCode: string, body: Record<string, unknown>) =>
    request("PUT", `/admin/branches/${encodeURIComponent(branchCode)}`, body),
  deleteBranch: (branchCode: string) =>
    request("DELETE", `/admin/branches/${encodeURIComponent(branchCode)}`),

  getAttendanceReport: async (params?: { startDate?: string; endDate?: string; staffId?: string }) => {
    const q = new URLSearchParams();
    if (params?.startDate) q.set("startDate", params.startDate);
    if (params?.endDate) q.set("endDate", params.endDate);
    if (params?.staffId) q.set("staffId", params.staffId);
    const qs = q.toString();
    const res = await request<AttendanceReportResult>(
      "GET",
      `/admin/attendance-report${qs ? `?${qs}` : ""}`,
    );
    if (!res.success || !res.data) return { success: false, message: res.message };
    return { success: true, message: res.message, data: res.data };
  },

  getLeaveRequests: (status?: string) => {
    const qs = status ? `?status=${status}` : "";
    return request<LeaveRequest[]>("GET", `/admin/leave-requests${qs}`);
  },
  updateLeaveStatus: (id: string, status: "approved" | "rejected", adminComment?: string) =>
    request("PUT", `/admin/leave-requests/${id}`, { status, adminComment }),
  getMcLetter: (id: string) => request<{ mcLetter: string }>("GET", `/admin/leave-requests/${id}/mc`),

  getPayslipRecords: (params?: { staffId?: string; year?: number; month?: number }) => {
    const q = new URLSearchParams();
    if (params?.staffId) q.set("staffId", params.staffId);
    if (params?.year) q.set("year", String(params.year));
    if (params?.month) q.set("month", String(params.month));
    const qs = q.toString();
    return request<PayslipRecord[]>("GET", `/admin/payslip-records${qs ? `?${qs}` : ""}`);
  },
  upsertPayslip: (body: Record<string, unknown>) => request("POST", "/admin/payslip-record", body),

  getDisciplineMetrics: (staffId: string, days = 90) =>
    request<DisciplineMetrics>("GET", `/admin/staff/${encodeURIComponent(staffId)}/discipline-metrics?days=${days}`),
  getStaffPerformance: (staffId: string, days = 90) =>
    request<StaffPerformanceAnalytics>("GET", `/admin/staff/${encodeURIComponent(staffId)}/performance?days=${days}`),
  getPerformanceOverview: (days = 30) =>
    request<PerformanceOverview>("GET", `/admin/performance-overview?days=${days}`),
  getAccessLogs: (params?: { days?: number; limit?: number; action?: string; platform?: string }) => {
    const q = new URLSearchParams();
    if (params?.days) q.set("days", String(params.days));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.action) q.set("action", params.action);
    if (params?.platform) q.set("platform", params.platform);
    const qs = q.toString();
    return request<AccessLogResult>("GET", `/admin/access-logs${qs ? `?${qs}` : ""}`);
  },
  getWarnings: (staffId?: string) => {
    const qs = staffId ? `?staffId=${encodeURIComponent(staffId)}` : "";
    return request<WarningLetter[]>("GET", `/admin/warnings${qs}`);
  },
  createWarning: (body: { staffId: string; category: string; notes: string }) =>
    request("POST", "/admin/warnings", body),

  getOvertimeRequests: (status?: string) => {
    const qs = status ? `?status=${status}` : "";
    return request<OvertimeRequest[]>("GET", `/admin/overtime-requests${qs}`);
  },

  getWorkplace: () => request<{ lat: number; lng: number; radiusMeters: number }>("GET", "/attendance/workplace", undefined, false),
};

export function getApiBaseUrl(): string {
  return typeof window !== "undefined" && process.env.NODE_ENV === "development"
    ? "/api-backend"
    : (process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000/api").replace(/\/$/, "");
}
