import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  isAdminUserWithFallback,
  listAdminProfilesWithFallback,
  persistAdminWhatsAppNumberWithFallback,
} from "./admin-profile.ts";

type QueryResult = {
  data?: unknown;
  error?: unknown;
};

class FakeSupabase {
  constructor(
    private readonly handlers: Record<string, QueryResult>,
    private readonly updates: Array<Record<string, unknown>> = [],
  ) {}

  from(table: string) {
    return new FakeTable(table, this.handlers, this.updates);
  }
}

class FakeTable {
  constructor(
    private readonly table: string,
    private readonly handlers: Record<string, QueryResult>,
    private readonly updates: Array<Record<string, unknown>>,
  ) {}

  select(selection: string) {
    return new FakeQuery(this.table, selection, this.handlers);
  }

  update(payload: Record<string, unknown>) {
    return {
      eq: async (column: string, value: string) => {
        const key = `${this.table}:update:${column}:${value}`;
        this.updates.push({ table: this.table, payload, column, value });
        return this.handlers[key] ?? { data: null, error: null };
      },
    };
  }
}

class FakeQuery {
  constructor(
    private readonly table: string,
    private readonly selection: string,
    private readonly handlers: Record<string, QueryResult>,
  ) {}

  eq(column: string, value: string) {
    return new FakeEqQuery(
      this.table,
      this.selection,
      this.handlers,
      column,
      value,
    );
  }
}

class FakeEqQuery {
  constructor(
    private readonly table: string,
    private readonly selection: string,
    private readonly handlers: Record<string, QueryResult>,
    private readonly column: string,
    private readonly value: string,
  ) {}

  then<TResult1 = QueryResult, TResult2 = never>(
    onfulfilled?:
      | ((value: QueryResult) => TResult1 | PromiseLike<TResult1>)
      | null,
    _onrejected?:
      | ((reason: unknown) => TResult2 | PromiseLike<TResult2>)
      | null,
  ): Promise<TResult1 | TResult2> {
    const key =
      `${this.table}:select:${this.selection}:eq:${this.column}:${this.value}`;
    const result = this.handlers[key] ?? { data: [], error: null };
    return Promise.resolve(
      onfulfilled ? onfulfilled(result) : result as TResult1,
    );
  }

  async maybeSingle(): Promise<QueryResult> {
    const key =
      `${this.table}:select:${this.selection}:eq:${this.column}:${this.value}:maybeSingle`;
    return this.handlers[key] ?? { data: null, error: null };
  }
}

Deno.test("listAdminProfilesWithFallback falls back to legacy profiles table", async () => {
  const supabase = new FakeSupabase({
    "dinein_profiles:select:id, display_name, email, role, whatsapp_number:eq:role:admin":
      {
        error: { message: 'relation "dinein_profiles" does not exist' },
      },
    "dinein_profiles:select:id, display_name, role, whatsapp_number:eq:role:admin":
      {
        error: { message: 'relation "dinein_profiles" does not exist' },
      },
    "dinein_profiles:select:id, display_name, email, role:eq:role:admin": {
      error: { message: 'relation "dinein_profiles" does not exist' },
    },
    "dinein_profiles:select:id, display_name, role:eq:role:admin": {
      error: { message: 'relation "dinein_profiles" does not exist' },
    },
    "profiles:select:id, display_name, email, role, whatsapp_number:eq:role:admin":
      {
        data: [{ id: "admin-1", display_name: "Legacy Admin", role: "admin" }],
      },
  });

  const profiles = await listAdminProfilesWithFallback(supabase as never);

  assertEquals(profiles.length, 1);
  assertEquals(profiles[0].id, "admin-1");
});

Deno.test("isAdminUserWithFallback checks legacy profiles table", async () => {
  const supabase = new FakeSupabase({
    "dinein_profiles:select:role:eq:id:admin-1:maybeSingle": {
      error: { message: 'relation "dinein_profiles" does not exist' },
    },
    "profiles:select:role:eq:id:admin-1:maybeSingle": {
      data: { role: "admin" },
    },
  });

  const isAdmin = await isAdminUserWithFallback(supabase as never, "admin-1");

  assertEquals(isAdmin, true);
});

Deno.test("persistAdminWhatsAppNumberWithFallback updates legacy profiles table", async () => {
  const updates: Array<Record<string, unknown>> = [];
  const supabase = new FakeSupabase({
    "dinein_profiles:update:id:admin-1": {
      error: { message: 'relation "dinein_profiles" does not exist' },
    },
    "profiles:update:id:admin-1": { data: null, error: null },
  }, updates);

  await persistAdminWhatsAppNumberWithFallback(
    supabase as never,
    "admin-1",
    "+25075588248",
  );

  assertEquals(updates.length, 2);
  assertEquals(updates[1].table, "profiles");
});

Deno.test("listAdminProfilesWithFallback rethrows unexpected query failures", async () => {
  const supabase = new FakeSupabase({
    "dinein_profiles:select:id, display_name, email, role, whatsapp_number:eq:role:admin":
      {
        error: { message: "permission denied for table dinein_profiles" },
      },
  });

  await assertRejects(() => listAdminProfilesWithFallback(supabase as never));
});
