import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const DEFAULT_FINISH_URL="https://aliyaseenhasn-hue.github.io/istishara-platform/#/payment-result";

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  try{
    const authHeader=req.headers.get("Authorization"); if(!authHeader) throw new Error("غير مصرح");
    const url=Deno.env.get("SUPABASE_URL")!,serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,anonKey=Deno.env.get("SUPABASE_ANON_KEY")!;
    const base=(Deno.env.get("QICARD_API_URL")||Deno.env.get("QICARD_API_BASE_URL")||"https://uat-sandbox-3ds-api.qi.iq/api/v1").replace(/\/$/,"");
    const username=Deno.env.get("QICARD_USERNAME"),password=Deno.env.get("QICARD_PASSWORD"),terminalId=Deno.env.get("QICARD_TERMINAL_ID");
    if(!username||!password||!terminalId) throw new Error("لم يتم إعداد بيانات بوابة كي كارد كاملة");
    const admin=createClient(url,serviceRoleKey),client=createClient(url,anonKey,{global:{headers:{Authorization:authHeader}}});
    const {data:userData,error:authError}=await client.auth.getUser(); if(authError||!userData.user) throw new Error("المستخدم غير مسجل دخول");
    const {data:profile,error:profileError}=await admin.from("profiles").select("id").eq("auth_id",userData.user.id).maybeSingle(); if(profileError) throw profileError; if(!profile) throw new Error("ملف المستخدم غير مكتمل");
    const body=await req.json(),bookingId=body?.booking_id; if(!bookingId) throw new Error("معرّف الحجز مطلوب");
    const {data:booking,error:be}=await admin.from("bookings").select("id,user_id,price,status,lawyer_approved").eq("id",bookingId).maybeSingle();
    if(be) throw be; if(!booking||booking.user_id!==profile.id) throw new Error("لا تملك صلاحية الدفع لهذا الحجز");
    if(booking.status!=="قيد انتظار الدفع" && booking.status!=="قيد معالجة الدفع") throw new Error("الحجز غير متاح للدفع في حالته الحالية");
    if(booking.price==null||Number(booking.price)<=0) throw new Error("قيمة الحجز غير صالحة للدفع");

    const configuredFinish=Deno.env.get("QICARD_FINISH_URL")||DEFAULT_FINISH_URL;
    const reusableResponse=(p:any)=>{
      const requestId=p.qicard_request_id||"";
      const finishUrl=`${configuredFinish}${configuredFinish.includes("?")?"&":"?"}booking_id=${encodeURIComponent(bookingId)}${requestId?`&request_id=${encodeURIComponent(requestId)}`:""}`;
      const formUrl=`${base}/payment/${encodeURIComponent(p.qicard_payment_id)}`;
      return new Response(JSON.stringify({paymentId:p.qicard_payment_id,formUrl,finishUrl,reused:true}),{headers:{...cors,"Content-Type":"application/json"}});
    };

    const {data:active,error:activeError}=await admin.from("payments").select("id,qicard_payment_id,qicard_request_id,status,created_at").eq("booking_id",bookingId).in("status",["قيد معالجة الدفع","تم الدفع"]).order("created_at",{ascending:false}).limit(1);
    if(activeError) throw activeError;
    const current=active?.[0];
    if(current?.status==="تم الدفع") throw new Error("تم دفع هذا الحجز مسبقاً");
    if(current?.status==="قيد معالجة الدفع"){
      if(current.qicard_payment_id) return reusableResponse(current);
      throw new Error("توجد عملية دفع قيد التجهيز لهذا الحجز. حاول بعد لحظات.");
    }

    // Reserve the single active payment row before calling Qi Card. The partial
    // unique index on booking_id makes concurrent requests fail here, before a
    // second external payment can be created.
    const requestId=crypto.randomUUID(),now=new Date().toISOString();
    const {data:reservation,error:reserveError}=await admin.from("payments").insert({
      booking_id:bookingId,
      amount:booking.price,
      payment_method:"Qi Card",
      status:"قيد معالجة الدفع",
      qicard_request_id:requestId,
      qicard_raw_status:"CREATING",
      qicard_updated_at:now
    }).select("id,qicard_payment_id,qicard_request_id,status").single();

    if(reserveError){
      if(reserveError.code==="23505"){
        const {data:race,error:raceError}=await admin.from("payments").select("id,qicard_payment_id,qicard_request_id,status,created_at").eq("booking_id",bookingId).in("status",["قيد معالجة الدفع","تم الدفع"]).order("created_at",{ascending:false}).limit(1);
        if(raceError) throw raceError;
        const winner=race?.[0];
        if(winner?.status==="تم الدفع") throw new Error("تم دفع هذا الحجز مسبقاً");
        if(winner?.qicard_payment_id) return reusableResponse(winner);
        throw new Error("توجد عملية دفع قيد التجهيز لهذا الحجز. حاول بعد لحظات.");
      }
      throw reserveError;
    }

    const credentials=btoa(`${username}:${password}`);
    const finishUrl=`${configuredFinish}${configuredFinish.includes("?")?"&":"?"}booking_id=${encodeURIComponent(bookingId)}&request_id=${encodeURIComponent(requestId)}`;
    const webhookUrl=Deno.env.get("QICARD_WEBHOOK_URL")||`${url}/functions/v1/qicard-webhook`;
    let qiResponse:Response;
    let raw="";
    let qiData:any=null;
    try{
      qiResponse=await fetch(`${base}/payment`,{method:"POST",headers:{"Content-Type":"application/json",Accept:"application/json",Authorization:`Basic ${credentials}`,"X-Terminal-Id":terminalId},body:JSON.stringify({requestId,amount:Number(booking.price),currency:"IQD",locale:"ar_IQ",finishPaymentUrl:finishUrl,notificationUrl:webhookUrl,additionalInfo:{bookingId,requestId},appChannel:false})});
      raw=await qiResponse.text();
      try{qiData=JSON.parse(raw)}catch{qiData=null;}
      if(!qiResponse.ok||!qiData?.paymentId||!qiData?.formUrl){
        const d=qiData?.error?.description||qiData?.error?.message||raw.slice(0,300);
        await admin.from("payments").update({status:"فشل الدفع",qicard_raw_status:"CREATE_FAILED",qicard_updated_at:new Date().toISOString()}).eq("id",reservation.id).eq("qicard_request_id",requestId);
        throw new Error(`بوابة كي كارد: ${d||`HTTP ${qiResponse.status}`}`);
      }
    }catch(error){
      if(!(qiData?.paymentId)){
        await admin.from("payments").update({status:"فشل الدفع",qicard_raw_status:"CREATE_FAILED",qicard_updated_at:new Date().toISOString()}).eq("id",reservation.id).eq("qicard_request_id",requestId);
      }
      throw error;
    }

    const {error:paymentUpdateError}=await admin.from("payments").update({qicard_payment_id:qiData.paymentId,qicard_raw_status:String(qiData.status||"CREATED").toUpperCase(),qicard_updated_at:new Date().toISOString()}).eq("id",reservation.id).eq("qicard_request_id",requestId).eq("status","قيد معالجة الدفع");
    if(paymentUpdateError) throw paymentUpdateError;

    const {error:bookingUpdateError}=await admin.from("bookings").update({status:"قيد معالجة الدفع"}).eq("id",bookingId).in("status",["قيد انتظار الدفع","قيد معالجة الدفع"]);
    if(bookingUpdateError) throw bookingUpdateError;
    return new Response(JSON.stringify({paymentId:qiData.paymentId,formUrl:qiData.formUrl,finishUrl,reused:false}),{headers:{...cors,"Content-Type":"application/json"}});
  }catch(error){
    return new Response(JSON.stringify({error:error instanceof Error?error.message:"حدث خطأ غير متوقع"}),{status:400,headers:{...cors,"Content-Type":"application/json"}});
  }
});
