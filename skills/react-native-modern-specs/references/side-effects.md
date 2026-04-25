# Side effects: move them out of render

The default answer to "where does this side effect go?" is **not** `useEffect`. Most `useEffect` calls in real codebases are bugs in disguise: doubled fetches, stale closures, render→effect→setState→render loops, sync-two-pieces-of-state ladders.

## Decision order

When you're tempted to write `useEffect`, walk this list in order. Stop at the first match:

1. **Is it a user-triggered side effect?** → event handler (`onPress`, `onSubmit`, `onChange`).
2. **Is it derived from existing state?** → compute it during render (no state, no effect).
3. **Is it a reaction to global state changing?** → store subscription (the state-management library's hook), not a `useEffect` watching a hook value.
4. **Is it data fetching?** → query library (`@tanstack/react-query`, `swr`, `tRPC`) or load into the store. Never `fetch().then(setState)`.
5. **Is it a screen-focus thing?** → `useFocusEffect` (React Navigation / Expo Router). Not `useEffect`.
6. **Is it an app-state thing?** → `useAppState` (or `AppState` listener wrapped in a hook). Not `useEffect`.
7. **Is it imperative third-party setup that has no library hook?** → `useEffect` with cleanup, or `useMountEffect` for one-shot mount logic. Comment **why** it can't be avoided.

If you reach step 7, leave a comment in the code: `// useEffect: <why this can't be a handler/derived/subscription>`. That comment is the only acceptable form of documentation that this is intentional.

## The five replacement patterns

### 1. Derive state inline

❌ Bad — extra render, possible stale state:
```tsx
const [filtered, setFiltered] = useState<Product[]>([]);
useEffect(() => {
  setFiltered(products.filter(p => p.inStock));
}, [products]);
```

✅ Good:
```tsx
const filtered = products.filter(p => p.inStock);
// or memoize if measurably expensive:
const filtered = useMemo(() => products.filter(p => p.inStock), [products]);
```

### 2. Use a query library for data fetching

❌ Bad — race conditions, no cancellation, no caching:
```tsx
useEffect(() => {
  let cancelled = false;
  fetch(`/api/users/${id}`)
    .then(r => r.json())
    .then(u => { if (!cancelled) setUser(u); });
  return () => { cancelled = true; };
}, [id]);
```

✅ Good:
```tsx
const { data: user, isLoading } = useQuery({
  queryKey: ["user", id],
  queryFn: () => fetchUser(id),
});
```

### 3. Handle user actions in event handlers

❌ Bad — relay flag through state just to trigger an effect:
```tsx
const [submitting, setSubmitting] = useState(false);
useEffect(() => {
  if (submitting) {
    api.submit(form).finally(() => setSubmitting(false));
  }
}, [submitting]);
// ...
<Pressable onPress={() => setSubmitting(true)}>...</Pressable>
```

✅ Good:
```tsx
<Pressable onPress={async () => { await api.submit(form); }}>...</Pressable>
```

### 4. Subscribe to the store, don't `useEffect` the hook output

❌ Bad — runs after render, doubled with strict mode:
```tsx
const cart = useCartStore(s => s.items);
useEffect(() => {
  analytics.track("cart_changed", cart);
}, [cart]);
```

✅ Good — react to the change at the source:
```tsx
// once at module setup
useCartStore.subscribe(
  s => s.items,
  items => analytics.track("cart_changed", items),
);
```

### 5. Reset state with `key`, not effect-driven `setState`

❌ Bad:
```tsx
function Editor({ docId }: { docId: string }) {
  const [draft, setDraft] = useState("");
  useEffect(() => { setDraft(""); }, [docId]); // reset on doc change
  return <TextInput value={draft} onChangeText={setDraft} />;
}
```

✅ Good — let React unmount/remount:
```tsx
function EditorWrapper({ docId }: { docId: string }) {
  return <Editor key={docId} docId={docId} />;
}
```

## What `useEffect` legitimately does

The acceptable list is short:

- Setting up an imperative third-party API that has no hook (e.g. wiring a non-React video player, attaching a native module listener for which no library hook exists). Always with cleanup.
- Subscribing to an external event emitter. Always with cleanup.

That's it. If your effect is doing something else, one of the five patterns above applies.

## React 19 escape hatches

- `useEffectEvent` — extract non-reactive logic out of an effect so it doesn't re-run on every dependency change. Use to prune dependency arrays without lying about reactivity.
- `use()` — read promises and contexts inside render. Cuts most "fetch in effect" patterns when paired with Suspense.
- Ref-as-prop — no more `forwardRef` boilerplate.

## Comment requirement

Every surviving `useEffect` in the codebase needs a one-line comment explaining why none of the alternatives apply. If a reviewer can't tell from the comment whether the effect is necessary, the comment is wrong.

```tsx
// useEffect: imperative subscription to a native module without a library hook
useEffect(() => {
  const sub = NativeFooModule.addListener("event", handler);
  return () => sub.remove();
}, []);
```
