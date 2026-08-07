const SUPPORT_EMAIL = "support@homesteadcontrol.com";

const BASE_STYLES = `
  :root {
    color-scheme: light dark;
    --background: #f5f5f7;
    --surface: rgba(255, 255, 255, 0.82);
    --text: #1d1d1f;
    --secondary: #6e6e73;
    --accent: #d66a1f;
    --hairline: rgba(0, 0, 0, 0.09);
    --shadow: rgba(0, 0, 0, 0.08);
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --background: #000;
      --surface: rgba(28, 28, 30, 0.82);
      --text: #f5f5f7;
      --secondary: #a1a1a6;
      --accent: #ff9f5a;
      --hairline: rgba(255, 255, 255, 0.12);
      --shadow: rgba(0, 0, 0, 0.34);
    }
  }

  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    min-height: 100vh;
    margin: 0;
    background: var(--background);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  a { color: inherit; }
  .shell { width: min(100% - 40px, 920px); margin: 0 auto; }
  header { padding: 22px 0; }
  nav { display: flex; align-items: center; justify-content: space-between; gap: 24px; }
  .brand { display: flex; align-items: center; gap: 11px; text-decoration: none; font-weight: 700; }
  .mark {
    width: 36px; height: 36px; display: grid; place-items: center;
    border-radius: 10px; color: white; background: linear-gradient(145deg, #f59e42, #c45416);
    box-shadow: 0 5px 14px rgba(196, 84, 22, 0.22);
  }
  .nav-links { display: flex; gap: 20px; }
  .nav-links a { color: var(--secondary); text-decoration: none; font-size: 0.94rem; }
  .nav-links a:hover { color: var(--text); }
  main { padding: 64px 0 80px; }
  .hero { max-width: 760px; padding: 48px 0 72px; }
  .eyebrow { color: var(--accent); font-weight: 650; letter-spacing: 0.01em; }
  h1 { margin: 12px 0 18px; font-size: clamp(3rem, 9vw, 5.8rem); line-height: 0.98; letter-spacing: -0.055em; }
  h2 { margin: 0 0 12px; font-size: clamp(1.55rem, 4vw, 2.15rem); letter-spacing: -0.025em; }
  h3 { margin: 0 0 8px; font-size: 1.05rem; }
  p, li { color: var(--secondary); font-size: 1.02rem; line-height: 1.65; }
  .lead { max-width: 650px; font-size: clamp(1.18rem, 3vw, 1.42rem); line-height: 1.5; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
  .card {
    padding: 26px; border: 1px solid var(--hairline); border-radius: 24px;
    background: var(--surface); box-shadow: 0 14px 40px var(--shadow);
  }
  .card p { margin: 0; }
  .content { max-width: 720px; }
  .content > section { margin-top: 42px; }
  .content ul { padding-left: 22px; }
  .contact {
    display: inline-block; margin-top: 8px; padding: 12px 18px; border-radius: 999px;
    background: var(--text); color: var(--background); text-decoration: none; font-weight: 650;
  }
  footer { padding: 28px 0 38px; border-top: 1px solid var(--hairline); }
  footer .shell { display: flex; justify-content: space-between; gap: 20px; flex-wrap: wrap; }
  footer p, footer a { margin: 0; color: var(--secondary); font-size: 0.88rem; }
  .disclosure { margin-top: 60px; font-size: 0.9rem; }
  @media (max-width: 700px) {
    .grid { grid-template-columns: 1fr; }
    .nav-links { gap: 12px; }
    main { padding-top: 32px; }
    .hero { padding-top: 26px; }
  }
`;

