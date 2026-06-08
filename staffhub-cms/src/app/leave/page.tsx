"use client";

import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Select } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { LeaveRequest } from "@/lib/types";

export default function LeavePage() {
  const [requests, setRequests] = useState<LeaveRequest[]>([]);
  const [filter, setFilter] = useState("");
  const [message, setMessage] = useState("");
  const [mcImage, setMcImage] = useState<string | null>(null);

  const load = async () => {
    const res = await api.getLeaveRequests(filter || undefined);
    if (res.success && res.data) setRequests(res.data);
  };

  useEffect(() => { load(); }, [filter]);

  const handleDecision = async (id: string, status: "approved" | "rejected") => {
    const comment = prompt(`Comment for ${status} (optional):`) || "";
    const res = await api.updateLeaveStatus(id, status, comment);
    setMessage(res.success ? `Leave ${status}` : res.message || "Failed");
    load();
  };

  const viewMc = async (id: string) => {
    const res = await api.getMcLetter(id);
    if (res.success && res.data?.mcLetter) {
      setMcImage(res.data.mcLetter);
    } else {
      setMessage("No MC letter attached");
    }
  };

  return (
    <DashboardLayout title="Leave Requests">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">{message}</div>
      )}

      <div className="mb-6">
        <Select value={filter} onChange={(e) => setFilter(e.target.value)} className="w-48">
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </Select>
      </div>

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff</th>
                <th className="pb-3 pr-4">Type</th>
                <th className="pb-3 pr-4">Dates</th>
                <th className="pb-3 pr-4">Days</th>
                <th className="pb-3 pr-4">Status</th>
                <th className="pb-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {requests.map((r) => (
                <tr key={r._id} className="border-b border-slate-800">
                  <td className="py-3 pr-4">
                    <p className="text-white">{r.staffName || r.staffId}</p>
                    <p className="text-xs text-slate-500">{r.reason}</p>
                  </td>
                  <td className="py-3 pr-4 capitalize text-slate-300">{r.leaveType}</td>
                  <td className="py-3 pr-4 text-slate-400">
                    {new Date(r.startDate).toLocaleDateString()} – {new Date(r.endDate).toLocaleDateString()}
                  </td>
                  <td className="py-3 pr-4 text-slate-400">{r.totalDays}</td>
                  <td className="py-3 pr-4"><Badge status={r.status} /></td>
                  <td className="py-3">
                    <div className="flex flex-wrap gap-2">
                      {r.status === "pending" && (
                        <>
                          <Button className="!px-2 !py-1 text-xs" onClick={() => handleDecision(r._id, "approved")}>Approve</Button>
                          <Button variant="danger" className="!px-2 !py-1 text-xs" onClick={() => handleDecision(r._id, "rejected")}>Reject</Button>
                        </>
                      )}
                      {r.hasMcLetter && (
                        <Button variant="ghost" className="!px-2 !py-1 text-xs" onClick={() => viewMc(r._id)}>View MC</Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {mcImage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onClick={() => setMcImage(null)}>
          <img src={mcImage} alt="MC Letter" className="max-h-[90vh] max-w-full rounded-lg" />
        </div>
      )}
    </DashboardLayout>
  );
}
