export class ClientRequestError extends Error {
  constructor(public status: number) {
    super(status === 401 ? 'Please sign in to continue.' : status === 403 ? 'Your account does not have access to this action.' : status === 404 ? 'This item is no longer available.' : status === 409 ? 'This item has changed. Refresh and try again.' : status === 422 ? 'Check the required details and your eligibility, then try again.' : 'We couldn’t complete this request. Please try again.');
  }
}
export async function clientAPI<T>(path: string, method = 'GET', body?: unknown, signal?: AbortSignal): Promise<T> {
  const options: RequestInit = {method,signal,cache:'no-store',headers:{'content-type':'application/json'}};
  if(body !== undefined && method !== 'GET') options.body=JSON.stringify(body);
  const response=await fetch(`/api/backend${path}`,options);
  if(!response.ok) throw new ClientRequestError(response.status);
  return response.status===204 ? undefined as T : await response.json() as T;
}
