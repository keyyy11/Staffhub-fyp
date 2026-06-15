"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label, Select } from "@/components/ui/Input";
import { StaffPerformancePanel } from "@/components/staff/StaffPerformancePanel";
import { api } from "@/lib/api";
import type { Branch, StaffMember } from "@/lib/types";

export default function StaffEditPage() {
  const { staffId } = useParams<{ staffId: string }>();
  const router = useRouter();
  const [staff, setStaff] = useState<StaffMember | null>(null);
  const [allStaff, setAllStaff] = useState<StaffMember[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [message, setMessage] = useState("");
  const [form, setForm] = useState({
    name: "", email: "", phone: "", department: "", position: "",
    branchCode: "", supervisorStaffId: "", newPassword: "", salary: "",
  });

  useEffect(() => {
    const load = async () => {
      const [staffRes, branchRes] = await Promise.all([api.getStaffList(), api.getBranches()]);
      if (staffRes.success && staffRes.data) {
        setAllStaff(staffRes.data);
        const found = staffRes.data.find((s) => s.staffId === staffId);
        if (found) {
          setStaff(found);
          setForm({
            name: found.name || "",
            email: found.email || "",
            phone: found.phone || "",
            department: found.department || "",
            position: found.position || "",
            branchCode: found.branchCode || "",
            supervisorStaffId: found.supervisorStaffId || "",
            newPassword: "",
            salary: String(found.salary ?? ""),
          });
        }
      }
      if (branchRes.success && branchRes.data) setBranches(branchRes.data);
    };
    load();
  }, [staffId]);

  const handleSave = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    const res = await api.updateStaff(staffId, {
      name: form.name,
      email: form.email,
      phone: form.phone,
      department: form.department,
      position: form.position,
      branchCode: form.branchCode || "",
      ...(form.newPassword ? { newPassword: form.newPassword } : {}),
    });
    if (!res.success) {
      setMessage(res.message || "Update failed");
      return;
    }
    if (staff?.role === "staff" && form.supervisorStaffId !== (staff.supervisorStaffId || "")) {
      await api.assignSupervisor(staffId, form.supervisorStaffId);
    }
    if (form.salary) {
      await api.updateSalary(staffId, Number(form.salary));
    }
    setMessage("Saved successfully");
  };

  if (!staff) {
    return (
      <DashboardLayout title="Edit Staff">
        <p className="text-slate-400">Loading...</p>
      </DashboardLayout>
    );
  }

  const supervisors = allStaff.filter((s) => s.role === "supervisor" && s.staffId !== staffId);

  return (
    <DashboardLayout title={`Edit — ${staffId}`}>
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">
          {message}
        </div>
      )}

      <Card className="mb-6">
        <CardTitle>{staff.name} ({staff.role})</CardTitle>
        <form onSubmit={handleSave} className="grid gap-4 sm:grid-cols-2">
          <div><Label>Name</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
          <div><Label>Email</Label><Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></div>
          <div><Label>Phone</Label><Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></div>
          <div><Label>Department</Label><Input value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} /></div>
          <div><Label>Position</Label><Input value={form.position} onChange={(e) => setForm({ ...form, position: e.target.value })} /></div>
          <div>
            <Label>Branch</Label>
            <Select value={form.branchCode} onChange={(e) => setForm({ ...form, branchCode: e.target.value })}>
              <option value="">No branch</option>
              {branches.map((b) => <option key={b.branchCode} value={b.branchCode}>{b.branchCode} — {b.name}</option>)}
            </Select>
          </div>
          {staff.role === "staff" && (
            <div>
              <Label>Supervisor</Label>
              <Select value={form.supervisorStaffId} onChange={(e) => setForm({ ...form, supervisorStaffId: e.target.value })}>
                <option value="">None</option>
                {supervisors.map((s) => <option key={s.staffId} value={s.staffId}>{s.staffId} — {s.name}</option>)}
              </Select>
            </div>
          )}
          <div><Label>Monthly Salary (RM)</Label><Input type="number" value={form.salary} onChange={(e) => setForm({ ...form, salary: e.target.value })} /></div>
          <div><Label>New Password (optional)</Label><Input type="password" value={form.newPassword} onChange={(e) => setForm({ ...form, newPassword: e.target.value })} /></div>
          <div className="flex gap-3 sm:col-span-2">
            <Button type="submit">Save Changes</Button>
            <Button type="button" variant="ghost" onClick={() => router.push("/staff")}>Back</Button>
          </div>
        </form>
      </Card>

      <StaffPerformancePanel staffId={staffId} staffName={staff.name} />
    </DashboardLayout>
  );
}
