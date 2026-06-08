"use client";

import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Select } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { OvertimeRequest } from "@/lib/types";

export default function OvertimePage() {
  const [requests, setRequests] = useState<OvertimeRequest[]>([]);
  const [filter, setFilter] = useState("");
  const [expanded, setExpanded] = useState<string | null>(null);

  useEffect(() => {
    api.getOvertimeRequests(filter || undefined).then((res) => {
      if (res.success && res.data) setRequests(res.data);
    });
  }, [filter]);

  return (
    <DashboardLayout title="Overtime Audit">
      <p className="mb-4 text-sm text-slate-400">Read-only view. Supervisors approve OT requests in the mobile app.</p>

      <div className="mb-6">
        <Select value={filter} onChange={(e) => setFilter(e.target.value)} className="w-48">
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </Select>
      </div>

      <Card>
        <div className="space-y-3">
          {requests.length === 0 ? (
            <p className="text-slate-500">No overtime requests</p>
          ) : requests.map((r) => (
            <div key={r._id} className="rounded-lg border border-slate-700/60 bg-slate-800/30 p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-white">{r.staffName || r.staffId}</p>
                  <p className="text-sm text-slate-400">
                    {new Date(r.otDate).toLocaleDateString()} · {r.hours}h · {r.reason}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <Badge status={r.status} />
                  <button
                    className="text-xs text-blue-400 hover:underline"
                    onClick={() => setExpanded(expanded === r._id ? null : r._id)}
                  >
                    {expanded === r._id ? "Hide" : "Flow"}
                  </button>
                </div>
              </div>
              {expanded === r._id && r.flow && (
                <ul className="mt-3 space-y-1 border-t border-slate-700 pt-3">
                  {r.flow.map((f, i) => (
                    <li key={i} className="text-xs text-slate-400">
                      {new Date(f.at).toLocaleString()} — {f.action} ({f.actorRole}) {f.note && `· ${f.note}`}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      </Card>
    </DashboardLayout>
  );
}
