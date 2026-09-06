import { withSupabase } from 'npm:@supabase/server@^1';
import { importPKCS8, SignJWT } from 'npm:jose@6';

interface NotificationRecord {
  id: string;
  user_id: string;
  title?: string | null;
  body?: string | null;
  type?: string | null;
  reference_id?: string | null;
  reference_type?: string | null;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: NotificationRecord;
  old_record: NotificationRecord | null;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

async function getAccessToken(serviceAccount: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(serviceAccount.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google OAuth token request failed: ${await response.text()}`);
  }

  const data = await response.json();
  return data.access_token as string;
}

export default {
  fetch: withSupabase({ auth: 'secret' }, async (request, ctx) => {
    try {
      if (request.method !== 'POST') {
        return Response.json({ error: 'Method not allowed' }, { status: 405 });
      }

      const payload = (await request.json()) as WebhookPayload;
      if (payload.type !== 'INSERT' || payload.table !== 'notifications' || payload.schema !== 'public') {
        return Response.json({ ok: true, skipped: true });
      }

      const serviceAccount = JSON.parse(requireEnv('FCM_SERVICE_ACCOUNT_JSON')) as Record<string, string>;
      const projectId = serviceAccount.project_id || requireEnv('FIREBASE_PROJECT_ID');

      const { data: devices, error } = await ctx.supabaseAdmin
        .from('push_device_tokens')
        .select('id, token')
        .eq('user_id', payload.record.user_id)
        .eq('is_active', true);

      if (error) throw error;
      if (!devices?.length) return Response.json({ ok: true, sent: 0 });

      const accessToken = await getAccessToken(serviceAccount);
      const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      let sent = 0;
      const invalidDeviceIds: string[] = [];

      for (const device of devices) {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: payload.record.title ?? 'إشعار جديد',
                body: payload.record.body ?? '',
              },
              data: {
                notification_id: payload.record.id,
                type: payload.record.type ?? '',
                reference_id: payload.record.reference_id ?? '',
                reference_type: payload.record.reference_type ?? '',
              },
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: 'law_connect_channel',
                  sound: 'default',
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                  },
                },
              },
            },
          }),
        });

        if (response.ok) {
          sent += 1;
          continue;
        }

        const errorText = await response.text();
        if (/UNREGISTERED|INVALID_ARGUMENT/i.test(errorText)) {
          invalidDeviceIds.push(device.id);
        } else {
          console.error('FCM delivery failed', { deviceId: device.id, errorText });
        }
      }

      if (invalidDeviceIds.length) {
        await ctx.supabaseAdmin
          .from('push_device_tokens')
          .update({ is_active: false })
          .in('id', invalidDeviceIds);
      }

      return Response.json({ ok: true, sent, invalidated: invalidDeviceIds.length });
    } catch (error) {
      console.error('send-native-push failed', error);
      return Response.json({ error: String(error) }, { status: 500 });
    }
  }),
};