function layout(title: string, description: string, content: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="${description}" />
  <title>${title}</title>
  <style>${BASE_STYLES}</style>
</head>
<body>
  <header>
    <nav class="shell" aria-label="Main navigation">
      <a class="brand" href="/"><span class="mark" aria-hidden="true">H</span>Homestead</a>
      <div class="nav-links"><a href="/support">Support</a><a href="/privacy">Privacy</a></div>
    </nav>
  </header>
  <main class="shell">${content}</main>
  <footer>
    <div class="shell"><p>© 2026 Tyler Keegan</p><p><a href="/support">Support</a> · <a href="/privacy">Privacy</a></p></div>
  </footer>
</body>
</html>`;
}

function homePage(): string {
  return layout(
    "Homestead — Native control for your home",
    "Homestead is a focused native iPhone client for Home Assistant.",
    `<section class="hero">
      <p class="eyebrow">A native Home Assistant client for iPhone</p>
      <h1>Your home, beautifully organized.</h1>
      <p class="lead">Control rooms, devices, scenes, and automations through a fast, focused interface designed for iPhone.</p>
    </section>
    <section class="grid" aria-label="Highlights">
      <article class="card"><h2>At a glance</h2><p>Bring the controls and information that matter most into comfortable, customizable dashboards.</p></article>
      <article class="card"><h2>Built for iPhone</h2><p>Native navigation, widgets, notifications, and thoughtful interactions make your home feel at home on iOS.</p></article>
      <article class="card"><h2>Your system</h2><p>Connect to an existing Home Assistant installation and keep Home Assistant as the source of truth.</p></article>
    </section>
    <p class="disclosure">Homestead requires an existing Home Assistant installation. Homestead is an independent third-party client and is not affiliated with or endorsed by the Home Assistant project.</p>`
  );
}

function supportPage(): string {
  return layout(
    "Support — Homestead",
    "Get support for the Homestead iPhone app.",
    `<div class="content">
      <p class="eyebrow">Support</p>
      <h1>How can we help?</h1>
      <p class="lead">For help with Homestead, send an email with a brief description of what happened and the app version you’re using.</p>
      <a class="contact" href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>
      <section><h2>Before contacting support</h2><ul>
        <li>Confirm your Home Assistant server is reachable from Safari.</li>
        <li>In Homestead, open Settings and review the connection status.</li>
        <li>For purchase issues, try Restore Purchases from the Homestead+ screen.</li>
      </ul></section>
      <section><h2>Privacy</h2><p>Never send Home Assistant access tokens, passwords, or other private credentials. Homestead includes privacy-safe diagnostics that can be copied from Settings when useful.</p></section>
    </div>`
  );
}

function privacyPage(): string {
  return layout(
    "Privacy Policy — Homestead",
    "Privacy policy for the Homestead iPhone app.",
    `<article class="content">
      <p class="eyebrow">Last updated July 27, 2026</p>
      <h1>Privacy Policy</h1>
      <p class="lead">Homestead is a native client for Home Assistant. It connects directly to Home Assistant servers that you choose and stores Home Assistant credentials in the device Keychain.</p>
      <section><h2>Data Homestead handles</h2><ul>
        <li>Home Assistant server addresses, entity state, registry metadata, dashboards, and preferences needed to provide the app.</li>
        <li>Home Assistant sign-in credentials stored locally in the device Keychain.</li>
        <li>Notification delivery identifiers used to relay Home Assistant notifications to Apple Push Notification service.</li>
        <li>Optional iCloud key-value data for Homestead-owned server metadata, dashboards, safety preferences, and small appearance preferences. Credentials, Home Assistant state, notification secrets, widget snapshots, and wallpaper images are not placed in Homestead’s iCloud sync payload.</li>
        <li>App Store purchase and subscription status supplied by Apple through StoreKit.</li>
      </ul></section>
      <section><h2>Data sharing</h2><p>Homestead does not sell personal information or use third-party advertising. Home Assistant data is sent only to the Home Assistant servers configured by the user, Apple services required for platform features such as StoreKit, iCloud, and push notifications, and Homestead’s notification relay when remote Home Assistant notification delivery is enabled.</p></section>
      <section><h2>Storage and deletion</h2><p>Most Homestead data is stored on the user’s device. Removing a server or deleting the app removes its local data subject to normal device backups and Apple platform behavior. Users can disable Homestead iCloud sync in Settings and manage App Store purchases through their Apple Account.</p></section>
      <section><h2>Contact</h2><p>Questions about privacy or support can be sent to <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.</p></section>
    </article>`
  );
}

export function sitePageResponse(pathname: string, method: string): Response {
  const pages = new Map<string, string>([
    ["/", homePage()],
    ["/support", supportPage()],
    ["/privacy", privacyPage()]
  ]);
  const html = pages.get(pathname.replace(/\/$/, "") || "/");

  if ((method !== "GET" && method !== "HEAD") || !html) {
    return new Response("Not found.", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" }
    });
  }

  return new Response(method === "HEAD" ? null : html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff"
    }
  });
}
