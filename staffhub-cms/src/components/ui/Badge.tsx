const colors: Record<string, string> = {
  pending: "bg-amber-500/20 text-amber-300",
  approved: "bg-emerald-500/20 text-emerald-300",
  rejected: "bg-red-500/20 text-red-300",
  staff: "bg-blue-500/20 text-blue-300",
  supervisor: "bg-purple-500/20 text-purple-300",
  active: "bg-emerald-500/20 text-emerald-300",
  inactive: "bg-slate-500/20 text-slate-400",
};

export function Badge({ status }: { status: string }) {
  const key = status.toLowerCase();
  return (
    <span className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${colors[key] || "bg-slate-700 text-slate-300"}`}>
      {status}
    </span>
  );
}
