"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { StaffPerformanceAnalytics } from "@/lib/types";
import { Card, CardTitle } from "@/components/ui/Card";

const PERIOD_OPTIONS = [30, 60, 90, 180] as const;

const gradeColors: Record<string, string> = {
  Excellent: "text-emerald-300 border-emerald-500/50 bg-emerald-500/15",
  Good: "text-blue-300 border-blue-500/50 bg-blue-500/15",
  Fair: "text-amber-300 border-amber-500/50 bg-amber-500/15",
  "Needs Improvement": "text-rose-300 border-rose-500/50 bg-rose-500/15",
};

function scoreColor(score: number) {
  if (score >= 90) return "text-emerald-300";
  if (score >= 75) return "text-blue-300";
  if (score >= 60) return "text-amber-300";
  return "text-rose-300";
}

interface StaffPerformancePanelProps {
  staffId: string;
  staffName?: string;
  compact?: boolean;
}

export function StaffPerformancePanel({ staffId, staffName, compact = false }: StaffPerformancePanelProps) {
  const [days, setDays] = useState<number>(90);
  const [data, setData] = useState<StaffPerformanceAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const res = await api.getStaffPerformance(staffId, days);
    if (res.success && res.data) {
      setData(res.data);
    } else {
      setData(null);
      setError(res.message || "Failed to load performance data");
    }
    setLoading(false);
  }, [staffId, days]);

  useEffect(() => {
    load();
  }, [load]);

  const title = staffName ? `${staffName} — Performance` : `Performance — ${staffId}`;

  return (
    <Card className={compact ? "!p-4" : ""}>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <CardTitle>{title}</CardTitle>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className="rounded-lg border border-slate-600 bg-slate-800 px-3 py-1.5 text-sm text-slate-200"
        >
          {PERIOD_OPTIONS.map((d) => (
            <option key={d} value={d}>
              Last {d} days
            </option>
          ))}
        </select>
      </div>

      {loading && <p className="text-slate-400">Loading analytics…</p>}
      {!loading && error && (
        <p className="rounded-lg border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{error}</p>
      )}
      {!loading && data && (
        <div className="space-y-6">
          <div className="flex flex-wrap items-center gap-6">
            <div className="relative flex h-28 w-28 shrink-0 items-center justify-center rounded-full border-4 border-slate-600 bg-slate-800/80">
              <span className={`text-3xl font-bold ${scoreColor(data.performanceScore)}`}>{data.performanceScore}</span>
              <span className="absolute -bottom-1 text-[10px] uppercase tracking-wide text-slate-500">Score</span>
            </div>
            <div>
              <p className="text-sm text-slate-400">Performance grade</p>
              <span
                className={`mt-1 inline-block rounded-full border px-3 py-1 text-sm font-semibold ${gradeColors[data.performanceGrade] ?? gradeColors.Fair}`}
              >
                {data.performanceGrade}
              </span>
              <p className="mt-2 text-xs text-slate-500">
                Based on attendance, leave, overtime & warnings over {data.periodDays} days
              </p>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <MetricCard
              label="Total attendance"
              value={data.attendance.total}
              sub={`${data.attendance.onTime} on-time · ${data.attendance.late} late`}
              accent="blue"
            />
            <MetricCard
              label="Attendance rate"
              value={`${data.attendance.rate}%`}
              sub="On-time clock-ins"
              accent="emerald"
            />
            <MetricCard
              label="Leave"
              value={data.leave.approved}
              sub={`${data.leave.rejected} rejected · ${data.leave.pending} pending · ${data.leave.daysApproved} days`}
              accent="amber"
            />
            <MetricCard
              label="Overtime"
              value={`${data.overtime.hoursApproved}h`}
              sub={`${data.overtime.approved} approved · ${data.overtime.rejected} rejected`}
              accent="violet"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-slate-700 bg-slate-800/50 p-4">
              <p className="mb-2 text-sm font-medium text-slate-300">Punctuality</p>
              <div className="h-3 overflow-hidden rounded-full bg-slate-700">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-emerald-400"
                  style={{ width: `${data.attendance.rate}%` }}
                />
              </div>
              <p className="mt-2 text-xs text-slate-500">{data.attendance.rate}% on-time rate</p>
            </div>
            <div className="rounded-xl border border-slate-700 bg-slate-800/50 p-4">
              <p className="mb-2 text-sm font-medium text-slate-300">Warnings issued</p>
              <p className="text-3xl font-bold text-rose-300">{data.warnings.count}</p>
              {(data.eligibleLateWarning || data.eligibleUnsatisfactoryWarning) && (
                <p className="mt-2 text-xs text-amber-300">
                  {data.eligibleLateWarning && "Eligible for late warning. "}
                  {data.eligibleUnsatisfactoryWarning && "Eligible for unsatisfactory attendance warning."}
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </Card>
  );
}

function MetricCard({
  label,
  value,
  sub,
  accent,
}: {
  label: string;
  value: string | number;
  sub?: string;
  accent: "blue" | "emerald" | "amber" | "violet";
}) {
  const borders = {
    blue: "border-blue-500/35",
    emerald: "border-emerald-500/35",
    amber: "border-amber-500/35",
    violet: "border-violet-500/35",
  };
  const values = {
    blue: "text-blue-300",
    emerald: "text-emerald-300",
    amber: "text-amber-300",
    violet: "text-violet-300",
  };
  return (
    <div className={`rounded-xl border ${borders[accent]} bg-slate-800/40 p-4`}>
      <p className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`mt-2 text-2xl font-bold ${values[accent]}`}>{value}</p>
      {sub ? <p className="mt-1 text-xs text-slate-500">{sub}</p> : null}
    </div>
  );
}
