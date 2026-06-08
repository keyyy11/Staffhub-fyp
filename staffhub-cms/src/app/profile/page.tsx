"use client";

import { FormEvent, useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { AuthUser } from "@/lib/types";

export default function ProfilePage() {
  const [profile, setProfile] = useState<AuthUser & { phone?: string; department?: string; position?: string } | null>(null);
  const [message, setMessage] = useState("");
  const [form, setForm] = useState({ name: "", phone: "", department: "", position: "" });

  useEffect(() => {
    api.getMe().then((res) => {
      if (res.success && res.data) {
        const d = res.data as typeof profile;
        setProfile(d);
        setForm({
          name: d?.name || "",
          phone: d?.phone || "",
          department: d?.department || "",
          position: d?.position || "",
        });
      }
    });
  }, []);

  const handleSave = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    const res = await api.updateMe(form);
    setMessage(res.success ? "Profile updated" : res.message || "Failed");
  };

  return (
    <DashboardLayout title="Admin Profile">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">{message}</div>
      )}

      <Card className="max-w-lg">
        <CardTitle>{profile?.name || "Profile"}</CardTitle>
        <p className="mb-4 text-sm text-slate-400">{profile?.staffId} · {profile?.email}</p>
        <form onSubmit={handleSave} className="space-y-4">
          <div><Label>Name</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
          <div><Label>Phone</Label><Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></div>
          <div><Label>Department</Label><Input value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} /></div>
          <div><Label>Position</Label><Input value={form.position} onChange={(e) => setForm({ ...form, position: e.target.value })} /></div>
          <Button type="submit">Save Profile</Button>
        </form>
      </Card>
    </DashboardLayout>
  );
}
