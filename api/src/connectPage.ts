const CONNECT_PAGE_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Homestead</title>

  <link rel="redirect_uri" href="homestead://auth" />
</head>
<body>
  <h1>Homestead</h1>
  <p>Native Home Assistant client.</p>
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
