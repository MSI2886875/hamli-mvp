"use client";
import { useEffect,useState } from "react";
import { supabaseBrowser } from "@/lib/supabase";
import { AuthScreen } from "@/components/auth-screen";
import { SeniorDashboard } from "@/components/senior-dashboard";
import { FamilyDashboard } from "@/components/family-dashboard";

type Profile={id:string;role:"senior"|"family";first_name:string;last_name:string;phone:string;connection_code:string|null;primary_family_id:string|null};
export default function Home(){const [profile,setProfile]=useState<Profile|null>(null);const [loading,setLoading]=useState(true);async function load(){const sb=supabaseBrowser();const {data:{user}}=await sb.auth.getUser();if(!user){setProfile(null);setLoading(false);return}const {data}=await sb.from("profiles").select("id,role,first_name,last_name,phone,connection_code,primary_family_id").eq("id",user.id).single();setProfile(data);setLoading(false)}useEffect(()=>{void load()},[]);if(loading)return <main className="shell"><p>در حال بارگذاری...</p></main>;if(!profile)return <AuthScreen onDone={load}/>;return profile.role==="senior"?<SeniorDashboard profile={profile} onLogout={async()=>{await supabaseBrowser().auth.signOut();setProfile(null)}}/>:<FamilyDashboard profile={profile} onLogout={async()=>{await supabaseBrowser().auth.signOut();setProfile(null)}}/>}
