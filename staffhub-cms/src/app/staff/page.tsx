"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label, Select } from "@/components/ui/Input";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import type { Branch, StaffMember } from "@/lib/types";

export default function StaffPage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [message, setMessage] = useState("");
  const [form, setForm] = useState({ name: "", email: "", password: "", branchCode: "", autoStaffId: true });

  const load = async () => {
    const [staffRes, branchRes] = await Promise.all([api.getStaffList(), api.getBranches()]);
    if (staffRes.success && staffRes.data) setStaff(staffRes.data);
    if (branchRes.success && branchRes.data) setBranches(branchRes.data);
  };

  useEffect(() => { load(); }, []);

  const handleRegister = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    const res = await api.registerStaff({
      name: form.name,
      email: form.email,
      password: form.password,
      autoStaffId: true,
      ...(form.branchCode ? { branchCode: form.branchCode } : {}),
    });
    if (!res.success) {
      setMessage(res.message || "Failed to register staff");
      return;
    }
    setMessage("Staff registered successfully");
    setShowForm(false);
    setForm({ name: "", email: "", password: "", branchCode: "", autoStaffId: true });
    load();
  };

  const handlePromote = async (staffId: string) => {
    if (!confirm(`Promote ${staffId} to supervisor?`)) return;
    const res = await api.promoteSupervisor(staffId);
    setMessage(res.success ? "Promoted successfully" : res.message || "Failed");
    load();
  };

  return (
    <DashboardLayout title="Staff Management">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">
          {message}
        </div>
      )}

      <div className="mb-6 flex justify-between">
        <p className="text-slate-400">{staff.length} staff & supervisors</p>
        <Button onClick={() => setShowForm(!showForm)}>{showForm ? "Cancel" : "+ Register Staff"}</Button>
      </div>

      {showForm && (
        <Card className="mb-6">
          <CardTitle>Register New Staff</CardTitle>
          <form onSubmit={handleRegister} className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label>Name</Label>
              <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <Label>Email</Label>
              <Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required />
            </div>
            <div>
              <Label>Password</Label>
              <Input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required />
            </div>
            <div>
              <Label>Branch</Label>
              <Select value={form.branchCode} onChange={(e) => setForm({ ...form, branchCode: e.target.value })}>
                <option value="">No branch</option>
                {branches.map((b) => (
                  <option key={b.branchCode} value={b.branchCode}>{b.branchCode} — {b.name}</option>
                ))}
              </Select>
            </div>
            <div className="sm:col-span-2">
              <Button type="submit">Register Staff</Button>
            </div>
          </form>
        </Card>
      )}

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff ID</th>
                <th className="pb-3 pr-4">Name</th>
                <th className="pb-3 pr-4">Role</th>
                <th className="pb-3 pr-4">Branch</th>
                <th className="pb-3 pr-4">Supervisor</th>
                <th className="pb-3 pr-4">Salary</th>
                <th className="pb-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {staff.map((s) => (
                <tr key={s.staffId} className="border-b border-slate-800">
                  <td className="py-3 pr-4 font-mono text-blue-300">{s.staffId}</td>
                  <td className="py-3 pr-4 text-white">{s.name}</td>
                  <td className="py-3 pr-4"><Badge status={s.role} /></td>
                  <td className="py-3 pr-4 text-slate-400">{s.branchCode || "—"}</td>
                  <td className="py-3 pr-4 text-slate-400">{s.supervisorStaffId || "—"}</td>
                  <td className="py-3 pr-4 text-slate-400">RM {s.salary ?? 0}</td>
                  <td className="py-3">
                    <div className="flex flex-wrap gap-2">
                      <Link href={`/staff/${s.staffId}`}>
                        <Button variant="ghost" className="!px-2 !py-1 text-xs">Edit</Button>
                      </Link>
                      <Link href={`/staff/${s.staffId}/performance`}>
                        <Button variant="secondary" className="!px-2 !py-1 text-xs">Performance</Button>
                      </Link>
                      {s.role === "staff" && (
                        <Button variant="secondary" className="!px-2 !py-1 text-xs" onClick={() => handlePromote(s.staffId)}>
                          Promote
                        </Button>
                      )}
                    </div>
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
