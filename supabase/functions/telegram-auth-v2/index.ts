import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const BOT_USERNAME = (Deno.env.get('TELEGRAM_BOT_USERNAME') || 'Astshara_app_bot').replace(/^@/, '');
const WEBHOOK_SECRET = Deno.env.get('TELEGRAM_WEBHOOK_SECRET') || '';

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const authClient = createClient(SUPABASE_URL, ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });

const normalizeDigits = (value: string) =>
  String(value || '')
    .replace(/[٠-٩]/g, (c) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(c)))
    .replace(/[۰-۹]/g, (c) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c)));

const normalizePhone = (value: string) => {
  let phone = normalizeDigits(value)
    .trim()
    .replace(/\s+/g, '')
    .replace(/[()\-]/g, '')
    .replace(/[^0-9+]/g, '');
  if (phone.startsWith('+')) phone = phone.slice(1);
  if (phone.startsWith('00')) phone = phone.slice(2);
  if (phone.startsWith('0')) phone = `964${phone.slice(1)}`;
  if (!phone.startsWith('964')) phone = `964${phone}`;
  return phone;
};
const phoneCandidates = (phone: string) => [phone, `0${phone.slice(3)}`, `+${phone}`];
const normalizeCode = (value: string) => normalizeDigits(value).replace(/\s/g, '');
const sha256 = async (text: string) => {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
};
const randomPassword = () => crypto.randomUUID() + crypto.randomUUID();
const syntheticEmail = (phone: string) => `telegram.${phone}@login.astshara.app`;
const LINKED = 'هذا الحساب مرتبط بحساب آخر في تطبيق استشارة.';

async function telegram(method: string, body: Record<string, unknown>) {
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!data.ok) throw new Error(data.description || `Telegram ${method} failed`);
  return data.result;
}

async function ensureWebhook() {
  if (!WEBHOOK_SECRET) {
    throw new Error('إعداد أمان Telegram غير مكتمل.');
  }
  const body: Record<string, unknown> = {
    url: `${SUPABASE_URL}/functions/v1/telegram-auth-v2?webhook=1`,
    allowed_updates: ['message'],
    drop_pending_updates: false,
    secret_token: WEBHOOK_SECRET,
  };
  await telegram('setWebhook', body);
}

async function findProfile(phone: string) {
  const { data, error } = await admin
    .from('profiles')
    .select('*')
    .in('phone', phoneCandidates(phone))
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`تعذر التحقق من الرقم: ${error.message}`);
  return data;
}

async function findProfileById(id: string) {
  if (!id) return null;
  const { data, error } = await admin.from('profiles').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(`تعذر استرجاع الحساب المرتبط: ${error.message}`);
  return data;
}

async function findTelegramProfile(telegramUserId: number) {
  const { data, error } = await admin
    .from('profiles')
    .select('*')
    .eq('telegram_user_id', telegramUserId)
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`تعذر التحقق من حساب Telegram: ${error.message}`);
  return data;
}

async function start(phoneRaw: string, mode = 'login', fullName?: string, role?: string) {
  const phone = normalizePhone(phoneRaw);
  if (!/^9647\d{9}$/.test(phone)) throw new Error('رقم الهاتف العراقي غير صحيح');

  const signup = mode === 'signup';
  if (signup) {
    if (!fullName || fullName.trim().length < 3) throw new Error('الاسم الكامل مطلوب');
    if (role !== 'user' && role !== 'lawyer') throw new Error('نوع الحساب غير صحيح');
    if (await findProfile(phone)) {
      throw new Error(
        'هذا الرقم مرتبط بحساب آخر. يرجى استخدام رقم هاتف آخر أو تسجيل الدخول بالحساب المرتبط به.',
      );
    }
  }

  await ensureWebhook();
  const token = crypto.randomUUID();
  await admin
    .from('telegram_login_requests')
    .update({ status: 'expired' })
    .eq('phone', phone)
    .in('status', ['waiting', 'code_sent', 'telegram_verified'])
    .is('session_claimed_at', null);

  const { error } = await admin.from('telegram_login_requests').insert({
    request_token: token,
    phone,
    status: 'waiting',
    attempts: 0,
    expires_at: new Date(Date.now() + 600000).toISOString(),
    mode: signup ? 'signup' : 'login',
    full_name: signup ? fullName!.trim() : null,
    role: signup ? role : null,
  });
  if (error) throw new Error(`تعذر إنشاء طلب Telegram: ${error.message}`);

  return {
    ok: true,
    request_token: token,
    telegram_url: `https://t.me/${BOT_USERNAME}?start=${token}`,
  };
}

