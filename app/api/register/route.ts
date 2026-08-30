import { NextResponse } from "next/server";
import { adminClient } from "@/lib/server-auth";
import { syntheticEmail } from "@/lib/supabase";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const role = String(body.role);
    const phone = String(body.phone ?? "").replace(/\D/g, "");
    const familyPhone = String(body.familyPhone ?? "").replace(/\D/g, "");
    if (!["senior", "family"].includes(role) || !/^09\d{9}$/.test(phone) || String(body.password ?? "").length < 6) return NextResponse.json({ message: "اطلاعات معتبر نیست." }, { status: 400 });
    if (role === "senior" && !/^09\d{9}$/.test(familyPhone)) return NextResponse.json({ message: "شماره عضو خانواده معتبر نیست." }, { status: 400 });
    const admin = adminClient();
    const { data, error } = await admin.auth.admin.createUser({ email: syntheticEmail(phone), password: body.password, email_confirm: true });
    if (error || !data.user) {
  console.error("Supabase createUser error:", error);
  return NextResponse.json(
    { message: error?.message ?? "ثبت‌نام انجام نشد." },
    { status: 400 }
  );
}
    const code = role === "senior" ? String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, "0") : null;
    const { error: profileError } = await admin.from("profiles").insert({ id: data.user.id, role, first_name: body.firstName, last_name: body.lastName, phone, family_phone: role === "senior" ? familyPhone : null, connection_code: code });
    if (profileError) { await admin.auth.admin.deleteUser(data.user.id); throw profileError; }
    return NextResponse.json({ ok: true, connectionCode: code });
  } catch { return NextResponse.json({ message: "ثبت‌نام انجام نشد." }, { status: 500 }); }
}
