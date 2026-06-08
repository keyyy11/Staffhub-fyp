"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";

const nav = [
  { href: "/dashboard", label: "Dashboard", icon: "📊" },
  { href: "/staff", label: "Staff", icon: "👥" },
  { href: "/branches", label: "Branches", icon: "🏢" },
  { href: "/attendance", label: "Attendance", icon: "🕐" },
  { href: "/leave", label: "Leave", icon: "📅" },
  { href: "/payslips", label: "Payslips", icon: "💰" },
  { href: "/discipline", label: "Discipline", icon: "⚠️" },
  { href: "/overtime", label: "Overtime", icon: "⏱️" },
  { href: "/profile", label: "Profile", icon: "👤" },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuth();

  const handleLogout = () => {
    logout();
    router.push("/login");
  };

  return (
    <aside className="flex w-64 shrink-0 flex-col border-r border-slate-700/60 bg-slate-950">
      <div className="border-b border-slate-700/60 p-5">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-emerald-500 to-amber-500 text-lg font-bold text-slate-900">
            R
          </div>
          <div>
            <p className="font-semibold text-white">Staff Hub</p>
            <p className="text-xs text-slate-400">Admin CMS</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 space-y-1 p-3">
        {nav.map((item) => {
          const active = pathname === item.href || pathname.startsWith(item.href + "/");
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition ${
                active ? "bg-blue-600/20 text-blue-300" : "text-slate-400 hover:bg-slate-800 hover:text-white"
              }`}
            >
              <span>{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-slate-700/60 p-4">
        <p className="truncate text-sm font-medium text-white">{user?.name}</p>
        <p className="truncate text-xs text-slate-500">{user?.email}</p>
        <button
          onClick={handleLogout}
          className="mt-3 w-full rounded-lg border border-slate-600 px-3 py-2 text-sm text-slate-300 hover:bg-slate-800"
        >
          Logout
        </button>
      </div>
    </aside>
  );
}