async function webhook(req: Request) {
  if (!WEBHOOK_SECRET) return json({ ok: false, error: 'Telegram webhook secret missing' }, 503);
  if (req.headers.get('x-telegram-bot-api-secret-token') !== WEBHOOK_SECRET) {
    return json({ ok: false }, 401);
  }

  const update = await req.json();
  const message = update?.message;
  if (!message?.chat?.id) return json({ ok: true });

  if (message.contact) {
    await handleContact(message);
    return json({ ok: true });
  }

  const telegramUserId = Number(message.chat.id);
  const text = String(message.text || '').trim();
  const arg = text.match(/^\/start(?:\s+(.+))?$/i)?.[1]?.trim();
  if (!arg) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'مرحباً بك في بوت استشارة ⚖️\nافتح رابط تسجيل الدخول من تطبيق استشارة واضغط «بدء». ثم اختر «مشاركة رقم الهاتف» لإكمال الدخول تلقائياً.',
    });
    return json({ ok: true });
  }

  const { data: request, error } = await admin
    .from('telegram_login_requests')
    .select('*')
    .eq('request_token', arg)
    .maybeSingle();

  if (
    error ||
    !request ||
    new Date(request.expires_at).getTime() <= Date.now() ||
    request.status === 'expired' ||
    request.session_claimed_at
  ) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'انتهت صلاحية طلب التحقق أو تم استخدامه مسبقاً. ارجع إلى تطبيق استشارة واطلب محاولة جديدة.',
    });
    return json({ ok: true });
  }

  const { error: bindError } = await admin
    .from('telegram_login_requests')
    .update({
      telegram_user_id: telegramUserId,
      telegram_username: message.from?.username ?? null,
      telegram_first_name: message.from?.first_name ?? null,
      telegram_last_name: message.from?.last_name ?? null,
    })
    .eq('id', request.id)
    .eq('status', 'waiting')
    .is('session_claimed_at', null);
  if (bindError) throw new Error(`تعذر تثبيت طلب Telegram: ${bindError.message}`);

  await telegram('sendMessage', {
    chat_id: telegramUserId,
    text: 'لإكمال تسجيل الدخول تلقائياً، اضغط الزر أدناه لمشاركة رقم هاتفك مع بوت استشارة. لن يتم استخدامه إلا للتحقق من ملكية الرقم.',
    reply_markup: {
      keyboard: [[{ text: 'مشاركة رقم الهاتف', request_contact: true }]],
      resize_keyboard: true,
      one_time_keyboard: true,
    },
  });
  return json({ ok: true });
}

