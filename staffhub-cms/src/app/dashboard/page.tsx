"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { AttendanceDashboardStats } from "@/components/dashboard/AttendanceDashboardStats";
import { StaffPerformanceOverview } from "@/components/dashboard/StaffPerformanceOverview";
import { Card, CardTitle } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import { isDateInRange, lastNDaysRange } from "@/lib/dateRange";
import type { AttendanceRecord, AttendanceReportStats, LeaveRequest, OvertimeRequest, StaffMember } from "@/lib/types";

const PERIOD_DAYS = 30;

export default function DashboardPage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [leave, setLeave] = useState<LeaveRequest[]>([]);
  const [ot, setOt] = useState<OvertimeRequest[]>([]);
  const [attendance, setAttendance] = useState<AttendanceRecord[]>([]);
  const [attendanceStats, setAttendanceStats] = useState<AttendanceReportStats>({ total: 0, onTime: 0, late: 0 });
  const [leaveInPeriod, setLeaveInPeriod] = useState(0);
  const [otInPeriod, setOtInPeriod] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const { start, end, startDate, endDate } = lastNDaysRange(PERIOD_DAYS);

      const [staffRes, leaveRes, otRes, attRes] = await Promise.all([
        api.getStaffList(),
        api.getLeaveRequests(),
        api.getOvertimeRequests(),
        api.getAttendanceReport({ startDate, endDate }),
      ]);

      if (staffRes.success && staffRes.data) setStaff(staffRes.data);
      if (leaveRes.success && leaveRes.data) {
        setLeave(leaveRes.data);
        setLeaveInPeriod(
          leaveRes.data.filter((r) => isDateInRange(r.startDate, start, end) || isDateInRange(r.createdAt, start, end)).length,
        );
      }
      if (otRes.success && otRes.data) {
        setOt(otRes.data);
        setOtInPeriod(otRes.data.filter((r) => isDateInRange(r.otDate, start, end)).length);
      }
      if (attRes.success && attRes.data) {
        setAttendance(attRes.data.report);
        setAttendanceStats(attRes.data.stats);
      }
      setLoading(false);
    };
    load();
  }, []);

  const pendingLeave = leave.filter((r) => r.status === "pending");
  const pendingOt = ot.filter((r) => r.status === "pending");

  const opsStats = [
    { label: "Total Staff", value: staff.filter((s) => s.role === "staff").length, href: "/staff" },
    { label: "Supervisors", value: staff.filter((s) => s.role === "supervisor").length, href: "/staff" },
    { label: "Pending Leave", value: pendingLeave.length, href: "/leave" },
    { label: "Pending OT", value: pendingOt.length, href: "/overtime" },
  ];

  return (
    <DashboardLayout title="Dashboard">
      {loading ? (
        <div className="mb-8 rounded-2xl border border-slate-700/60 bg-slate-900/50 p-12 text-center text-slate-400">
          Loading attendance dashboard…
        </div>
      ) : (
        <div className="mb-10">
          <AttendanceDashboardStats
            periodLabel={`Last ${PERIOD_DAYS} days`}
            metrics={{
              attendance: attendanceStats,
              leaveCount: leaveInPeriod,
              overtimeCount: otInPeriod,
            }}
          />
        </div>
      )}

      {!loading ? <StaffPerformanceOverview /> : null}

      <div className="mb-8">
        <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Operations</h3>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {opsStats.map((s) => (
            <Link key={s.label} href={s.href}>
              <Card className="transition hover:border-blue-500/50">
                <p className="text-sm text-slate-400">{s.label}</p>
                <p className="mt-1 text-2xl font-bold text-white">{s.value}</p>
              </Card>
            </Link>
          ))}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>Pending Leave Requests</CardTitle>
          {pendingLeave.length === 0 ? (
            <p className="text-sm text-slate-500">No pending requests</p>
          ) : (
            <ul className="space-y-3">
              {pendingLeave.slice(0, 5).map((r) => (
                <li key={r._id} className="flex items-center justify-between rounded-lg bg-slate-800/50 px-3 py-2">
                  <div>
                    <p className="text-sm font-medium text-white">{r.staffName || r.staffId}</p>
                    <p className="text-xs text-slate-400">{r.leaveType} · {r.totalDays} day(s)</p>
                  </div>
                  <Badge status={r.status} />
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card>
          <CardTitle>Recent Attendance</CardTitle>
          {attendance.length === 0 ? (
            <p className="text-sm text-slate-500">No records in the last {PERIOD_DAYS} days</p>
          ) : (
            <ul className="space-y-3">
              {attendance.slice(0, 5).map((a) => (
                <li key={a._id} className="flex items-center justify-between rounded-lg bg-slate-800/50 px-3 py-2">
                  <div>
                    <p className="text-sm font-medium text-white">{a.staffName || a.staffId}</p>
                    <p className="text-xs text-slate-400">{new Date(a.date).toLocaleDateString()}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-slate-400">
                      {a.clockIn ? new Date(a.clockIn).toLocaleTimeString() : "—"}
                    </p>
                    {a.status === "late" ? (
                      <span className="text-xs font-medium text-amber-400">Late</span>
                    ) : (
                      <span className="text-xs font-medium text-emerald-400">On time</span>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </DashboardLayout>
  );
}
