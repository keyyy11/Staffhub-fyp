"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import { DashboardLayout } from "@/components/layout/DashboardLayout";
import { Card, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label, Select } from "@/components/ui/Input";
import { api } from "@/lib/api";
import type { PayslipRecord, StaffMember } from "@/lib/types";

function readFileAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error("Failed to read file"));
    reader.readAsDataURL(file);
  });
}

export default function PayslipsPage() {
  const [records, setRecords] = useState<PayslipRecord[]>([]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const now = new Date();
  const [form, setForm] = useState({
    staffId: "",
    year: String(now.getFullYear()),
    month: String(now.getMonth() + 1),
    netPay: "",
    grossPay: "",
    remarks: "",
  });
  const [pdfFile, setPdfFile] = useState<{ dataUrl: string; name: string } | null>(null);

  const load = async () => {
    const [recRes, staffRes] = await Promise.all([api.getPayslipRecords(), api.getStaffList()]);
    if (recRes.success && recRes.data) setRecords(recRes.data);
    if (staffRes.success && staffRes.data) setStaff(staffRes.data);
  };

  useEffect(() => {
    load();
  }, []);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setMessage("");
    setBusy(true);
    const res = await api.upsertPayslip({
      staffId: form.staffId,
      year: Number(form.year),
      month: Number(form.month),
      netPay: Number(form.netPay),
      grossPay: form.grossPay ? Number(form.grossPay) : undefined,
      remarks: form.remarks,
    });
    setBusy(false);
    setMessage(res.success ? "Payslip saved" : res.message || "Failed");
    if (res.success) load();
  };

  const handlePdfSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.type !== "application/pdf") {
      setMessage("Please select a PDF file");
      return;
    }
    const dataUrl = await readFileAsDataUrl(file);
    setPdfFile({ dataUrl, name: file.name });
    setMessage("");
  };

  const handleUploadPdf = async () => {
    if (!form.staffId || !form.netPay || !pdfFile) {
      setMessage("Staff, net pay, and PDF file are required for upload");
      return;
    }
    setBusy(true);
    setMessage("");
    const res = await api.uploadPayslipPdf({
      staffId: form.staffId,
      year: Number(form.year),
      month: Number(form.month),
      netPay: Number(form.netPay),
      grossPay: form.grossPay ? Number(form.grossPay) : undefined,
      remarks: form.remarks,
      pdfFile: pdfFile.dataUrl,
      pdfFileName: pdfFile.name,
    });
    setBusy(false);
    setMessage(res.success ? "Payslip PDF uploaded" : res.message || "Upload failed");
    if (res.success) {
      setPdfFile(null);
      if (fileRef.current) fileRef.current.value = "";
      load();
    }
  };

  const handleGenerate = async () => {
    if (!form.staffId) {
      setMessage("Select staff first");
      return;
    }
    setBusy(true);
    setMessage("");
    const res = await api.generatePayslipPdf({
      staffId: form.staffId,
      year: Number(form.year),
      month: Number(form.month),
    });
    setBusy(false);
    setMessage(res.success ? "Payslip PDF generated" : res.message || "Generate failed");
    if (res.success) load();
  };

  const openPdf = async (r: PayslipRecord) => {
    setBusy(true);
    setMessage("");
    const res = await api.getPayslipPdf(r.staffId, r.year, r.month);
    setBusy(false);
    if (!res.success || !res.data?.pdfFile) {
      setMessage(res.message || "No PDF for this record");
      return;
    }
    const w = window.open();
    if (w) {
      w.document.title = res.data.pdfFileName || "Payslip";
      w.document.write(
        `<iframe width="100%" height="100%" style="border:0" src="${res.data.pdfFile}"></iframe>`,
      );
    }
  };

  return (
    <DashboardLayout title="Payslips">
      {message && (
        <div className="mb-4 rounded-lg border border-blue-500/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-200">
          {message}
        </div>
      )}

      <Card className="mb-6">
        <CardTitle>Issue Payslip</CardTitle>
        <p className="mb-4 text-sm text-slate-400">
          Save payslip data, upload an official PDF, or auto-generate a PDF from salary and attendance.
        </p>
        <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-3">
          <div>
            <Label>Staff</Label>
            <Select value={form.staffId} onChange={(e) => setForm({ ...form, staffId: e.target.value })} required>
              <option value="">Select staff</option>
              {staff.map((s) => (
                <option key={s.staffId} value={s.staffId}>
                  {s.staffId} — {s.name}
                </option>
              ))}
            </Select>
          </div>
          <div>
            <Label>Year</Label>
            <Input type="number" value={form.year} onChange={(e) => setForm({ ...form, year: e.target.value })} required />
          </div>
          <div>
            <Label>Month</Label>
            <Input type="number" min="1" max="12" value={form.month} onChange={(e) => setForm({ ...form, month: e.target.value })} required />
          </div>
          <div>
            <Label>Net Pay (RM)</Label>
            <Input type="number" value={form.netPay} onChange={(e) => setForm({ ...form, netPay: e.target.value })} required />
          </div>
          <div>
            <Label>Gross Pay (RM)</Label>
            <Input type="number" value={form.grossPay} onChange={(e) => setForm({ ...form, grossPay: e.target.value })} />
          </div>
          <div>
            <Label>Remarks</Label>
            <Input value={form.remarks} onChange={(e) => setForm({ ...form, remarks: e.target.value })} />
          </div>
          <div className="flex flex-wrap gap-2 sm:col-span-3">
            <Button type="submit" disabled={busy}>
              Save Data
            </Button>
            <Button type="button" variant="secondary" disabled={busy} onClick={handleGenerate}>
              Generate PDF
            </Button>
          </div>
        </form>

        <div className="mt-6 border-t border-slate-700 pt-4">
          <Label>Upload official PDF</Label>
          <div className="mt-2 flex flex-wrap items-center gap-3">
            <input ref={fileRef} type="file" accept="application/pdf,.pdf" onChange={handlePdfSelect} className="text-sm text-slate-300" />
            {pdfFile && <span className="text-sm text-emerald-300">{pdfFile.name}</span>}
            <Button type="button" disabled={busy || !pdfFile} onClick={handleUploadPdf}>
              Upload PDF
            </Button>
          </div>
        </div>
      </Card>

      <Card>
        <CardTitle>Recent Payslips</CardTitle>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700 text-left text-slate-400">
                <th className="pb-3 pr-4">Staff</th>
                <th className="pb-3 pr-4">Period</th>
                <th className="pb-3 pr-4">Net Pay</th>
                <th className="pb-3 pr-4">PDF</th>
                <th className="pb-3">Remarks</th>
              </tr>
            </thead>
            <tbody>
              {records.map((r) => (
                <tr key={r._id} className="border-b border-slate-800">
                  <td className="py-3 pr-4 font-mono text-blue-300">{r.staffId}</td>
                  <td className="py-3 pr-4 text-white">
                    {r.month}/{r.year}
                  </td>
                  <td className="py-3 pr-4 text-emerald-300">RM {r.netPay}</td>
                  <td className="py-3 pr-4">
                    {r.hasPdf ? (
                      <button type="button" onClick={() => openPdf(r)} className="text-blue-300 hover:underline">
                        View ({r.pdfSource || "pdf"})
                      </button>
                    ) : (
                      <span className="text-slate-500">—</span>
                    )}
                  </td>
                  <td className="py-3 text-slate-400">{r.remarks || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </DashboardLayout>
  );
}
