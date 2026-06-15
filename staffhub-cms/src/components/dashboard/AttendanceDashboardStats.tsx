import Link from "next/link";
import type { AttendanceReportStats } from "@/lib/types";

export interface AttendanceDashboardMetrics {
  attendance: AttendanceReportStats;
  leaveCount: number;
  overtimeCount: number;
  periodLabel?: string;
}

interface StatCardProps {
  label: string;
  value: number;
  sub?: string;
  href?: string;
  accent: "blue" | "amber" | "emerald" | "violet";
  icon: string;
  suffix?: string;
}

const accentStyles = {
  blue: {
    border: "border-blue-500/40",
    glow: "from-blue-600/20 to-blue-900/10",
    value: "text-blue-300",
    icon: "bg-blue-500/20 text-blue-300",
  },
  amber: {
    border: "border-amber-500/40",
    glow: "from-amber-600/20 to-amber-900/10",
    value: "text-amber-300",
    icon: "bg-amber-500/20 text-amber-300",
  },
  emerald: {
    border: "border-emerald-500/40",
    glow: "from-emerald-600/20 to-emerald-900/10",
    value: "text-emerald-300",
    icon: "bg-emerald-500/20 text-emerald-300",
  },
  violet: {
    border: "border-violet-500/40",
    glow: "from-violet-600/20 to-violet-900/10",
    value: "text-violet-300",
    icon: "bg-violet-500/20 text-violet-300",
  },
};

function StatCard({ label, value, sub, href, accent, icon, suffix }: StatCardProps) {
  const styles = accentStyles[accent];
  const inner = (
    <div
      className={`relative overflow-hidden rounded-2xl border ${styles.border} bg-gradient-to-br ${styles.glow} p-5 shadow-lg transition hover:scale-[1.02] hover:shadow-xl`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-medium text-slate-400">{label}</p>
          <p className={`mt-2 text-4xl font-bold tracking-tight ${styles.value}`}>
            {value}
            {suffix ? <span className="text-2xl">{suffix}</span> : null}
          </p>
          {sub ? <p className="mt-2 text-xs text-slate-500">{sub}</p> : null}
        </div>
        <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-2xl ${styles.icon}`}>
          {icon}
        </div>
      </div>
    </div>
  );

  if (href) {
    return (
      <Link href={href} className="block">
        {inner}
      </Link>
    );
  }
  return inner;
}

export function AttendanceDashboardStats({ metrics, periodLabel = "Last 30 days" }: { metrics: AttendanceDashboardMetrics; periodLabel?: string }) {
  const { attendance, leaveCount, overtimeCount } = metrics;
  const onTimeRate = attendance.total > 0 ? Math.round((attendance.onTime / attendance.total) * 100) : 0;
  const lateRate = attendance.total > 0 ? Math.round((attendance.late / attendance.total) * 100) : 0;

  return (
    <section>
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-white">Attendance Dashboard</h2>
          <p className="mt-1 text-sm text-slate-400">
            Workforce overview · {periodLabel}
          </p>
        </div>
        {attendance.total > 0 ? (
          <div className="rounded-full border border-slate-700 bg-slate-800/60 px-4 py-1.5 text-xs text-slate-300">
            On-time rate <span className="font-semibold text-emerald-400">{onTimeRate}%</span>
            {" · "}
            Late <span className="font-semibold text-amber-400">{lateRate}%</span>
          </div>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Total Attendance"
          value={attendance.total}
          sub={`${attendance.onTime} on time`}
          href="/attendance"
          accent="blue"
          icon="✓"
        />
        <StatCard
          label="On-Time Rate"
          value={onTimeRate}
          sub={`${attendance.onTime} of ${attendance.total} clock-ins`}
          href="/attendance"
          accent="emerald"
          icon="⚡"
          suffix="%"
        />
        <StatCard
          label="Late Rate"
          value={lateRate}
          sub={`${attendance.late} late clock-ins`}
          href="/attendance"
          accent="amber"
          icon="⏰"
          suffix="%"
        />
        <StatCard
          label="Overtime Count"
          value={overtimeCount}
          sub="OT requests in period"
          href="/overtime"
          accent="violet"
          icon="⏱"
        />
      </div>

      {attendance.total > 0 ? (
        <div className="mt-4 rounded-xl border border-slate-700/60 bg-slate-900/50 p-4">
          <p className="mb-2 text-xs font-medium uppercase tracking-wide text-slate-500">Punctuality breakdown</p>
          <div className="flex h-3 overflow-hidden rounded-full bg-slate-800">
            <div
              className="bg-emerald-500 transition-all"
              style={{ width: `${onTimeRate}%` }}
              title={`On time: ${attendance.onTime}`}
            />
            <div
              className="bg-amber-500 transition-all"
              style={{ width: `${lateRate}%` }}
              title={`Late: ${attendance.late}`}
            />
          </div>
          <div className="mt-2 flex justify-between text-xs text-slate-500">
            <span className="text-emerald-400">On time ({attendance.onTime})</span>
            <span className="text-amber-400">Late ({attendance.late})</span>
          </div>
        </div>
      ) : null}
    </section>
  );
}
