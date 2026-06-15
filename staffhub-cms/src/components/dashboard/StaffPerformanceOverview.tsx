"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import type { StaffPerformanceSummary } from "@/lib/types";
import { Card, CardTitle } from "@/components/ui/Card";

const PERIOD_OPTIONS = [30, 60, 90] as const;

const gradeColors: Record<string, string> = {
  Excellent: "text-emerald-300 bg-emerald-500/15 border-emerald-500/40",
  Good: "text-blue-300 bg-blue-500/15 border-blue-500/40",
  Fair: "text-amber-300 bg-amber-500/15 border-amber-500/40",
  "Needs Improvement": "text-rose-300 bg-rose-500/15 border-rose-500/40",
};

function scoreColor(score: number) {
  if (score >= 90) return "text-emerald-300";
  if (score >= 75) return "text-blue-300";
  if (score >= 60) return "text-amber-300";
  return "text-rose-300";
}

export function StaffPerformanceOverview() {
  const [days, setDays] = useState<number>(30);
  const [staff, setStaff] = useState<StaffPerformanceSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const res = await api.getPerformanceOverview(days);
    if (res.success && res.data) {
      setStaff(res.data.staff);
    } else {
      setStaff([]);
      setError(res.message || "Failed to load performance overview");
    }
    setLoading(false);
  }, [days]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <section className="mt-10">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-white">Staff Performance Analytics</h2>
          <p className="mt-1 text-sm text-slate-400">Individual scores · attendance on-time / late %</p>
        </div>
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

      <Card>
        {loading ? (
          <p className="text-slate-400">Loading performance analytics…</p>
        ) : error ? (
          <p className="text-rose-300">{error}</p>
        ) : staff.length === 0 ? (
          <p className="text-slate-500">No staff performance data yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-700 text-left text-slate-400">
                  <th className="pb-3 pr-4">Staff</th>
                  <th className="pb-3 pr-4">On-time %</th>
                  <th className="pb-3 pr-4">Late %</th>
                  <th className="pb-3 pr-4">Score</th>
                  <th className="pb-3 pr-4">Grade</th>
                  <th className="pb-3">Details</th>
                </tr>
              </thead>
              <tbody>
                {staff.map((s) => {
                  const total = s.attendance.total;
                  const onTimePct = total > 0 ? Math.round((s.attendance.onTime / total) * 100) : 0;
                  const latePct = total > 0 ? Math.round((s.attendance.late / total) * 100) : 0;
                  return (
                    <tr key={s.staffId} className="border-b border-slate-800">
                      <td className="py-3 pr-4">
                        <p className="font-medium text-white">{s.staffName}</p>
                        <p className="font-mono text-xs text-slate-500">{s.staffId}</p>
                      </td>
                      <td className="py-3 pr-4">
                        <span className="font-semibold text-emerald-400">{onTimePct}%</span>
                        <p className="text-xs text-slate-500">{s.attendance.onTime} on time</p>
                      </td>
                      <td className="py-3 pr-4">
                        <span className="font-semibold text-amber-400">{latePct}%</span>
                        <p className="text-xs text-slate-500">{s.attendance.late} late</p>
                      </td>
                      <td className={`py-3 pr-4 text-lg font-bold ${scoreColor(s.performanceScore)}`}>
                        {s.performanceScore}
                      </td>
                      <td className="py-3 pr-4">
                        <span
                          className={`inline-block rounded-full border px-2.5 py-0.5 text-xs font-medium ${gradeColors[s.performanceGrade] ?? gradeColors.Fair}`}
                        >
                          {s.performanceGrade}
                        </span>
                      </td>
                      <td className="py-3">
                        <Link
                          href={`/staff/${s.staffId}/performance`}
                          className="text-xs font-medium text-blue-400 hover:text-blue-300"
                        >
                          View →
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </section>
  );
}
