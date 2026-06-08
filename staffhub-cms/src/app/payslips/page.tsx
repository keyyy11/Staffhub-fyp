"use client";

import { FormEvent, useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label, Select } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { PayslipRecord, StaffMember } from "@/lib/types";

export default function PayslipsPage() {
  const [records, setRecords] = useState<PayslipRecord[]>([]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [message, setMessage] = useState("");
  const now = new Date();
  const [form, setForm] = useState({
    staffId: "", year: String(now.getFullYear()), month: String(now.getMonth() + 1),
    netPay: "", grossPay: "", remarks: "",
  });

  const load = async () => {
    const [recRes, staffRes] = await Promise.all([api.getPayslipRecords(), api.getStaffList()]);
    if (recRes.success && recRes.data) setRecords(recRes.data);
    if (staffRes.success && staffRes.data) setStaff(staffRes.data);
  };

  useEffect(() => { load(); }, []);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    const res = await api.upsertPayslip({
      staffId: form.staffId,
      year: Number(form.year),
      month: Number(form.month),
      netPay: Number(form.netPay),
      grossPay: form.grossPay ? Number(form.grossPay) : undefined,
      remarks: form.remarks,
    });
    setMessage(res.success ? "Payslip saved" : res.message || "Failed");
    if (res.success) load();
  };

  return (
    <DashboardLayout title="Payslips">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">{message}</div>
      )}

      <Card className="mb-6">
        <CardTitle>Issue Payslip</CardTitle>
        <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-3">
          <div>
            <Label>Staff</Label>
            <Select value={form.staffId} onChange={(e) => setForm({ ...form, staffId: e.target.value })} required>
              <option value="">Select staff</option>
              {staff.map((s) => <option key={s.staffId} value={s.staffId}>{s.staffId} — {s.name}</option>)}
            </Select>
          </div>
          <div><Label>Year</Label><Input type="number" value={form.year} onChange={(e) => setForm({ ...form, year: e.target.value })} required /></div>
          <div><Label>Month</Label><Input type="number" min="1" max="12" value={form.month} onChange={(e) => setForm({ ...form, month: e.target.value })} required /></div>
          <div><Label>Net Pay (RM)</Label><Input type="number" value={form.netPay} onChange={(e) => setForm({ ...form, netPay: e.target.value })} required /></div>
          <div><Label>Gross Pay (RM)</Label><Input type="number" value={form.grossPay} onChange={(e) => setForm({ ...form, grossPay: e.target.value })} /></div>
          <div><Label>Remarks</Label><Input value={form.remarks} onChange={(e) => setForm({ ...form, remarks: e.target.value })} /></div>
          <div className="sm:col-span-3"><Button type="submit">Save Payslip</Button></div>
        </form>
      </Card>

      <Card>
        <CardTitle>Recent Payslips</CardTitle>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff</th>
                <th className="pb-3 pr-4">Period</th>
                <th className="pb-3 pr-4">Net Pay</th>
                <th className="pb-3">Remarks</th>
              </tr>
            </thead>
            <tbody>
              {records.map((r) => (
                <tr key={r._id} className="border-b border-slate-800">
                  <td className="py-3 pr-4 font-mono text-blue-300">{r.staffId}</td>
                  <td className="py-3 pr-4 text-white">{r.month}/{r.year}</td>
                  <td className="py-3 pr-4 text-emerald-300">RM {r.netPay}</td>
                  <td className="py-3 text-slate-400">{r.remarks || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </DashboardLayout>
  );
}
