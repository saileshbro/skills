# State management

Global state lives **outside** the React tree. Don't lift everything through Context + props — Context re-renders the whole subtree on any change and turns into a quiet performance leak.

## Library choice

Any of these are fine. Pick one per project, don't mix:

- **Zustand** — small, hooks-first, easy to subscribe imperatively. Default pick.
- **Jotai** — atom-based, good for fine-grained derived state.
- **Redux Toolkit** — when the team already speaks Redux, or you need devtools/time-travel.
- **Valtio** — proxy-based, mutable-feeling. Good for mutable model objects.

Context is fine for **truly tree-scoped** concerns: theme, current user, navigation. It's not a state library.

## Read state through the library hook

```tsx
const cartCount = useCartStore(s => s.items.length);
```

Never read the raw store object during render. Selectors give you re-render granularity; raw reads don't.

```tsx
// ❌ entire component re-renders on any cart change
const cart = useCartStore.getState();

// ✅ re-renders only when count changes
const cartCount = useCartStore(s => s.items.length);
```

## Persistence

Subscribe to store changes and write them out. Don't watch state in `useEffect` — that fires on every render with the value, not on the change.

```tsx
useCartStore.subscribe(
  s => s.items,
  items => AsyncStorage.setItem("cart", JSON.stringify(items)),
);
```

Most libraries ship a persistence middleware (`zustand/middleware/persist`, `redux-persist`); prefer those over hand-rolling.

### Don't persist non-serializable values

Functions, class instances, refs, `Date` objects, `Map`/`Set` (without a custom serializer) — none of these survive a round trip through `JSON.stringify`. Either keep them out of the store or split them into a separate non-persisted slice.

## Hydration before first render

A "flash of empty UI" happens when persisted state loads asynchronously after the first paint. Block render until hydration completes:

```tsx
function Root() {
  const hasHydrated = useCartStore(s => s._hasHydrated);
  if (!hasHydrated) return <SplashScreen />;
  return <App />;
}
```

`zustand/middleware/persist` exposes `_hasHydrated` (or `onRehydrateStorage` callback). Other libraries have equivalents.

For Expo: pair this with `expo-splash-screen`'s `preventAutoHideAsync` / `hideAsync` so the native splash holds until hydrated.

## Reset on logout

Never rely on unmount to clean up global state — your store is module-level and doesn't unmount. Reset explicitly:

```tsx
const initialState = { user: null, cart: { items: [] } };

const useStore = create(set => ({
  ...initialState,
  reset: () => set(initialState),
}));

async function logout() {
  await api.logout();
  useStore.getState().reset();
  await AsyncStorage.multiRemove(["cart", "session"]);
}
```

Audit every store on logout. Forgetting one is how PII leaks across accounts on shared devices.

## Server state vs client state

Don't put server data in your client store. Use a query library (`@tanstack/react-query`, `swr`) for anything fetched. Client store is for UI state, user preferences, and locally-owned domain state. Mixing the two means you reinvent caching, invalidation, and refetching badly.
