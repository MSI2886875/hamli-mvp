import { NextResponse } from "next/server";
import { adminClient, requireUser } from "@/lib/server-auth";

export async function POST(request: Request) {
  const user = await requireUser(request);
  if (!user) return NextResponse.json({ message: "دسترسی نامعتبر است." }, { status: 401 });
  const body = await request.json();
  const admin = adminClient();
  const { data: family } = await admin.from("profiles").select("id,phone,role").eq("id", user.id).single();
  if (family?.role !== "family") return NextResponse.json({ message: "فقط حساب خانواده مجاز است." }, { status: 403 });
  const { data: senior } = await admin.from("profiles").select("id,family_phone,primary_family_id").eq("connection_code", String(body.code)).eq("role", "senior").single();
  if (!senior || senior.family_phone !== family.phone) return NextResponse.json({ message: "کد یا شماره خانواده مطابقت ندارد." }, { status: 400 });
  if (senior.primary_family_id) return NextResponse.json({ message: "این سالمند قبلاً متصل شده است." }, { status: 409 });
  const relationship = String(body.relationship ?? "");
  const custom = relationship === "سایر" ? String(body.customRelationship ?? "").trim() : null;
  const { error } = await admin.from("care_links").insert({ family_id: family.id, senior_id: senior.id, relationship, custom_relationship: custom });
  if (error) return NextResponse.json({ message: "اتصال انجام نشد." }, { status: 400 });
  await admin.from("profiles").update({ primary_family_id: family.id, connection_code: null }).eq("id", senior.id);
  return NextResponse.json({ ok: true });
}
