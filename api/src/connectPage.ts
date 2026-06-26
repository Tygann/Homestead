const CONNECT_PAGE_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Homestead</title>

  <link rel="redirect_uri" href="homestead://auth" />
  <style>
    :root {
      color-scheme: light dark;
      --background: #f5f5f7;
      --surface: rgba(255, 255, 255, 0.82);
      --text: #1d1d1f;
      --secondary: #6e6e73;
      --hairline: rgba(0, 0, 0, 0.08);
      --icon-start: #f5f7fb;
      --icon-end: #dce7ff;
      --icon-text: #1d4ed8;
      --shadow: rgba(0, 0, 0, 0.08);
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --background: #000;
        --surface: rgba(28, 28, 30, 0.78);
        --text: #f5f5f7;
        --secondary: #a1a1a6;
        --hairline: rgba(255, 255, 255, 0.12);
        --icon-start: #1f2937;
        --icon-end: #0f172a;
        --icon-text: #8ab4ff;
        --shadow: rgba(0, 0, 0, 0.32);
      }
    }

    * {
      box-sizing: border-box;
    }

    body {
      min-height: 100vh;
      margin: 0;
      display: grid;
      place-items: center;
      padding: 32px;
      background: var(--background);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
      text-align: center;
      -webkit-font-smoothing: antialiased;
    }

    main {
      width: min(100%, 420px);
      padding: 36px 30px 34px;
      border: 1px solid var(--hairline);
      border-radius: 28px;
      background: var(--surface);
      box-shadow: 0 18px 50px var(--shadow);
    }

    .mark {
      width: 72px;
      height: 72px;
      display: grid;
      place-items: center;
      margin: 0 auto 24px;
      border-radius: 18px;
      background: linear-gradient(145deg, var(--icon-start), var(--icon-end));
      border: 1px solid var(--hairline);
      color: var(--icon-text);
      font-size: 34px;
      font-weight: 700;
      letter-spacing: 0;
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 8vw, 3rem);
      line-height: 1.05;
      font-weight: 700;
      letter-spacing: 0;
    }

    .tagline {
      margin: 12px 0 0;
      font-size: 1.08rem;
      line-height: 1.45;
      color: var(--secondary);
    }

    .setup {
      margin: 28px 0 0;
      font-size: 0.98rem;
      line-height: 1.45;
      color: var(--secondary);
    }
  </style>
</head>
<body>
  <main>
    <div class="mark" aria-hidden="true">H</div>
    <h1>Homestead</h1>
    <p class="tagline">A native Home Assistant client for iPhone.</p>
    <p class="setup">Open Homestead on your iPhone to continue setup.</p>
  </main>
</body>
</html>
`;

export function connectPageResponse(): Response {
  return new Response(CONNECT_PAGE_HTML, {
    headers: {
      "content-type": "text/html; charset=utf-8"
    }
  });
}
