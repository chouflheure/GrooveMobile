const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const MAILGUN_API_KEY = defineSecret("MAILGUN_API_KEY");

// Not sensitive — just config. Swap MAILGUN_DOMAIN for a verified domain
// once one exists; until then Mailgun's sandbox only delivers to addresses
// added by hand to "Authorized Recipients" in the Mailgun dashboard.
const MAILGUN_DOMAIN = "sandbox08adca4c459c4f8bb3dbb311b9dca4eb.mailgun.org";
const MAILGUN_SENDER = `CourtConnect <noreply@${MAILGUN_DOMAIN}>`;

/** Adapted from the user-supplied template — tracking classes/attributes
 * and the third party's branding stripped, `link` substituted where the
 * Firebase console template used `%LINK%` (its own editor can't render
 * this table-based layout, hence sending it ourselves entirely). */
function buildResetEmailHtml(link) {
  return `
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td colspan="2" style="background-color:#ffffff;color:#1e1e1e;border:1px solid #e5e5e5;border-radius:0.375rem;padding:20px;padding-top:2rem;text-align:left;font-family:Arial,Helvetica,sans-serif">
          <h1 style="margin:0 0 16px 0;font-size:22px;">Votre demande de réinitialisation de mot de passe</h1>
          <strong>Bonjour !</strong><br><br>
          Vous avez demandé à réinitialiser votre mot de passe sur CourtConnect.<br><br>
          Afin de réinitialiser votre mot de passe, merci de cliquer sur le lien ci-dessous.<br>
          <table role="presentation" cellpadding="0" cellspacing="0" style="margin:16px auto;width:auto">
            <tr>
              <td style="background-color:#fbca4d;color:#1e1e1e;border:1px solid #fbca4d;border-radius:0.375rem;text-align:center">
                <a href="${link}" style="color:#1e1e1e;display:inline-block;font-size:18px;font-weight:700;line-height:1.3;padding:10px 20px;text-decoration:none" target="_blank">
                  Modifier votre mot de passe
                </a>
              </td>
            </tr>
          </table>
          Cordialement,<br><br>
          L'équipe CourtConnect<br><br><br>
          Si vous n'arrivez pas à cliquer sur le bouton "Modifier votre mot de passe", copiez et collez l'URL ci-dessous dans votre navigateur web :<br>
          <a href="${link}" style="color:#1e1e1e;font-weight:bold;text-decoration:underline;word-break:break-all" target="_blank">${link}</a>
        </td>
      </tr>
    </table>
  `;
}

exports.sendPasswordResetEmail = onCall(
  { region: "europe-west9", secrets: [MAILGUN_API_KEY] },
  async (request) => {
    const email = request.data && request.data.email;
    if (!email) {
      throw new HttpsError("invalid-argument", "Email requis.");
    }

    let link;
    try {
      link = await admin.auth().generatePasswordResetLink(email, {
        // Firebase's own default reset-completion page — unchanged, only
        // the email carrying this link is now custom.
        url: "https://ace-tennis-41dc7.firebaseapp.com",
      });
    } catch (e) {
      if (e.code === "auth/user-not-found") {
        throw new HttpsError("not-found", "Aucun compte associé à cet email.");
      }
      throw new HttpsError("internal", "Impossible de générer le lien de réinitialisation.");
    }

    const form = new URLSearchParams({
      from: MAILGUN_SENDER,
      to: email,
      subject: "Réinitialise ton mot de passe CourtConnect",
      html: buildResetEmailHtml(link),
    });

    const response = await fetch(
      `https://api.mailgun.net/v3/${MAILGUN_DOMAIN}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(`api:${MAILGUN_API_KEY.value()}`).toString("base64")}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: form,
      },
    );
    if (!response.ok) {
      throw new HttpsError("internal", `Mailgun a refusé l'envoi (${response.status}).`);
    }
  },
);
