import { validate } from "uuid";
import { getApiKey } from "@/lib/api-key";
import { Thread } from "@langchain/langgraph-sdk";
import { useQueryState } from "nuqs";
import {
  createContext,
  ReactNode,
  useCallback,
  useState,
  useMemo,
  Dispatch,
  SetStateAction,
} from "react";
import { createClient } from "./client";

export interface ThreadContextType {
  getThreads: () => Promise<Thread[]>;
  threads: Thread[];
  setThreads: Dispatch<SetStateAction<Thread[]>>;
  threadsLoading: boolean;
  setThreadsLoading: Dispatch<SetStateAction<boolean>>;
}

export const ThreadContext = createContext<ThreadContextType | undefined>(undefined);

function getThreadSearchMetadata(
  assistantId: string,
): { graph_id: string } | { assistant_id: string } {
  if (validate(assistantId)) {
    return { assistant_id: assistantId };
  } else {
    return { graph_id: assistantId };
  }
}

export function ThreadProvider({ children }: { children: ReactNode }) {
  const envApiUrl: string | undefined = process.env.NEXT_PUBLIC_API_URL;
  const envAssistantId: string | undefined =
    process.env.NEXT_PUBLIC_ASSISTANT_ID;
  const envAuthScheme: string | undefined = process.env.NEXT_PUBLIC_AUTH_SCHEME;

  const [apiUrl] = useQueryState("apiUrl", {
    defaultValue: envApiUrl || "",
  });
  const [assistantId] = useQueryState("assistantId");
  const [authScheme] = useQueryState("authScheme", {
    defaultValue: envAuthScheme || "",
  });
  const [threads, setThreads] = useState<Thread[]>([]);
  const [threadsLoading, setThreadsLoading] = useState(false);

  const finalApiUrl = apiUrl || envApiUrl;
  const sanitizedAssistantId = assistantId?.trim();
  const finalAssistantId = sanitizedAssistantId || envAssistantId;

  const getThreads = useCallback(async (): Promise<Thread[]> => {
    if (!finalApiUrl || !finalAssistantId) return [];
    const client = createClient(
      finalApiUrl,
      getApiKey() ?? undefined,
      authScheme || undefined
    );

    const threads = await client.threads.search({
      metadata: {
        ...getThreadSearchMetadata(finalAssistantId),
      },
      limit: 100,
    });

    return threads;
  }, [finalApiUrl, finalAssistantId, authScheme]);

  const value = useMemo(
    () => ({
      getThreads,
      threads,
      setThreads,
      threadsLoading,
      setThreadsLoading,
    }),
    [getThreads, threads, threadsLoading]
  );

  return (
    <ThreadContext.Provider value={value}>{children}</ThreadContext.Provider>
  );
}
