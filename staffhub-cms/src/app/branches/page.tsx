"use client";

import { FormEvent, useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import type { Branch } from "@/lib/types";

const emptyForm = {
  branchCode: "", name: "", address: "", lat: "", lng: "", radiusMeters: "60", isActive: true,
};

export default function BranchesPage() {
  const [branches, setBranches] = useState<Branch[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [editing, setEditing] = useState<string | null>(null);
  const [message, setMessage] = useState("");

  const load = async () => {
    const res = await api.getBranches();
    if (res.success && res.data) setBranches(res.data);
  };

  useEffect(() => { load(); }, []);

  const useDefaultLocation = async () => {
    const res = await api.getWorkplace();
    if (res.success && res.data) {
      setForm((f) => ({
        ...f,
        lat: String(res.data!.lat),
        lng: String(res.data!.lng),
        radiusMeters: String(res.data!.radiusMeters),
      }));
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    const body = {
      branchCode: form.branchCode.toUpperCase(),
      name: form.name,
      address: form.address,
      lat: Number(form.lat),
      lng: Number(form.lng),
      radiusMeters: Number(form.radiusMeters),
      isActive: form.isActive,
    };
    const res = editing
      ? await api.updateBranch(editing, body)
      : await api.createBranch(body);
    if (!res.success) {
      setMessage(res.message || "Failed");
      return;
    }
    setMessage(editing ? "Branch updated" : "Branch created");
    setForm(emptyForm);
    setEditing(null);
    load();
  };

  const startEdit = (b: Branch) => {
    setEditing(b.branchCode);
    setForm({
      branchCode: b.branchCode,
      name: b.name,
      address: b.address || "",
      lat: String(b.lat),
      lng: String(b.lng),
      radiusMeters: String(b.radiusMeters),
      isActive: b.isActive,
    });
  };

  const handleDelete = async (code: string) => {
    if (!confirm(`Delete branch ${code}?`)) return;
    const res = await api.deleteBranch(code);
    setMessage(res.success ? "Deleted" : res.message || "Failed");
    load();
  };

  return (
    <DashboardLayout title="Branches">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">{message}</div>
      )}

      <Card className="mb-6">
        <CardTitle>{editing ? `Edit ${editing}` : "Add Branch"}</CardTitle>
        <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2">
          <div>
            <Label>Branch Code</Label>
            <Input value={form.branchCode} onChange={(e) => setForm({ ...form, branchCode: e.target.value })} required disabled={!!editing} />
          </div>
          <div>
            <Label>Name</Label>
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
          </div>
          <div className="sm:col-span-2">
            <Label>Address</Label>
            <Input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          </div>
          <div>
            <Label>Latitude</Label>
            <Input type="number" step="any" value={form.lat} onChange={(e) => setForm({ ...form, lat: e.target.value })} required />
          </div>
          <div>
            <Label>Longitude</Label>
            <Input type="number" step="any" value={form.lng} onChange={(e) => setForm({ ...form, lng: e.target.value })} required />
          </div>
          <div>
            <Label>Radius (meters)</Label>
            <Input type="number" value={form.radiusMeters} onChange={(e) => setForm({ ...form, radiusMeters: e.target.value })} />
          </div>
          <div className="flex items-end gap-2">
            <label className="flex items-center gap-2 text-sm text-slate-300">
              <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />
              Active
            </label>
          </div>
          <div className="flex gap-2 sm:col-span-2">
            <Button type="submit">{editing ? "Update" : "Create"}</Button>
            <Button type="button" variant="secondary" onClick={useDefaultLocation}>Use HQ location</Button>
            {editing && <Button type="button" variant="ghost" onClick={() => { setEditing(null); setForm(emptyForm); }}>Cancel</Button>}
          </div>
        </form>
      </Card>

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Code</th>
                <th className="pb-3 pr-4">Name</th>
                <th className="pb-3 pr-4">GPS</th>
                <th className="pb-3 pr-4">Radius</th>
                <th className="pb-3 pr-4">Status</th>
                <th className="pb-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {branches.map((b) => (
                <tr key={b.branchCode} className="border-b border-slate-800">
                  <td className="py-3 pr-4 font-mono text-blue-300">{b.branchCode}</td>
                  <td className="py-3 pr-4 text-white">{b.name}</td>
                  <td className="py-3 pr-4 text-slate-400">{b.lat.toFixed(5)}, {b.lng.toFixed(5)}</td>
                  <td className="py-3 pr-4 text-slate-400">{b.radiusMeters}m</td>
                  <td className="py-3 pr-4"><Badge status={b.isActive ? "active" : "inactive"} /></td>
                  <td className="py-3">
                    <div className="flex gap-2">
                      <Button variant="ghost" className="!px-2 !py-1 text-xs" onClick={() => startEdit(b)}>Edit</Button>
                      {b.branchCode !== "HQ" && (
                        <Button variant="danger" className="!px-2 !py-1 text-xs" onClick={() => handleDelete(b.branchCode)}>Delete</Button>
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
