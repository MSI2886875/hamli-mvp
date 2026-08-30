import { NextResponse } from "next/server";
import { adminClient, requireUser } from "@/lib/server-auth";

export async function POST(request: Request) {
  const user=await requireUser(request);if(!user)return NextResponse.json({message:"دسترسی نامعتبر است."},{status:401});
  const body=await request.json();const admin=adminClient();const {data:me}=await admin.from("profiles").select("role").eq("id",user.id).single();
  const seniorId=me?.role==="senior"?user.id:String(body.seniorId||"");
  let query=admin.from("care_links").select("id").eq("senior_id",seniorId);if(me?.role==="family")query=query.eq("family_id",user.id);
  const {data:link}=await query.maybeSingle();if(!link)return NextResponse.json({message:"اتصال پیدا نشد."},{status:404});
  await admin.from("care_links").delete().eq("id",link.id);const code=String(crypto.getRandomValues(new Uint32Array(1))[0]%1_000_000).padStart(6,"0");
  await admin.from("profiles").update({primary_family_id:null,connection_code:code}).eq("id",seniorId);return NextResponse.json({ok:true,connectionCode:code});
}
