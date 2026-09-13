export function health(request: Request): Response {
  if (request.method !== "GET")
    return Response.json(
      {
        error: {
          code: "method_not_allowed",
          message: "Use GET for health checks.",
          retryable: false,
        },
      },
      { status: 405, headers: { Allow: "GET" } },
    );
  return Response.json(
    { service: "nto-cloud", status: "ok", contractVersion: 1 },
    { headers: { "Cache-Control": "no-store" } },
  );
}
