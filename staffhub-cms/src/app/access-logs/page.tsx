"use client";

import { useCallback, useEffect, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import type { AccessLogEntry } from "@/lib/types";

const ACTION_OPTIONS = [
  { value: "", label: "All actions" },
  { value: "login", label: "Login" },
  { value: "logout", label: "Logout" },
  { value: "login_failed", label: "Login failed" },
];

const PLATFORM_OPTIONS = [
  { value: "", label: "All platforms" },
  { value: "cms", label: "CMS" },
  { value: "mobile", label: "Mobile" },
];

function actionLabel(action: string) {
  if (action === "login") return "Login";
  if (action === "logout") return "Logout";
  if (action === "login_failed") return "Login failed";
  return action;
}

function platformLabel(platform: string) {
  if (platform === "cms") return "CMS";
  if (platform === "mobile") return "Mobile";
  return "Unknown";
}

export default function AccessLogsPage() {
  const [logs, setLogs] = useState<AccessLogEntry[]>([]);
  const [days, setDays] = useState(30);
  const [action, setAction] = useState("");
  const [platform, setPlatform] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const res = await api.getAccessLogs({
      days,
      limit: 200,
      ...(action ? { action } : {}),
      ...(platform ? { platform } : {}),
    });
    if (res.success && res.data) {
      setLogs(res.data.logs);
    } else {
      setLogs([]);
      setError(res.message || "Failed to load access logs");
    }
    setLoading(false);
  }, [days, action, platform]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <DashboardLayout title="Admin Access Logs">
      <p className="mb-6 text-sm text-slate-400">
        Login and logout activity for admin accounts (CMS and mobile app).
      </p>

      <div className="mb-6 flex flex-wrap gap-3">
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className="rounded-lg border border-slate-600 bg-slate-800 px-3 py-2 text-sm text-slate-200"
        >
          <option value={7}>Last 7 days</option>
          <option value={30}>Last 30 days</option>
          <option value={90}>Last 90 days</option>
        </select>
        <select
          value={action}
          onChange={(e) => setAction(e.target.value)}
          className="rounded-lg border border-slate-600 bg-slate-800 px-3 py-2 text-sm text-slate-200"
        >
          {ACTION_OPTIONS.map((o) => (
            <option key={o.value || "all"} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        <select
          value={platform}
          onChange={(e) => setPlatform(e.target.value)}
          className="rounded-lg border border-slate-600 bg-slate-800 px-3 py-2 text-sm text-slate-200"
        >
          {PLATFORM_OPTIONS.map((o) => (
            <option key={o.value || "all"} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>

      <Card>
        {loading ? (
          <p className="text-slate-400">Loading access logs…</p>
        ) : error ? (
          <p className="text-rose-300">{error}</p>
        ) : logs.length === 0 ? (
          <p className="text-slate-500">No access logs in this period.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-700 text-left text-slate-400">
                  <th className="pb-3 pr-4">Date & time</th>
                  <th className="pb-3 pr-4">Admin</th>
                  <th className="pb-3 pr-4">Action</th>
                  <th className="pb-3 pr-4">Platform</th>
                  <th className="pb-3 pr-4">Status</th>
                  <th className="pb-3">IP</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log._id} className="border-b border-slate-800">
                    <td className="py-3 pr-4 whitespace-nowrap text-slate-300">
                      {log.createdAt ? new Date(log.createdAt).toLocaleString() : "—"}
                    </td>
                    <td className="py-3 pr-4">
                      <p className="font-medium text-white">{log.name || log.staffId}</p>
                      <p className="text-xs text-slate-500">{log.email}</p>
                    </td>
                    <td className="py-3 pr-4">
                      <Badge status={log.action === "logout" ? "pending" : log.action === "login_failed" ? "rejected" : "approved"} />
                      <span className="ml-2 text-slate-300">{actionLabel(log.action)}</span>
                    </td>
                    <td className="py-3 pr-4 text-slate-300">{platformLabel(log.platform)}</td>
                    <td className="py-3 pr-4">
                      {log.success ? (
                        <span className="text-emerald-400">Success</span>
                      ) : (
                        <span className="text-rose-400">Failed</span>
                      )}
                    </td>
                    <td className="py-3 text-xs text-slate-500">{log.ipAddress || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </DashboardLayout>
  );
}