async function handleContact(message: any) {
  const telegramUserId = Number(message.chat.id);
  const contact = message.contact;
  if (!contact?.phone_number) return false;
  if (contact.user_id && Number(contact.user_id) !== telegramUserId) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'يجب مشاركة رقم الهاتف الخاص بحساب Telegram نفسه.',
      reply_markup: { remove_keyboard: true },
    });
    return true;
  }

  const contactPhone = normalizePhone(String(contact.phone_number));
  let { data: request, error } = await admin
    .from('telegram_login_requests')
    .select('*')
    .eq('telegram_user_id', telegramUserId)
    .eq('status', 'waiting')
    .is('session_claimed_at', null)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`تعذر العثور على طلب Telegram: ${error.message}`);

  if (!request) {
    const fallback = await admin
      .from('telegram_login_requests')
      .select('*')
      .in('phone', phoneCandidates(contactPhone))
      .eq('status', 'waiting')
      .is('session_claimed_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (fallback.error) throw new Error(`تعذر العثور على طلب Telegram: ${fallback.error.message}`);
    request = fallback.data;
  }

  if (!request) return false;
  if (new Date(request.expires_at).getTime() <= Date.now()) {
    await admin
      .from('telegram_login_requests')
      .update({ status: 'expired' })
      .eq('id', request.id)
      .eq('status', 'waiting');
    return false;
  }
  if (contactPhone !== normalizePhone(request.phone)) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'رقم الهاتف الذي تمت مشاركته لا يطابق الرقم المدخل في استشارة. ارجع إلى التطبيق وتحقق من الرقم.',
      reply_markup: { remove_keyboard: true },
    });
    return true;
  }

  const existingTelegram = await findTelegramProfile(telegramUserId);
  if (
    existingTelegram &&
    (request.mode !== 'login' || normalizePhone(existingTelegram.phone) !== contactPhone)
  ) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: LINKED,
      reply_markup: { remove_keyboard: true },
    });
    return true;
  }

  const profile = await findProfile(request.phone);
  if (request.mode === 'login' && !profile) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'لم يتم العثور على حساب بهذا الرقم. أنشئ حساباً أولاً من استشارة.',
      reply_markup: { remove_keyboard: true },
    });
    return true;
  }
  if (request.mode === 'signup' && profile) {
    await telegram('sendMessage', {
      chat_id: telegramUserId,
      text: 'هذا الرقم مرتبط بحساب موجود. استخدم تسجيل الدخول بدلاً من إنشاء حساب جديد.',
      reply_markup: { remove_keyboard: true },
    });
    return true;
  }

  const { error: verifyError } = await admin
    .from('telegram_login_requests')
    .update({
      status: 'telegram_verified',
      verified_profile_id: profile?.id ?? null,
      verified_at: null,
      telegram_user_id: telegramUserId,
      telegram_username: message.from?.username ?? null,
      telegram_first_name: message.from?.first_name ?? null,
      telegram_last_name: message.from?.last_name ?? null,
    })
    .eq('id', request.id)
    .eq('status', 'waiting')
    .is('session_claimed_at', null);
  if (verifyError) throw new Error(`تعذر تثبيت طلب Telegram: ${verifyError.message}`);

  if (profile?.id) {
    await admin
      .from('profiles')
      .update({ telegram_user_id: telegramUserId, updated_at: new Date().toISOString() })
      .eq('id', profile.id);
  }

  await telegram('sendMessage', {
    chat_id: telegramUserId,
    text: 'تم التحقق بنجاح. ارجع إلى استشارة، وسيتم إكمال العملية تلقائياً.',
    reply_markup: { remove_keyboard: true },
  });
  return true;
}

async function status(token: string) {
  const { data: request, error } = await admin
    .from('telegram_login_requests')
    .select('status,expires_at,telegram_user_id,mode,verified_profile_id,session_claimed_at')
    .eq('request_token', token)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!request) throw new Error('طلب التحقق غير موجود');
  if (request.session_claimed_at) {
    return {
      ok: false,
      status: 'used',
      mode: request.mode,
      verified_profile_id: request.verified_profile_id ?? null,
    };
  }
  if (new Date(request.expires_at).getTime() <= Date.now() && request.status !== 'verified') {
    return { ok: false, status: 'expired' };
  }
  return {
    ok: true,
    status: request.status,
    telegram_linked: !!request.telegram_user_id,
    mode: request.mode,
    verified_profile_id: request.verified_profile_id ?? null,
  };
}

async function claimSession(request: any) {
  const { data, error } = await admin.rpc('claim_telegram_login_session', {
    p_request_id: request.id,
    p_telegram_user_id: Number(request.telegram_user_id),
  });
  if (error) throw new Error(`تعذر تثبيت طلب Telegram: ${error.message}`);
  if (data !== true) {
    throw new Error('طلب Telegram تم استخدامه مسبقاً أو انتهت صلاحيته. ابدأ محاولة جديدة.');
  }
}

async function releaseSessionClaim(request: any) {
  await admin
    .from('telegram_login_requests')
    .update({ session_claimed_at: null })
    .eq('id', request.id)
    .eq('telegram_user_id', Number(request.telegram_user_id))
    .eq('status', 'telegram_verified');
}

