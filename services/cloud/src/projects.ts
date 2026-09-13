import type { Project, CloudError } from "@nto/shared-types";
export class CloudRequestError extends Error {
  constructor(public detail: CloudError) {
    super(detail.message);
  }
}
export interface ProjectClient {
  list(accessToken: string): Promise<Project[]>;
  create(title: string, ownerId: string, accessToken: string): Promise<Project>;
}
interface ProjectRow {
  id: string;
  owner_id: string;
  title: string;
  created_at: string;
}
export function projectClient(
  url: string,
  publishableKey: string,
): ProjectClient {
  async function request(
    method: string,
    token: string,
    body?: unknown,
  ): Promise<Project[]> {
    let response: Response;
    try {
      response = await fetch(`${url}/rest/v1/projects?select=*`, {
        method,
        headers: {
          apikey: publishableKey,
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch {
      throw new CloudRequestError({
        code: "network_error",
        message: "Could not reach NTO Cloud. Try again when connected.",
        retryable: true,
      });
    }
    if (!response.ok)
      throw new CloudRequestError({
        code: response.status === 401 ? "session_expired" : "request_failed",
        message:
          response.status === 401
            ? "Sign in again to continue."
            : "The Cloud project request failed.",
        retryable: response.status >= 500 || response.status === 429,
      });
    const rows = (await response.json()) as ProjectRow[];
    return rows.map((row) => ({
      id: row.id,
      ownerId: row.owner_id,
      title: row.title,
      createdAt: row.created_at,
    }));
  }
  return {
    list: (token) => request("GET", token),
    create: async (title, ownerId, token) => {
      if (!title.trim())
        throw new CloudRequestError({
          code: "invalid_title",
          message: "A project title is required.",
          retryable: false,
        });
      const rows = await request("POST", token, {
        title: title.trim(),
        owner_id: ownerId,
      });
      if (!rows[0])
        throw new CloudRequestError({
          code: "invalid_response",
          message: "Cloud returned no project.",
          retryable: false,
        });
      return rows[0];
    },
  };
}
