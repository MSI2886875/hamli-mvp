import { NextResponse } from "next/server";
import { adminClient, requireUser } from "@/lib/server-auth";

export async function POST(request: Request) {
  const user = await requireUser(request);
  if (!user) return NextResponse.json({ message: "دسترسی نامعتبر است." }, { status: 401 });
  const { seniorId, password } = await request.json();
  if (String(password).length < 6) return NextResponse.json({ message: "رمز حداقل ۶ کاراکتر باشد." }, { status: 400 });
  const admin = adminClient();
  const { data: link } = await admin.from("care_links").select("id").eq("family_id", user.id).eq("senior_id", seniorId).single();
  if (!link) return NextResponse.json({ message: "دسترسی ندارید." }, { status: 403 });
  const { error } = await admin.auth.admin.updateUserById(seniorId, { password });
  return error ? NextResponse.json({ message: "بازنشانی انجام نشد." }, { status: 400 }) : NextResponse.json({ ok: true });
}