async function createSessionForProfile(request: any, profile: any) {
  if (!profile?.auth_id) throw new Error('تعذر استرجاع الحساب المرتبط');

  const { data: userResult, error: userError } = await admin.auth.admin.getUserById(profile.auth_id);
  const user = userResult.user;
  if (userError || !user) throw new Error('تعذر استرجاع الحساب');

  let email = user.email || '';
  if (!email) {
    email = syntheticEmail(request.phone);
    const { error: emailError } = await admin.auth.admin.updateUserById(user.id, {
      email,
      email_confirm: true,
    });
    if (emailError) throw new Error(`تعذر تجهيز جلسة الدخول: ${emailError.message}`);
  }

  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email,
  });
  if (linkError || !link?.properties?.hashed_token) {
    throw new Error(`تعذر تجهيز جلسة الدخول: ${linkError?.message || 'رمز الجلسة غير متاح'}`);
  }

  await claimSession(request);
  try {
    const { data: login, error: loginError } = await authClient.auth.verifyOtp({
      token_hash: link.properties.hashed_token,
      type: 'email',
    });
    if (loginError || !login.session || login.user?.id !== user.id) {
      throw new Error(`تعذر إنشاء جلسة الدخول: ${loginError?.message || 'الجلسة غير متاحة'}`);
    }

    const { error: profileUpdateError } = await admin
      .from('profiles')
      .update({
        telegram_user_id: request.telegram_user_id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profile.id);
    if (profileUpdateError) throw new Error(`تعذر تحديث الحساب: ${profileUpdateError.message}`);

    const { error: requestUpdateError } = await admin
      .from('telegram_login_requests')
      .update({
        status: 'verified',
        verified_at: new Date().toISOString(),
        verified_profile_id: profile.id,
      })
      .eq('id', request.id)
      .eq('status', 'telegram_verified');
    if (requestUpdateError) throw new Error(`تعذر إكمال طلب Telegram: ${requestUpdateError.message}`);

    return {
      ok: true,
      access_token: login.session.access_token,
      refresh_token: login.session.refresh_token,
      userId: user.id,
    };
  } catch (error) {
    await releaseSessionClaim(request);
    throw error;
  }
}

async function createSignupProfile(request: any) {
  const email = syntheticEmail(request.phone);
  const password = randomPassword();
  const role = request.role === 'lawyer' ? 'lawyer' : 'user';
  const fullName = String(request.full_name || '').trim();
  if (fullName.length < 3) throw new Error('الاسم الكامل مطلوب');

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    phone: `+${request.phone}`,
    phone_confirm: true,
    user_metadata: { full_name: fullName, role },
  });
  if (createError) {
    throw new Error(
      /already|exists|registered|duplicate/i.test(createError.message)
        ? LINKED
        : `تعذر إنشاء الحساب: ${createError.message}`,
    );
  }

  const { error: insertError } = await admin.from('profiles').insert({
    auth_id: created.user.id,
    phone: request.phone,
    email,
    full_name: fullName,
    role,
    telegram_user_id: request.telegram_user_id,
  });
  if (insertError) {
    await admin.auth.admin.deleteUser(created.user.id);
    if (insertError.code === '23505') throw new Error(LINKED);
    throw new Error(`تعذر إنشاء ملف المستخدم: ${insertError.message}`);
  }

  const profile = await findProfile(request.phone);
  if (!profile) throw new Error('تم إنشاء الحساب لكن تعذر استرجاع الملف الشخصي.');
  await admin
    .from('telegram_login_requests')
    .update({ verified_profile_id: profile.id })
    .eq('id', request.id)
    .eq('status', 'telegram_verified');
  return profile;
}

