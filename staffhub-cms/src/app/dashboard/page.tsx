"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import type { AttendanceRecord, LeaveRequest, OvertimeRequest, StaffMember } from "@/lib/types";

export default function DashboardPage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [leave, setLeave] = useState<LeaveRequest[]>([]);
  const [ot, setOt] = useState<OvertimeRequest[]>([]);
  const [attendance, setAttendance] = useState<AttendanceRecord[]>([]);

  useEffect(() => {
    const load = async () => {
      const end = new Date();
      const start = new Date();
      start.setDate(start.getDate() - 7);
      const [staffRes, leaveRes, otRes, attRes] = await Promise.all([
        api.getStaffList(),
        api.getLeaveRequests("pending"),
        api.getOvertimeRequests("pending"),
        api.getAttendanceReport({
          startDate: start.toISOString().slice(0, 10),
          endDate: end.toISOString().slice(0, 10),
        }),
      ]);
      if (staffRes.success && staffRes.data) setStaff(staffRes.data);
      if (leaveRes.success && leaveRes.data) setLeave(leaveRes.data);
      if (otRes.success && otRes.data) setOt(otRes.data);
      if (attRes.success && attRes.data) setAttendance(attRes.data);
    };
    load();
  }, []);

  const stats = [
    { label: "Total Staff", value: staff.filter((s) => s.role === "staff").length, href: "/staff" },
    { label: "Supervisors", value: staff.filter((s) => s.role === "supervisor").length, href: "/staff" },
    { label: "Pending Leave", value: leave.length, href: "/leave" },
    { label: "Pending OT", value: ot.length, href: "/overtime" },
    { label: "Attendance (7d)", value: attendance.length, href: "/attendance" },
  ];

  return (
    <DashboardLayout title="Dashboard">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        {stats.map((s) => (
          <Link key={s.label} href={s.href}>
            <Card className="transition hover:border-blue-500/50">
              <p className="text-sm text-slate-400">{s.label}</p>
              <p className="mt-1 text-3xl font-bold text-white">{s.value}</p>
            </Card>
          </Link>
        ))}
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>Pending Leave Requests</CardTitle>
          {leave.length === 0 ? (
            <p className="text-sm text-slate-500">No pending requests</p>
          ) : (
            <ul className="space-y-3">
              {leave.slice(0, 5).map((r) => (
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
          <CardTitle>Recent Attendance (7 days)</CardTitle>
          {attendance.length === 0 ? (
            <p className="text-sm text-slate-500">No records</p>
          ) : (
            <ul className="space-y-3">
              {attendance.slice(0, 5).map((a) => (
                <li key={a._id} className="flex items-center justify-between rounded-lg bg-slate-800/50 px-3 py-2">
                  <div>
                    <p className="text-sm font-medium text-white">{a.staffId}</p>
                    <p className="text-xs text-slate-400">{new Date(a.date).toLocaleDateString()}</p>
                  </div>
                  <p className="text-xs text-slate-400">
                    {a.clockIn ? new Date(a.clockIn).toLocaleTimeString() : "—"}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </DashboardLayout>
  );
}
