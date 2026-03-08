// functions/index.js
// Firebase Cloud Function — sends employee welcome email via Resend API
//
// Deploy:
//   cd functions && npm install
//   firebase deploy --only functions
//
// Your Resend API key is already embedded below.
// IMPORTANT: Change the `from:` address to your verified domain once you add
// one in Resend dashboard (https://resend.com/domains).
// Until then, use the default resend.dev address — it still has great deliverability.

const functions = require("firebase-functions");
const admin     = require("firebase-admin");
const https     = require("https");

admin.initializeApp();

// ── Your Resend API key ──────────────────────────────────────────────────────
const RESEND_API_KEY = "re_JVU79Hhw_6jY4m6tvjGVk9byNneA3j8Kp";

// ── Your "from" address ──────────────────────────────────────────────────────
// Option A (works immediately, no domain needed):
//   "Laundrify Team <onboarding@resend.dev>"
// Option B (after verifying your domain in Resend):
//   "Laundrify Team <onboarding@yourdomain.com>"
const FROM_ADDRESS = "Laundrify Team <onboarding@resend.dev>";

// ─── Helper: call Resend REST API ────────────────────────────────────────────
function sendViaResend(payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const options = {
      hostname: "api.resend.com",
      path:     "/emails",
      method:   "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type":  "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data",  (chunk) => (data += chunk));
      res.on("end",   () => {
        try   { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

// ─── Cloud Function: sendEmployeeWelcomeEmail ─────────────────────────────────
exports.sendEmployeeWelcomeEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const { name, email, phone, role, employeeId } = data;

  if (!email || !name) {
    throw new functions.https.HttpsError("invalid-argument", "name and email are required.");
  }

  const roleLabel = {
    delivery: "Delivery Agent",
    manager:  "Manager",
    staff:    "Staff Member",
    admin:    "Administrator",
  }[role?.toLowerCase()] ?? (role ?? "Team Member");

  // ── HTML Email Template ────────────────────────────────────────────────────
  const phoneRow = phone ? `
    <tr>
      <td style="padding:10px 0;border-bottom:1px solid #e8edf5;">
        <span style="color:#6b7280;font-size:12px;text-transform:uppercase;
                     letter-spacing:0.5px;font-weight:600;">Phone</span><br/>
        <strong style="color:#080F1E;font-size:15px;">${phone}</strong>
      </td>
    </tr>` : "";

  const steps = [
    `Download the <strong>Laundrify</strong> app on your Android or iOS device.`,
    `Open the app and tap <strong>Sign In</strong>.`,
    `Use your email: <strong style="color:#1B4FD8;">${email}</strong>`,
    `You'll be taken directly to your <strong>${roleLabel} dashboard</strong>.`,
  ];

  const stepsHtml = steps.map((s, i) => `
    <tr>
      <td style="padding:6px 0;vertical-align:top;">
        <table cellpadding="0" cellspacing="0"><tr>
          <td style="width:28px;height:28px;min-width:28px;background:#1B4FD8;
                     border-radius:50%;text-align:center;vertical-align:middle;">
            <span style="color:#fff;font-size:12px;font-weight:900;">${i+1}</span>
          </td>
          <td style="padding-left:12px;color:#374151;font-size:14px;line-height:1.55;">
            ${s}
          </td>
        </tr></table>
      </td>
    </tr>`).join("");

  const htmlBody = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Welcome to Laundrify</title>
</head>
<body style="margin:0;padding:0;background:#f0f4ff;
             font-family:'Segoe UI',Helvetica,Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0"
       style="background:#f0f4ff;padding:40px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0"
       style="max-width:600px;width:100%;background:#ffffff;border-radius:20px;
              overflow:hidden;box-shadow:0 4px 32px rgba(8,15,30,0.12);">

  <!-- ── Header ── -->
  <tr>
    <td style="background:linear-gradient(135deg,#080F1E 0%,#1B4FD8 100%);
               padding:44px 48px 36px;text-align:center;">
      <div style="font-size:44px;line-height:1;margin-bottom:10px;">🧺</div>
      <h1 style="margin:0;color:#ffffff;font-size:30px;font-weight:900;
                 letter-spacing:-0.5px;">Laundrify</h1>
      <p style="margin:8px 0 0;color:rgba(255,255,255,0.65);font-size:14px;">
        Fresh &amp; Clean, Every Time
      </p>
    </td>
  </tr>

  <!-- ── Gold banner ── -->
  <tr>
    <td style="background:#F5C518;padding:14px 48px;text-align:center;">
      <p style="margin:0;color:#080F1E;font-size:13px;font-weight:900;letter-spacing:1px;">
        🎉 &nbsp;YOU'VE BEEN ADDED TO THE TEAM
      </p>
    </td>
  </tr>

  <!-- ── Body ── -->
  <tr>
    <td style="padding:44px 48px 36px;">

      <h2 style="margin:0 0 6px;color:#080F1E;font-size:24px;font-weight:800;">
        Hi ${name}! 👋
      </h2>
      <p style="margin:0 0 28px;color:#6b7280;font-size:15px;line-height:1.65;">
        You have been successfully added to the
        <strong style="color:#080F1E;">Laundrify</strong> team.
        Here are your details — please keep them safe.
      </p>

      <!-- Details card -->
      <table width="100%" cellpadding="0" cellspacing="0"
             style="background:#f8faff;border-radius:14px;
                    border:1.5px solid #e8edf5;margin-bottom:32px;">
        <tr><td style="padding:20px 24px;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td style="padding:10px 0;border-bottom:1px solid #e8edf5;">
                <span style="color:#6b7280;font-size:12px;text-transform:uppercase;
                             letter-spacing:0.5px;font-weight:600;">Employee ID</span><br/>
                <strong style="color:#080F1E;font-size:15px;">${employeeId}</strong>
              </td>
            </tr>
            <tr>
              <td style="padding:10px 0;border-bottom:1px solid #e8edf5;">
                <span style="color:#6b7280;font-size:12px;text-transform:uppercase;
                             letter-spacing:0.5px;font-weight:600;">Role</span><br/>
                <strong style="color:#1B4FD8;font-size:15px;">${roleLabel}</strong>
              </td>
            </tr>
            <tr>
              <td style="padding:10px 0;${phone ? "border-bottom:1px solid #e8edf5;" : ""}">
                <span style="color:#6b7280;font-size:12px;text-transform:uppercase;
                             letter-spacing:0.5px;font-weight:600;">Login Email</span><br/>
                <strong style="color:#080F1E;font-size:15px;">${email}</strong>
              </td>
            </tr>
            ${phoneRow}
          </table>
        </td></tr>
      </table>

      <!-- Steps -->
      <h3 style="margin:0 0 14px;color:#080F1E;font-size:16px;font-weight:800;">
        📱 How to Get Started
      </h3>
      <table width="100%" cellpadding="0" cellspacing="0">
        ${stepsHtml}
      </table>

    </td>
  </tr>

  <!-- ── Divider ── -->
  <tr><td style="padding:0 48px;"><hr style="border:none;border-top:1px solid #e8edf5;"/></td></tr>

  <!-- ── Footer ── -->
  <tr>
    <td style="padding:24px 48px 36px;text-align:center;">
      <p style="margin:0;color:#9ca3af;font-size:12px;line-height:1.7;">
        This email was sent because you were added to the
        <strong>Laundrify</strong> team.<br/>
        If this is a mistake, please ignore this email.
      </p>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;

  // Plain-text fallback — critical for inbox delivery, spam filters require it
  const textBody = [
    `Hi ${name},`,
    ``,
    `Welcome to Laundrify! You have been added as a ${roleLabel}.`,
    ``,
    `YOUR DETAILS`,
    `  Employee ID : ${employeeId}`,
    `  Role        : ${roleLabel}`,
    `  Login Email : ${email}`,
    phone ? `  Phone       : ${phone}` : null,
    ``,
    `HOW TO GET STARTED`,
    `  1. Download the Laundrify app on your Android or iOS device.`,
    `  2. Tap Sign In.`,
    `  3. Use your email: ${email}`,
    `  4. You will be taken to your ${roleLabel} dashboard.`,
    ``,
    `If you have any questions, contact your manager.`,
    ``,
    `Welcome aboard!`,
    `The Laundrify Team`,
  ].filter(l => l !== null).join("\n");

  try {
    const result = await sendViaResend({
      from:    FROM_ADDRESS,
      to:      [email],
      subject: `Welcome to Laundrify — You're now a ${roleLabel}! 🎉`,
      html:    htmlBody,
      text:    textBody,
    });

    functions.logger.info(`Resend response: ${result.status}`, result.body);

    if (result.status === 200 || result.status === 201) {
      // Audit log
      await admin.firestore().collection("email_logs").add({
        to:         email,
        type:       "employee_welcome",
        employeeId: employeeId,
        name:       name,
        role:       role,
        sentAt:     admin.firestore.FieldValue.serverTimestamp(),
        status:     "sent",
        resendId:   result.body?.id ?? null,
      });
      return { success: true, messageId: result.body?.id };
    } else {
      functions.logger.error("Resend rejected:", result.body);
      throw new functions.https.HttpsError(
        "internal",
        `Email send failed (${result.status}): ${JSON.stringify(result.body)}`
      );
    }
  } catch (err) {
    functions.logger.error("sendEmployeeWelcomeEmail error:", err);
    throw new functions.https.HttpsError("internal", err.message ?? "Unknown error");
  }
});