async function verify(token: string, rawCode?: string) {
  const { data: request, error } = await admin
    .from('telegram_login_requests')
    .select('*')
    .eq('request_token', token)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!request) throw new Error('طلب التحقق غير موجود');
  if (request.session_claimed_at) {
    throw new Error('طلب Telegram تم استخدامه مسبقاً. ابدأ محاولة جديدة.');
  }
  if (new Date(request.expires_at).getTime() <= Date.now()) {
    await admin
      .from('telegram_login_requests')
      .update({ status: 'expired' })
      .eq('id', request.id)
      .in('status', ['waiting', 'code_sent', 'telegram_verified'])
      .is('session_claimed_at', null);
    throw new Error('انتهت صلاحية رمز التحقق. اطلب محاولة جديدة');
  }

  if (request.status === 'telegram_verified' && request.telegram_user_id) {
    let profile = null;
    if (request.verified_profile_id) profile = await findProfileById(request.verified_profile_id);
    if (!profile) profile = await findProfile(request.phone);

    if (request.mode === 'login') {
      if (!profile) throw new Error('لم يتم العثور على حساب مرتبط بهذا الرقم. يرجى إنشاء حساب أولاً.');
      if (
        profile.telegram_user_id &&
        Number(profile.telegram_user_id) !== Number(request.telegram_user_id)
      ) {
        throw new Error(LINKED);
      }
      if (normalizePhone(profile.phone) !== normalizePhone(request.phone)) {
        throw new Error('رقم الهاتف لا يطابق الحساب المرتبط.');
      }
      return await createSessionForProfile(request, profile);
    }

    if (request.mode === 'signup') {
      if (profile) {
        const sameTelegram =
          Number(profile.telegram_user_id) === Number(request.telegram_user_id) &&
          normalizePhone(profile.phone) === normalizePhone(request.phone);
        if (!sameTelegram) throw new Error(LINKED);
        return await createSessionForProfile(request, profile);
      }

      const existingTelegram = await findTelegramProfile(Number(request.telegram_user_id));
      if (existingTelegram) throw new Error(LINKED);
      profile = await createSignupProfile(request);
      return await createSessionForProfile(request, profile);
    }
  }

  // Legacy six-digit code flow retained for backward compatibility.
  const code = normalizeCode(rawCode || '');
  if (!request.telegram_user_id || request.status !== 'code_sent') {
    throw new Error(
      'لم تصل إشارة Telegram بعد. افتح Telegram واضغط «بدء» من رابط استشارة، ثم انتظر وصول الرمز.',
    );
  }
  if (!/^\d{6}$/.test(code)) throw new Error('رمز التحقق يجب أن يتكون من 6 أرقام');
  if ((request.attempts ?? 0) >= 5) {
    throw new Error('تم تجاوز عدد المحاولات المسموح بها. اطلب رمزاً جديداً');
  }

  const expected = await sha256(`${code}:${token}`);
  if (expected !== request.code_hash) {
    await admin
      .from('telegram_login_requests')
      .update({ attempts: (request.attempts ?? 0) + 1 })
      .eq('id', request.id)
      .eq('status', 'code_sent')
      .is('session_claimed_at', null);
    throw new Error('رمز التحقق غير صحيح');
  }

  const phone = request.phone;
  const mode = request.mode || 'login';
  let profile = await findProfile(phone);
  const telegramProfile = await findTelegramProfile(Number(request.telegram_user_id));
  if (
    telegramProfile &&
    (!profile ||
      telegramProfile.id !== profile.id ||
      normalizePhone(telegramProfile.phone) !== normalizePhone(phone))
  ) {
    throw new Error(LINKED);
  }
  if (mode === 'signup' && profile) throw new Error(LINKED);
  if (mode === 'login' && !profile) {
    throw new Error('لم يتم العثور على حساب مرتبط بهذا الرقم. يرجى إنشاء حساب أولاً.');
  }

  await admin
    .from('telegram_login_requests')
    .update({ status: 'telegram_verified' })
    .eq('id', request.id)
    .eq('status', 'code_sent')
    .is('session_claimed_at', null);
  request.status = 'telegram_verified';

  if (!profile) profile = await createSignupProfile(request);
  return await createSessionForProfile(request, profile);
}

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') return new Response('ok', { status: 200, headers: cors });
    const url = new URL(req.url);
    if (url.searchParams.get('webhook') === '1') return await webhook(req);
    if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed' }, 405);

    const body = await req.json();
    if (body.action === 'start') {
      return json(await start(body.phone, body.mode || 'login', body.full_name, body.role));
    }
    if (body.action === 'status') return json(await status(body.request_token));
    if (body.action === 'verify') return json(await verify(body.request_token, body.code));
    return json({ ok: false, error: 'إجراء غير معروف' }, 400);
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    const statusCode =
      message === LINKED || /مرتبط بحساب آخر|هذا الرقم مرتبط/.test(message)
        ? 400
        : /غير صحيح|غير موجود|انتهت|تجاوز|يجب أن|لم تصل إشارة|مطلوب|نوع الحساب|تم استخدامه مسبقاً/.test(
              message,
            )
          ? 400
          : 500;
    return json({ ok: false, error: message }, statusCode);
  }
});
