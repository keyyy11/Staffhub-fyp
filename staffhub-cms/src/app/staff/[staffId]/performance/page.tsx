"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/Button";
import { StaffPerformancePanel } from "@/components/staff/StaffPerformancePanel";

export default function StaffPerformancePage() {
  const { staffId } = useParams<{ staffId: string }>();

  return (
    <DashboardLayout title={`Performance — ${staffId}`}>
      <div className="mb-4">
        <Link href={`/staff/${staffId}`}>
          <Button variant="ghost">← Back to edit staff</Button>
        </Link>
      </div>
      <StaffPerformancePanel staffId={staffId} />
    </DashboardLayout>
  );
}
