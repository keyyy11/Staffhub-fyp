"use client";

import { useRequireAuth } from "@/context/AuthContext";
import { Sidebar } from "./Sidebar";

export function DashboardLayout({ children, title }: { children: React.ReactNode; title: string }) {
  const { loading } = useRequireAuth();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-950 text-slate-400">
        Loading...
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-slate-950">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <header className="border-b border-slate-700/60 bg-slate-900/50 px-8 py-5">
          <h1 className="text-2xl font-bold text-white">{title}</h1>
        </header>
        <div className="p-8">{children}</div>
      </main>
    </div>
  );
}
