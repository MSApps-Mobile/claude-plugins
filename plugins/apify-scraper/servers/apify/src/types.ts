/** Apify API response wrapper */
export interface ApifyResponse<T> {
  data: T;
}

/** Apify list response with pagination */
export interface ApifyListResponse<T> {
  data: {
    total: number;
    count: number;
    offset: number;
    limit: number;
    items: T[];
    desc?: boolean;
  };
}

/** Actor summary from list endpoint */
export interface ActorSummary {
  id: string;
  name: string;
  username?: string;
  title?: string;
  description?: string;
  isPublic: boolean;
  createdAt: string;
  modifiedAt: string;
  stats?: {
    totalRuns?: number;
    totalUsers?: number;
  };
  defaultRunOptions?: RunOptions;
}

/** Actor detail */
export interface ActorDetail extends ActorSummary {
  versions?: ActorVersion[];
  defaultRunOptions?: RunOptions;
  exampleRunInput?: {
    contentType: string;
    body: string;
  };
  categories?: string[];
}

/** Actor version */
export interface ActorVersion {
  versionNumber: string;
  buildTag: string;
  sourceType: string;
  envVars?: EnvVar[];
}

/** Environment variable */
export interface EnvVar {
  name: string;
  value?: string;
  isSecret: boolean;
}

/** Run options */
export interface RunOptions {
  build?: string;
  timeoutSecs?: number;
  memoryMbytes?: number;
}

/** Actor run */
export interface ActorRun {
  id: string;
  actId: string;
  userId?: string;
  startedAt: string;
  finishedAt?: string;
  status: RunStatus;
  statusMessage?: string;
  buildId?: string;
  buildNumber?: string;
  meta?: Record<string, unknown>;
  stats?: RunStats;
  options?: RunOptions;
  defaultDatasetId: string;
  defaultKeyValueStoreId: string;
  defaultRequestQueueId: string;
  containerUrl?: string;
  exitCode?: number;
}

/** Run status enum */
export type RunStatus =
  | "READY"
  | "RUNNING"
  | "SUCCEEDED"
  | "FAILED"
  | "TIMING-OUT"
  | "TIMED-OUT"
  | "ABORTING"
  | "ABORTED";

/** Run statistics */
export interface RunStats {
  inputBodyLen?: number;
  restartCount?: number;
  resurrectCount?: number;
  memAvgBytes?: number;
  memMaxBytes?: number;
  memCurrentBytes?: number;
  cpuAvgUsage?: number;
  cpuMaxUsage?: number;
  cpuCurrentUsage?: number;
  netRxBytes?: number;
  netTxBytes?: number;
  durationMillis?: number;
  runTimeSecs?: number;
  computeUnits?: number;
}

/** Actor build */
export interface ActorBuild {
  id: string;
  actId: string;
  status: string;
  startedAt: string;
  finishedAt?: string;
  buildNumber: string;
  meta?: Record<string, unknown>;
  stats?: Record<string, unknown>;
}

/** Dataset summary */
export interface DatasetSummary {
  id: string;
  name?: string;
  userId?: string;
  createdAt: string;
  modifiedAt: string;
  accessedAt: string;
  itemCount: number;
  cleanItemCount?: number;
}

/** Key-Value Store summary */
export interface KeyValueStoreSummary {
  id: string;
  name?: string;
  userId?: string;
  createdAt: string;
  modifiedAt: string;
  accessedAt: string;
}

/** Key-Value Store record info */
export interface KeyValueStoreRecord {
  key: string;
  value: unknown;
  contentType?: string;
}

/** Key-Value Store key listing */
export interface KeyValueStoreKeys {
  items: Array<{ key: string; size: number; contentType: string }>;
  count: number;
  isTruncated: boolean;
  exclusiveStartKey?: string;
  nextExclusiveStartKey?: string;
}

/** Request Queue summary */
export interface RequestQueueSummary {
  id: string;
  name?: string;
  userId?: string;
  createdAt: string;
  modifiedAt: string;
  accessedAt: string;
  totalRequestCount: number;
  handledRequestCount: number;
  pendingRequestCount: number;
}

/** Schedule summary */
export interface ScheduleSummary {
  id: string;
  name?: string;
  userId?: string;
  isEnabled: boolean;
  isExclusive: boolean;
  cronExpression: string;
  timezone: string;
  createdAt: string;
  modifiedAt: string;
  lastRunAt?: string;
  nextRunAt?: string;
  actions?: ScheduleAction[];
}

/** Schedule action */
export interface ScheduleAction {
  type: "RUN_ACTOR" | "RUN_ACTOR_TASK";
  actorId?: string;
  actorTaskId?: string;
  runInput?: unknown;
  runOptions?: RunOptions;
}

/** Webhook summary */
export interface WebhookSummary {
  id: string;
  userId?: string;
  createdAt: string;
  modifiedAt: string;
  isAdHoc: boolean;
  eventTypes: string[];
  requestUrl: string;
  condition?: {
    actorId?: string;
    actorTaskId?: string;
    actorRunId?: string;
  };
  payloadTemplate?: string;
  shouldInterpolateStrings: boolean;
  isApifyIntegration: boolean;
  lastDispatch?: {
    status: string;
    finishedAt: string;
  };
}

/** Actor task */
export interface ActorTask {
  id: string;
  userId?: string;
  actId: string;
  name: string;
  title?: string;
  description?: string;
  createdAt: string;
  modifiedAt: string;
  options?: RunOptions;
  input?: unknown;
}
