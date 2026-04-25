# ts-pattern — exhaustive matching, no nested ternaries

`ts-pattern` is a runtime + type-system pattern-matching library for TypeScript. We adopt it as a project default because:

- **Exhaustiveness checking** — `.exhaustive()` makes TS error if a case is missing. Catches missed states at build time, not runtime.
- **Replaces nested ternaries** — long `a ? b : c ? d : e` chains are unreviewable; `match()` reads top-to-bottom like a switch with patterns.
- **Discriminated unions become trivial** — destructure on `kind`/`type` field with full inference.

## Install

### Single repo

```bash
bun add ts-pattern
# or: npm i ts-pattern / pnpm add ts-pattern / yarn add ts-pattern
```

### Monorepo — add as a catalog dep

If the workspace uses Bun catalogs (or pnpm catalogs), pin `ts-pattern` once at the root and reference it from each package. This avoids version drift across workspaces.

**Bun (recommended for new projects)** — root `package.json`:

```jsonc
{
  "workspaces": {
    "packages": ["packages/*", "apps/*"],
    "catalog": {
      "ts-pattern": "^5.5.0"
    }
  }
}
```

In a workspace package:

```jsonc
{
  "dependencies": {
    "ts-pattern": "catalog:"
  }
}
```

**pnpm** — `pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"
  - "apps/*"
catalogs:
  default:
    ts-pattern: ^5.5.0
```

In a workspace package:

```jsonc
{ "dependencies": { "ts-pattern": "catalog:" } }
```

## Always exhaustive

Default to `.exhaustive()`. The whole point of using ts-pattern is letting the type checker enforce coverage.

```ts
import { match, P } from "ts-pattern";

type Status =
  | { kind: "loading" }
  | { kind: "ready"; data: User }
  | { kind: "error"; error: Error };

function render(s: Status) {
  return match(s)
    .with({ kind: "loading" }, () => <Spinner />)
    .with({ kind: "ready" }, ({ data }) => <Profile user={data} />)
    .with({ kind: "error" }, ({ error }) => <ErrorBox message={error.message} />)
    .exhaustive(); // ← TS error if a kind is missing or a new variant is added
}
```

If you genuinely don't care about uncovered cases, use `.otherwise(() => default)`. But then justify it — most of the time you should add the case.

## When to migrate existing code

Replace these patterns with `match()`:

### 1. Nested ternaries (3+ levels)

❌
```tsx
const label = isLoading
  ? "Loading..."
  : error
    ? `Error: ${error.message}`
    : data
      ? data.title
      : "No data";
```

✅
```tsx
const label = match({ isLoading, error, data })
  .with({ isLoading: true }, () => "Loading...")
  .with({ error: P.not(undefined) }, ({ error }) => `Error: ${error.message}`)
  .with({ data: P.not(undefined) }, ({ data }) => data.title)
  .otherwise(() => "No data");
```

### 2. Long `if/else if` chains over a discriminated union

If the union has 3+ variants and you're branching on the discriminator, use `match`. The exhaustiveness check is the win.

### 3. `switch` on a string union without a default

`switch` lacks exhaustiveness in non-strict-bool mode and produces `any` in callbacks. `match()` is strictly safer.

### 4. Complex permission / state gates

Permission gates that combine role + feature flag + auth state read clearly as a `match()`:

```ts
const view = match({ role, hasFlag, isLoggedIn })
  .with({ isLoggedIn: false }, () => <Login />)
  .with({ role: "admin" }, () => <AdminDashboard />)
  .with({ role: "user", hasFlag: true }, () => <NewUserDashboard />)
  .with({ role: "user" }, () => <UserDashboard />)
  .exhaustive();
```

## When NOT to migrate

- **Simple binary ternaries.** `isOpen ? <A /> : <B />` is fine — `match()` would be noise.
- **Truly fall-through `if` statements** doing side effects, not value selection. `match()` is for choosing a value/component.
- **Performance-critical hot paths** with measured overhead. `match()` adds a small allocation; usually negligible, occasionally not.

## Major refactors — ask first

If migrating to `ts-pattern` would touch >20 files or restructure load-bearing branching, **stop and ask the user** before applying. Migrations of state machines, navigation gates, or reducer logic are easy to get subtly wrong; the user should sign off on the diff scope.

For small, isolated migrations (a single component's render branching), proceed without asking.

## Linting

If the project uses ESLint, consider:

```bash
bun add -D eslint-plugin-ts-pattern
```

It enforces `.exhaustive()` over `.otherwise()` where possible, which is the rule we want.
