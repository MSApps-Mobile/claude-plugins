import axios, { AxiosError, AxiosInstance, AxiosRequestConfig } from "axios";
import { API_BASE_URL, REQUEST_TIMEOUT } from "../constants.js";

/** Singleton API client for Apify */
let client: AxiosInstance | null = null;

/** Get or create the Axios client */
function getClient(): AxiosInstance {
  if (!client) {
    const token = process.env.APIFY_API_TOKEN;
    if (!token) {
      throw new Error(
        "APIFY_API_TOKEN environment variable is required. " +
        "Get your token from Apify Console > Settings > Integrations."
      );
    }

    client = axios.create({
      baseURL: API_BASE_URL,
      timeout: REQUEST_TIMEOUT,
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    });
  }
  return client;
}

/** Make a typed API request */
export async function apiRequest<T>(
  endpoint: string,
  method: "GET" | "POST" | "PUT" | "DELETE" = "GET",
  data?: unknown,
  params?: Record<string, unknown>,
  config?: Partial<AxiosRequestConfig>
): Promise<T> {
  const response = await getClient().request<T>({
    url: endpoint,
    method,
    data,
    params,
    ...config,
  });
  return response.data;
}

/** Make an API request and unwrap the .data wrapper */
export async function apiRequestUnwrap<T>(
  endpoint: string,
  method: "GET" | "POST" | "PUT" | "DELETE" = "GET",
  data?: unknown,
  params?: Record<string, unknown>
): Promise<T> {
  const response = await apiRequest<{ data: T }>(endpoint, method, data, params);
  return response.data;
}

/** Format API errors into actionable messages */
export function handleApiError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<{ error?: { message?: string; type?: string } }>;

    if (axiosError.response) {
      const status = axiosError.response.status;
      const apiMessage = axiosError.response.data?.error?.message;
      const apiType = axiosError.response.data?.error?.type;

      switch (status) {
        case 400:
          return `Error: Bad request${apiMessage ? ` - ${apiMessage}` : ""}. Check your parameters.`;
        case 401:
          return "Error: Authentication failed. Check your APIFY_API_TOKEN is valid.";
        case 403:
          return "Error: Permission denied. You don't have access to this resource.";
        case 404:
          return `Error: Resource not found${apiMessage ? ` - ${apiMessage}` : ""}. Check the ID is correct.`;
        case 408:
          return "Error: Synchronous run timed out. Use async run instead and poll for results.";
        case 429:
          return "Error: Rate limit exceeded. Wait a moment and try again.";
        default:
          return `Error: API returned status ${status}${apiType ? ` (${apiType})` : ""}${apiMessage ? ` - ${apiMessage}` : ""}.`;
      }
    }

    if (axiosError.code === "ECONNABORTED") {
      return "Error: Request timed out. The operation may still be running on Apify.";
    }

    if (axiosError.code === "ECONNREFUSED") {
      return "Error: Cannot connect to Apify API. Check your network connection.";
    }
  }

  return `Error: ${error instanceof Error ? error.message : String(error)}`;
}

/** Helper: truncate response text if too long */
export function truncateIfNeeded(text: string, limit: number): string {
  if (text.length <= limit) return text;
  return text.slice(0, limit) + "\n\n...[Response truncated. Use offset/limit parameters to paginate.]";
}
