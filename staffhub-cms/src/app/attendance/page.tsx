"use client";

import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { AttendanceDashboardStats } from "@/components/dashboard/AttendanceDashboardStats";
import { Card } from "@/components/ui/Card";
import { Input, Label } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { api } from "@/lib/api";
import { isDateInRange, localDateInput } from "@/lib/dateRange";
import type { AttendanceRecord, AttendanceReportStats, LeaveRequest, OvertimeRequest } from "@/lib/types";

export default function AttendancePage() {
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [stats, setStats] = useState<AttendanceReportStats>({ total: 0, onTime: 0, late: 0 });
  const [leaveCount, setLeaveCount] = useState(0);
  const [overtimeCount, setOvertimeCount] = useState(0);
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() - 30);
    return localDateInput(d);
  });
  const [endDate, setEndDate] = useState(() => localDateInput());
  const [staffId, setStaffId] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    setError("");
    const rangeStart = new Date(`${startDate}T00:00:00`);
    const rangeEnd = new Date(`${endDate}T23:59:59`);

    const [attRes, leaveRes, otRes] = await Promise.all([
      api.getAttendanceReport({ startDate, endDate, staffId: staffId || undefined }),
      api.getLeaveRequests(),
      api.getOvertimeRequests(),
    ]);

    if (attRes.success && attRes.data) {
      setRecords(attRes.data.report);
      setStats(attRes.data.stats);
    } else {
      setRecords([]);
      setStats({ total: 0, onTime: 0, late: 0 });
      setError(attRes.message || "Failed to load attendance. Make sure you are signed in as admin and the API is running.");
    }

    if (leaveRes.success && leaveRes.data) {
      setLeaveCount(
        leaveRes.data.filter((r: LeaveRequest) => isDateInRange(r.startDate, rangeStart, rangeEnd) || isDateInRange(r.createdAt, rangeStart, rangeEnd)).length,
      );
    } else {
      setLeaveCount(0);
    }

    if (otRes.success && otRes.data) {
      setOvertimeCount(
        otRes.data.filter((r: OvertimeRequest) => isDateInRange(r.otDate, rangeStart, rangeEnd)).length,
      );
    } else {
      setOvertimeCount(0);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const periodLabel = `${startDate} → ${endDate}`;

  return (
    <DashboardLayout title="Attendance Report">
      <div className="mb-6">
        <AttendanceDashboardStats
          periodLabel={periodLabel}
          metrics={{
            attendance: stats,
            leaveCount,
            overtimeCount,
          }}
        />
      </div>

      <Card className="mb-6">
        <div className="flex flex-wrap items-end gap-4">
          <div>
            <Label>Start Date</Label>
            <Input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
          </div>
          <div>
            <Label>End Date</Label>
            <Input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
          </div>
          <div>
            <Label>Staff ID (optional)</Label>
            <Input value={staffId} onChange={(e) => setStaffId(e.target.value)} placeholder="STF001" />
          </div>
          <Button onClick={load} disabled={loading}>
            {loading ? "Loading…" : "Filter"}
          </Button>
        </div>
      </Card>

      {error && (
        <div className="mb-4 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff</th>
                <th className="pb-3 pr-4">Date</th>
                <th className="pb-3 pr-4">Clock In</th>
                <th className="pb-3 pr-4">Clock Out</th>
                <th className="pb-3 pr-4">Status</th>
                <th className="pb-3">Location</th>
              </tr>
            </thead>
            <tbody>
              {records.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-500">
                    No records found for this period
                  </td>
                </tr>
              ) : (
                records.map((r) => (
                  <tr key={r._id} className="border-b border-slate-800">
                    <td className="py-3 pr-4">
                      <p className="font-mono text-blue-300">{r.staffId}</p>
                      {r.staffName ? <p className="text-xs text-slate-500">{r.staffName}</p> : null}
                    </td>
                    <td className="py-3 pr-4 text-white">{new Date(r.date).toLocaleDateString()}</td>
                    <td className="py-3 pr-4 text-slate-300">
                      {r.clockInTime || (r.clockIn ? new Date(r.clockIn).toLocaleTimeString() : "—")}
                    </td>
                    <td className="py-3 pr-4 text-slate-300">
                      {r.clockOutTime || (r.clockOut ? new Date(r.clockOut).toLocaleTimeString() : "—")}
                    </td>
                    <td className="py-3 pr-4">
                      {r.status === "late" ? (
                        <span className="rounded-full bg-amber-500/15 px-2 py-0.5 text-xs font-medium text-amber-400">Late</span>
                      ) : (
                        <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-xs font-medium text-emerald-400">On time</span>
                      )}
                    </td>
                    <td className="py-3 text-xs text-slate-500">
                      {r.clockInLocation ? `${r.clockInLocation.lat.toFixed(4)}, ${r.clockInLocation.lng.toFixed(4)}` : "—"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </DashboardLayout>
  );
}
