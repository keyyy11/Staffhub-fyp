"use client";

import { FormEvent, useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label, Select, Textarea } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { DisciplineMetrics, StaffMember, WarningLetter } from "@/lib/types";

const categories = [
  { value: "late_five_times", label: "Late 5 times" },
  { value: "attendance_leave_unsatisfactory", label: "Unsatisfactory attendance/leave" },
  { value: "other", label: "Other" },
];

export default function DisciplinePage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [warnings, setWarnings] = useState<WarningLetter[]>([]);
  const [metrics, setMetrics] = useState<DisciplineMetrics | null>(null);
  const [selectedStaff, setSelectedStaff] = useState("");
  const [message, setMessage] = useState("");
  const [form, setForm] = useState({ category: "late_five_times", notes: "" });

  useEffect(() => {
    api.getStaffList().then((res) => {
      if (res.success && res.data) setStaff(res.data.filter((s) => s.role === "staff"));
    });
    api.getWarnings().then((res) => { if (res.success && res.data) setWarnings(res.data); });
  }, []);

  useEffect(() => {
    if (!selectedStaff) { setMetrics(null); return; }
    api.getDisciplineMetrics(selectedStaff).then((res) => {
      if (res.success && res.data) setMetrics(res.data);
    });
    api.getWarnings(selectedStaff).then((res) => {
      if (res.success && res.data) setWarnings(res.data);
    });
  }, [selectedStaff]);

  const handleIssue = async (e: FormEvent) => {
    e.preventDefault();
    if (!selectedStaff) return;
    setMessage("");
    const res = await api.createWarning({ staffId: selectedStaff, category: form.category, notes: form.notes });
    setMessage(res.success ? "Warning issued" : res.message || "Failed");
    if (res.success) {
      setForm({ category: "late_five_times", notes: "" });
      const wRes = await api.getWarnings(selectedStaff);
      if (wRes.success && wRes.data) setWarnings(wRes.data);
    }
  };

  return (
    <DashboardLayout title="Discipline & Warnings">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">{message}</div>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>Select Staff</CardTitle>
          <Select value={selectedStaff} onChange={(e) => setSelectedStaff(e.target.value)}>
            <option value="">Choose staff member</option>
            {staff.map((s) => <option key={s.staffId} value={s.staffId}>{s.staffId} — {s.name}</option>)}
          </Select>

          {metrics && (
            <div className="mt-4 grid grid-cols-2 gap-3">
              <div className="rounded-lg bg-slate-800/50 p-3">
                <p className="text-xs text-slate-400">Late (90d)</p>
                <p className="text-xl font-bold text-amber-300">{metrics.lateCount}</p>
              </div>
              <div className="rounded-lg bg-slate-800/50 p-3">
                <p className="text-xs text-slate-400">On-time ratio</p>
                <p className="text-xl font-bold text-emerald-300">{(metrics.onTimeRatio * 100).toFixed(0)}%</p>
              </div>
              <div className="rounded-lg bg-slate-800/50 p-3">
                <p className="text-xs text-slate-400">Rejected leave</p>
                <p className="text-xl font-bold text-red-300">{metrics.rejectedLeaveCount}</p>
              </div>
              <div className="rounded-lg bg-slate-800/50 p-3">
                <p className="text-xs text-slate-400">Can issue warning</p>
                <p className="text-sm text-white">
                  {metrics.canIssueLateWarning ? "Late ✓" : ""} {metrics.canIssueAttendanceWarning ? "Attendance ✓" : ""}
                </p>
              </div>
            </div>
          )}
        </Card>

        <Card>
          <CardTitle>Issue Warning</CardTitle>
          <form onSubmit={handleIssue} className="space-y-4">
            <div>
              <Label>Category</Label>
              <Select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {categories.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </Select>
            </div>
            <div>
              <Label>Notes</Label>
              <Textarea rows={4} value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} required />
            </div>
            <Button type="submit" disabled={!selectedStaff}>Issue Warning</Button>
          </form>
        </Card>
      </div>

      <Card className="mt-6">
        <CardTitle>Warning History</CardTitle>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff</th>
                <th className="pb-3 pr-4">Category</th>
                <th className="pb-3 pr-4">Notes</th>
                <th className="pb-3">Date</th>
              </tr>
            </thead>
            <tbody>
              {warnings.map((w) => (
                <tr key={w._id} className="border-b border-slate-800">
                  <td className="py-3 pr-4 text-white">{w.staffName || w.staffId}</td>
                  <td className="py-3 pr-4 text-slate-300">{w.category}</td>
                  <td className="py-3 pr-4 text-slate-400">{w.notes}</td>
                  <td className="py-3 text-slate-500">{w.createdAt ? new Date(w.createdAt).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </DashboardLayout>
  );
}
