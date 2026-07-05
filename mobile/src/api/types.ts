// Hand-written types mirroring docs/API.md. Money is always integer cents.

export type ListingStatus = "active" | "parse_failed" | "blocked" | "archived";
export type RuleKind = "below_price" | "percent_drop" | "amount_drop";
export type NotificationKind = "price_alert" | "parse_failure";

export interface Store {
  id: number;
  slug: string;
  name: string;
  supports_resolution: boolean;
}

export interface Rule {
  kind: RuleKind;
  value_cents: number | null;
  value_pct: number | null;
}

// Rule as sent to the backend (only the field its kind uses).
export interface RuleInput {
  kind: RuleKind;
  value_cents?: number;
  value_pct?: number;
}

export type StoreRef = Record<string, string>;

export interface Resolution {
  url: string;
  title: string | null;
  image_url: string | null;
  price_cents: number | null;
  currency: string;
  verified: boolean;
  store_ref: StoreRef;
}

export interface ResolvedProduct {
  gtin13: string | null;
  name: string | null;
  image_url: string | null;
}

export interface ResolutionResponse {
  product: ResolvedProduct;
  resolution: Resolution;
}

export interface LatestPrice {
  price_cents: number;
  currency: string;
  in_stock: boolean;
  checked_at: string;
}

export interface WatchProduct {
  name: string | null;
  image_url: string | null;
  gtin13: string | null;
}

export interface WatchStore {
  slug: string;
  name: string;
}

export interface WatchListing {
  url: string;
  status: ListingStatus;
  display_name: string | null;
}

export interface Watch {
  id: number;
  active: boolean;
  armed: boolean;
  baseline_price_cents: number;
  product: WatchProduct;
  store: WatchStore;
  listing: WatchListing;
  latest_price: LatestPrice | null;
  rules: Rule[];
  sparkline: number[];
}

export interface PricePoint {
  price_cents: number;
  in_stock: boolean;
  checked_at: string;
}

export interface NotificationItem {
  kind: NotificationKind;
  notified_price_cents: number | null;
  sent_at: string | null;
}

export interface WatchDetail extends Watch {
  price_points: PricePoint[];
  notifications: NotificationItem[];
}

// --- requests ---

export interface ResolutionRequest {
  barcode: string;
  symbology?: string;
  store_id: number;
}

export interface CreateWatchFromResolution {
  barcode: string;
  store_id: number;
  resolution: Resolution;
  baseline_price_cents?: number;
  rules: RuleInput[];
}

export interface CreateWatchFromUrl {
  url: string;
  store_id: number;
  name?: string;
  rules: RuleInput[];
}

export type CreateWatchRequest = CreateWatchFromResolution | CreateWatchFromUrl;

export interface UpdateWatchRequest {
  baseline_price_cents?: number;
  active?: boolean;
  rules?: RuleInput[];
}

export interface DryRunResponse {
  dry_run: true;
  price_cents: number;
  currency: string;
  in_stock: boolean;
}

export interface DeviceRequest {
  expo_push_token: string;
  platform?: string;
}

export interface DeviceResponse {
  id: number;
  active: boolean;
}

export interface PingResponse {
  ok: boolean;
}
