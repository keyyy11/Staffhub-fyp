"use client";

import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card } from "@/components/ui/Card";
import { Input, Label } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { api } from "@/lib/api";
import type { AttendanceRecord } from "@/lib/types";

export default function AttendancePage() {
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [startDate, setStartDate] = useState(() => {
    const d = new Date(); d.setDate(d.getDate() - 30); return d.toISOString().slice(0, 10);
  });
  const [endDate, setEndDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [staffId, setStaffId] = useState("");

  const load = async () => {
    const res = await api.getAttendanceReport({ startDate, endDate, staffId: staffId || undefined });
    if (res.success && res.data) setRecords(res.data);
  };

  useEffect(() => { load(); }, []);

  return (
    <DashboardLayout title="Attendance Report">
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
          <Button onClick={load}>Filter</Button>
        </div>
      </Card>

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff ID</th>
                <th className="pb-3 pr-4">Date</th>
                <th className="pb-3 pr-4">Clock In</th>
                <th className="pb-3 pr-4">Clock Out</th>
                <th className="pb-3">Location</th>
              </tr>
            </thead>
            <tbody>
              {records.length === 0 ? (
                <tr><td colSpan={5} className="py-8 text-center text-slate-500">No records found</td></tr>
              ) : records.map((r) => (
                <tr key={r._id} className="border-b border-slate-800">
                  <td className="py-3 pr-4 font-mono text-blue-300">{r.staffId}</td>
                  <td className="py-3 pr-4 text-white">{new Date(r.date).toLocaleDateString()}</td>
                  <td className="py-3 pr-4 text-slate-300">{r.clockIn ? new Date(r.clockIn).toLocaleTimeString() : "—"}</td>
                  <td className="py-3 pr-4 text-slate-300">{r.clockOut ? new Date(r.clockOut).toLocaleTimeString() : "—"}</td>
                  <td className="py-3 text-xs text-slate-500">
                    {r.clockInLocation ? `${r.clockInLocation.lat.toFixed(4)}, ${r.clockInLocation.lng.toFixed(4)}` : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </DashboardLayout>
  );
}
