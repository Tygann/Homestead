const SUPPORT_EMAIL = "support@homesteadcontrol.com";

const BASE_STYLES = `
  :root {
    color-scheme: light dark;
    --background: #f5f5f7;
    --surface: rgba(255, 255, 255, 0.72);
    --surface-solid: #fff;
    --text: #1d1d1f;
    --secondary: #6e6e73;
    --accent: #d66a1f;
    --accent-soft: #fff1e7;
    --blue: #2678ff;
    --hairline: rgba(0, 0, 0, 0.09);
    --shadow: rgba(0, 0, 0, 0.08);
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --background: #000;
      --surface: rgba(28, 28, 30, 0.74);
      --surface-solid: #1c1c1e;
      --text: #f5f5f7;
      --secondary: #a1a1a6;
      --accent: #ff9f5a;
      --accent-soft: #3a2416;
      --blue: #64a0ff;
      --hairline: rgba(255, 255, 255, 0.12);
      --shadow: rgba(0, 0, 0, 0.34);
    }
  }

  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    min-height: 100vh;
    margin: 0;
    background:
      radial-gradient(circle at 75% 8%, rgba(255, 159, 90, 0.18), transparent 30rem),
      var(--background);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  a { color: inherit; }
  .shell { width: min(100% - 40px, 920px); margin: 0 auto; }
  header {
    position: sticky; top: 0; z-index: 10; padding: 14px 0;
    background: color-mix(in srgb, var(--background) 76%, transparent);
    border-bottom: 1px solid var(--hairline);
    backdrop-filter: saturate(180%) blur(20px);
  }
  nav { display: flex; align-items: center; justify-content: space-between; gap: 24px; }
  .brand { display: flex; align-items: center; gap: 11px; text-decoration: none; font-weight: 700; }
  .mark {
    width: 36px; height: 36px; display: grid; place-items: center;
    border-radius: 10px; color: white; background: linear-gradient(145deg, #f59e42, #c45416);
    box-shadow: 0 5px 14px rgba(196, 84, 22, 0.22);
  }
  .nav-links { display: flex; gap: 20px; }
  .nav-links a { color: var(--secondary); text-decoration: none; font-size: 0.94rem; font-weight: 550; }
  .nav-links a:hover { color: var(--text); }
  main { padding: 64px 0 80px; }
  .hero { display: grid; grid-template-columns: minmax(0, 1.05fr) minmax(280px, 0.72fr); align-items: center; gap: 72px; padding: 64px 0 86px; }
  .hero-copy { min-width: 0; }
  .eyebrow { color: var(--accent); font-weight: 650; letter-spacing: 0.01em; }
  h1 { margin: 12px 0 18px; font-size: clamp(3rem, 8vw, 5.4rem); line-height: 0.98; letter-spacing: -0.055em; }
  h2 { margin: 0 0 12px; font-size: clamp(1.55rem, 4vw, 2.15rem); letter-spacing: -0.025em; }
  h3 { margin: 0 0 8px; font-size: 1.05rem; }
  p, li { color: var(--secondary); font-size: 1.02rem; line-height: 1.65; }
  .lead { max-width: 650px; font-size: clamp(1.18rem, 3vw, 1.42rem); line-height: 1.5; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
  .card {
    padding: 26px; border: 1px solid var(--hairline); border-radius: 24px;
    background: var(--surface); box-shadow: 0 14px 40px var(--shadow);
    backdrop-filter: blur(22px);
  }
  .card p { margin: 0; }
  .content { max-width: 720px; }
  .content > section { margin-top: 42px; }
  .content ul { padding-left: 22px; }
  .contact {
    display: inline-block; margin-top: 8px; padding: 12px 18px; border-radius: 999px;
    background: var(--text); color: var(--background); text-decoration: none; font-weight: 650;
  }
  .cta-row { display: flex; align-items: center; gap: 14px; margin-top: 28px; flex-wrap: wrap; }
  .primary-cta {
    display: inline-flex; align-items: center; gap: 8px; padding: 13px 19px; border-radius: 999px;
    background: var(--text); color: var(--background); text-decoration: none; font-weight: 650;
  }
  .quiet-note { color: var(--secondary); font-size: 0.92rem; }
  .device-wrap { display: grid; place-items: center; perspective: 1200px; }
  .device {
    width: min(100%, 310px); aspect-ratio: 0.49; padding: 10px; border-radius: 48px;
    background: #18181a; box-shadow: 0 44px 90px rgba(0,0,0,0.24), 0 12px 30px rgba(196,84,22,0.14);
    transform: rotateY(-5deg) rotateX(2deg);
  }
  .screen {
    height: 100%; overflow: hidden; border-radius: 39px; padding: 38px 16px 18px;
    background: linear-gradient(180deg, #f5a665 0, #f7d2b2 28%, #f2f2f7 28%);
    color: #1d1d1f;
  }
  .island { width: 84px; height: 24px; margin: -29px auto 26px; border-radius: 18px; background: #070707; }
  .screen-top { display: flex; align-items: end; justify-content: space-between; margin-bottom: 18px; }
  .screen-top strong { font-size: 1.55rem; letter-spacing: -0.04em; }
  .avatar { width: 30px; height: 30px; display: grid; place-items: center; border-radius: 50%; background: rgba(255,255,255,0.72); font-size: 0.76rem; }
  .room-pills { display: flex; gap: 7px; overflow: hidden; margin-bottom: 12px; }
  .room-pills span { white-space: nowrap; padding: 6px 10px; border-radius: 12px; background: rgba(255,255,255,0.72); font-size: 0.64rem; font-weight: 650; }
  .room-pills span:first-child { color: white; background: #db6b26; }
  .tile-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 9px; }
  .tile { min-height: 92px; padding: 12px; border-radius: 19px; background: white; box-shadow: 0 5px 14px rgba(0,0,0,0.06); }
  .tile-icon { width: 30px; height: 30px; display: grid; place-items: center; border-radius: 50%; margin-bottom: 12px; background: #f2f2f7; color: #6e6e73; font-weight: 700; }
  .tile.on .tile-icon { color: white; background: #f59b3f; }
  .tile strong, .tile small { display: block; }
  .tile strong { font-size: 0.75rem; }
  .tile small { margin-top: 3px; color: #8e8e93; font-size: 0.62rem; }
  .feature-icon { width: 42px; height: 42px; display: grid; place-items: center; margin-bottom: 24px; border-radius: 13px; color: var(--accent); background: var(--accent-soft); font-size: 1.15rem; font-weight: 700; }
  .section-heading { max-width: 640px; margin-bottom: 28px; }
  .section-heading p { margin-bottom: 0; }
  footer { padding: 28px 0 38px; border-top: 1px solid var(--hairline); }
  footer .shell { display: flex; justify-content: space-between; gap: 20px; flex-wrap: wrap; }
  footer p, footer a { margin: 0; color: var(--secondary); font-size: 0.88rem; }
  .disclosure { margin-top: 60px; font-size: 0.9rem; }
  @media (max-width: 700px) {
    header { position: static; }
    .hero { grid-template-columns: 1fr; gap: 44px; padding-top: 40px; }
    .hero-copy { text-align: center; }
    .cta-row { justify-content: center; }
    .device { width: 270px; transform: none; }
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
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="Homestead" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  <meta property="og:image" content="https://homesteadcontrol.com/og.png" />
  <meta property="og:image:width" content="1731" />
  <meta property="og:image:height" content="909" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${description}" />
  <meta name="twitter:image" content="https://homesteadcontrol.com/og.png" />
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
      <div class="hero-copy">
        <p class="eyebrow">A native Home Assistant client</p>
        <h1>Your home, beautifully organized.</h1>
        <p class="lead">Comfortable controls, focused dashboards, and the details that matter—designed to feel right at home on iPhone.</p>
        <div class="cta-row"><a class="primary-cta" href="/support">Learn about Homestead <span aria-hidden="true">→</span></a><span class="quiet-note">Requires Home Assistant</span></div>
      </div>
      <div class="device-wrap" aria-label="Preview of a Homestead dashboard">
        <div class="device"><div class="screen">
          <div class="island" aria-hidden="true"></div>
          <div class="screen-top"><strong>Home</strong><span class="avatar">TK</span></div>
          <div class="room-pills"><span>Overview</span><span>Living Room</span><span>Kitchen</span></div>
          <div class="tile-grid">
            <div class="tile on"><span class="tile-icon">●</span><strong>Living Room</strong><small>3 lights on</small></div>
            <div class="tile"><span class="tile-icon">72°</span><strong>Climate</strong><small>Heating to 72°</small></div>
            <div class="tile"><span class="tile-icon">⌂</span><strong>Front Door</strong><small>Locked</small></div>
            <div class="tile on"><span class="tile-icon">▶</span><strong>Evening</strong><small>Scene active</small></div>
          </div>
        </div></div>
      </div>
    </section>
    <section aria-labelledby="features-title">
      <div class="section-heading"><p class="eyebrow">Made for everyday control</p><h2 id="features-title">Powerful without feeling complicated.</h2><p>Homestead keeps Home Assistant as the source of truth and gives it a focused, native front door.</p></div>
      <div class="grid" aria-label="Highlights">
        <article class="card"><span class="feature-icon" aria-hidden="true">⌂</span><h2>At a glance</h2><p>Bring the controls and information that matter most into comfortable, customizable dashboards.</p></article>
        <article class="card"><span class="feature-icon" aria-hidden="true">◎</span><h2>Native by design</h2><p>Familiar navigation, widgets, notifications, and responsive controls fit naturally into iOS.</p></article>
        <article class="card"><span class="feature-icon" aria-hidden="true">↗</span><h2>Your system</h2><p>Connect to your existing Home Assistant installation without replacing the automations and logic you trust.</p></article>
      </div>
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
      <p class="eyebrow">Last updated August 7, 2026</p>
      <h1>Privacy Policy</h1>
      <p class="lead">Homestead is a native client for Home Assistant. It connects directly to Home Assistant servers that you choose and stores Home Assistant credentials in the device Keychain.</p>
      <section><h2>Data Homestead handles</h2><ul>
        <li>Home Assistant server addresses, entity state, registry metadata, dashboards, and preferences needed to provide the app.</li>
        <li>Home Assistant sign-in credentials stored locally in the device Keychain.</li>
        <li>Pseudonymous notification delivery identifiers used to relay Home Assistant notifications to Apple Push Notification service. The notification relay does not retain the device name or app version.</li>
        <li>Optional iCloud key-value data for Homestead-owned server metadata, dashboards, safety preferences, and small appearance preferences. Credentials, Home Assistant state, notification secrets, widget snapshots, and wallpaper images are not placed in Homestead’s iCloud sync payload.</li>
        <li>App Store purchase and subscription status supplied by Apple through StoreKit.</li>
      </ul></section>
      <section><h2>Data sharing</h2><p>Homestead does not sell personal information or use third-party advertising. Home Assistant data is sent only to the Home Assistant servers configured by the user, Apple services required for platform features such as StoreKit, iCloud, and push notifications, and Homestead’s notification relay when remote Home Assistant notification delivery is enabled.</p></section>
      <section><h2>Storage and deletion</h2><p>Most Homestead data is stored on the user’s device. Removing a server or deleting the app removes its local data subject to normal device backups and Apple platform behavior. Notification relay identifiers expire automatically 90 days after the most recent registration. Users can disable Homestead iCloud sync in Settings, manage App Store purchases through their Apple Account, and request earlier deletion of notification relay data by contacting support.</p></section>
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
