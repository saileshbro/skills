# Navigation

Applies to React Navigation and Expo Router (which is built on it). Rules are identical; Expo Router's `Stack`/`Tabs` are thin wrappers over the native-stack / bottom-tabs navigators.

## Type every stack

Define a param list per stack. Never `any`. Never inline route name strings.

```ts
// types/navigation.ts
export type RootStackParamList = {
  Home: undefined;
  Product: { productId: string };
  Checkout: { cartId: string; coupon?: string };
};

export type RootStackScreenProps<T extends keyof RootStackParamList> =
  NativeStackScreenProps<RootStackParamList, T>;

// in a screen
type Props = RootStackScreenProps<"Product">;
function ProductScreen({ route, navigation }: Props) {
  const { productId } = route.params; // typed
}
```

For nested navigators:

```ts
declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
```

Now `useNavigation()` and `useRoute()` are typed everywhere without prop drilling.

## Only serializable params

Pass `id`s and primitives. Look the entity up in the destination screen via your store / query cache.

❌ Don't pass:
- Functions / callbacks (use store actions or context)
- Class instances, `Date` objects (pass timestamps)
- Refs, navigation objects, anything with methods

Why: navigation state is serialized for deep linking, state restoration, and dev tools. Non-serializable params silently break those.

## Use the hooks, not prop drilling

In nested components, reach for `useNavigation()` and `useRoute()`. Don't drill `navigation`/`route` props through five layers.

```tsx
const navigation = useNavigation<RootStackScreenProps<"Product">["navigation"]>();
```

## Never navigate inside `useEffect`

Navigation is a side effect of an event or a state change, not of a render. Either:

- An event handler triggered the navigate → call it there.
- Auth state changed → render a different stack (see below).

❌ Bad:
```tsx
useEffect(() => {
  if (!user) navigation.replace("Login");
}, [user]);
```

✅ Good — conditional stack rendering:
```tsx
function RootNavigator() {
  const user = useAuthStore(s => s.user);
  return user ? <AppStack /> : <AuthStack />;
}
```

When the auth state flips, React unmounts one stack and mounts the other. No imperative navigation, no race conditions.

## Permission gates with `Stack.Protected` (Expo Router v4+)

Declarative auth/role gating inside a stack. Routes evaluate the `guard` and unmount when it fails.

```tsx
// app/_layout.tsx
import { Stack } from "expo-router";
import { useAuthStore } from "@/stores/auth";

export default function RootLayout() {
  const isLoggedIn = useAuthStore(s => !!s.user);
  const isAdmin = useAuthStore(s => s.user?.role === "admin");

  return (
    <Stack>
      <Stack.Protected guard={isLoggedIn}>
        <Stack.Screen name="(tabs)" />
        <Stack.Protected guard={isAdmin}>
          <Stack.Screen name="admin" />
        </Stack.Protected>
      </Stack.Protected>

      <Stack.Protected guard={!isLoggedIn}>
        <Stack.Screen name="login" />
      </Stack.Protected>
    </Stack>
  );
}
```

Rules:
- Guards are **boolean reads** of state. Don't put async checks inside; resolve auth into a synchronous flag at the store level (with a hydrating splash if needed — see `state.md`).
- Nest `Stack.Protected` for compounded gates (logged-in **and** admin).
- Failed guards unmount the screen — you don't need to also `navigation.replace`.

For React Navigation without Expo Router, achieve the same with conditional stack rendering (the `RootNavigator` pattern above).

## `useFocusEffect` for focus-aware logic

Things that should run **when a screen gains focus** (refetch, start a video, log a screen view) belong in `useFocusEffect`, not `useEffect`. `useEffect` fires once on mount and never again — focus events go uncaught.

```tsx
useFocusEffect(
  useCallback(() => {
    analytics.screenView("Profile");
    const sub = startSession();
    return () => sub.end();
  }, []),
);
```

## Validate route params at screen entry

Params can be `undefined` in deep-linking, restoration, or buggy callsite scenarios. Validate at the door:

```tsx
function ProductScreen({ route }: RootStackScreenProps<"Product">) {
  const { productId } = route.params ?? {};
  if (!productId) {
    return <ErrorView message="Missing product id" />;
  }
  // ...
}
```

## `replace` vs `navigate`

`replace` (or Expo Router's `router.replace`) when going back makes no sense:

- After login (don't go back to login screen)
- After onboarding completion
- After a destructive flow ("delete account" → home)

`navigate`/`push` for normal forward flow.

## Dismiss the keyboard before navigating

`Keyboard.dismiss()` first, then navigate. Prevents the destination screen from rendering with a keyboard-insets layout. See `keyboard.md`.
