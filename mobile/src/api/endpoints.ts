// One typed function per endpoint in docs/API.md.
import { apiFetch } from "./client";
import type {
  CreateWatchRequest,
  DeviceRequest,
  DeviceResponse,
  DryRunResponse,
  PingResponse,
  ResolutionRequest,
  ResolutionResponse,
  Store,
  UpdateWatchRequest,
  Watch,
  WatchDetail,
} from "./types";

export const getPing = () => apiFetch<PingResponse>("/ping");

export const getStores = () => apiFetch<Store[]>("/stores");

export const postResolution = (body: ResolutionRequest) =>
  apiFetch<ResolutionResponse>("/resolutions", { method: "POST", body });

export const getWatches = () => apiFetch<Watch[]>("/watches");

export const getWatch = (id: number) => apiFetch<WatchDetail>(`/watches/${id}`);

export const createWatch = (body: CreateWatchRequest) =>
  apiFetch<WatchDetail>("/watches", { method: "POST", body });

// URL-mode price check without persisting (backend dry_run).
export const dryRunUrl = (body: { url: string; store_id: number; name?: string }) =>
  apiFetch<DryRunResponse>("/watches", { method: "POST", body: { ...body, dry_run: true } });

export const updateWatch = (id: number, body: UpdateWatchRequest) =>
  apiFetch<WatchDetail>(`/watches/${id}`, { method: "PATCH", body });

export const deleteWatch = (id: number) => apiFetch<void>(`/watches/${id}`, { method: "DELETE" });

export const registerDevice = (body: DeviceRequest) =>
  apiFetch<DeviceResponse>("/devices", { method: "POST", body });
