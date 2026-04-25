# Modern API replacements + footguns

This file is a **cheat sheet of "use X instead of Y"** decisions specific to current Expo + RN. Most of them aren't bugs in the legacy API — they're newer alternatives that do more, work better, or avoid a known footgun. Default to the modern column.

## Replacement table

| Purpose | Use | Instead of | Why |
|---------|-----|------------|-----|
| Images | `expo-image` | RN core `<Image>` | Caching, WebP/AVIF, blurhash placeholders, transitions, recycling in lists |
| Lists | `@shopify/flash-list` | `FlatList` | View recycling, much better large-list perf |
| Press | `Pressable` | `TouchableOpacity` / `TouchableHighlight` / `TouchableWithoutFeedback` | Modern API, web parity, flexible state-based styling |
| Audio | `expo-audio` | `expo-av` | `expo-av` is deprecated; split into `expo-audio` and `expo-video` |
| Video | `expo-video` | `expo-av` | Same — `expo-av` deprecated |
| Animation | `react-native-reanimated` (worklets, CSS keyframes) | core RN `Animated` | UI thread vs JS thread; no dropped frames |
| Gestures | `react-native-gesture-handler` (`Gesture.Tap()`, etc.) | `PanResponder` | Native-driven, composable, gesture-aware |
| Platform check | `Platform.OS` (direct import) **or** `process.env.EXPO_OS` | re-exported `Platform.OS` from a shared util | See "Platform check nuance" below — both shake well; the trap is re-exporting `Platform` through a barrel file, which breaks shaking |
| Context (React 19) | `React.use(MyContext)` | `useContext(MyContext)` | Can be called conditionally; integrates with Suspense |
| Safe area on scroll containers | `contentInsetAdjustmentBehavior="automatic"` on `ScrollView`/`FlatList` | wrapping in `<SafeAreaView>` | Native iOS large-title behavior, animated header collapse |
| Sync key/value storage | `react-native-mmkv` | `AsyncStorage` | Synchronous (no await), 10–30x faster, smaller |
| Network state | `react-native-mmkv` cache + `@tanstack/react-query` | hand-rolled `useState` + `useEffect` fetch | Cache, dedup, retries, offline (rule: side-effects #2) |
| Forms | `react-hook-form` + `zod` (or `valibot`) | controlled `useState` per field | Less re-renders, schema validation, type inference |
| E2E tests | Maestro | Detox | Simpler YAML flows, faster, better Expo support |
| Unit / component tests | `@testing-library/react-native` + Jest | Enzyme / shallow rendering | Behavior-first, future-proof |
| iOS SF Symbols | `expo-image` with `source="sf:name"` | `expo-symbols` | Single image API for raster + symbol; `expo-symbols` is being absorbed |
| Tabs | `NativeTabs` (Expo Router) or `@bottom-tabs/react-navigation` | JS-only tabs | True native UITabBar / BottomNavigation, system gestures |

## Footguns

These are bugs you ship if you forget. Train the reflex.

### 1. Falsy render renders `0` as text

```tsx
// ❌ renders the literal "0" when count is 0 (RN doesn't strip falsy text like the DOM does)
{count && <Badge value={count} />}

// ✅
{count > 0 && <Badge value={count} />}

// ✅ alternative
{!!count && <Badge value={count} />}
```

This is the single most common silent bug in RN code. Lint for `\{[a-zA-Z_]+ && <` patterns and audit each.

### 2. Animation properties

GPU-composited (cheap, no layout pass): **`transform`** (translate, scale, rotate) and **`opacity`**.

Everything else (width, height, padding, margin, flex, top/left, backgroundColor) triggers layout or paint and drops frames on lower-end devices.

```tsx
// ❌ animates layout — janky on Android mid-tier
useAnimatedStyle(() => ({ width: withTiming(open ? 200 : 0) }));

// ✅ same effect via transform
useAnimatedStyle(() => ({ transform: [{ scaleX: withTiming(open ? 1 : 0) }] }));
```

Exceptions: `boxShadow`, `backgroundColor`, and `color` are now interpolated on the UI thread under the New Architecture, so they're cheap with Reanimated. Layout properties still aren't.

### 3. Platform check nuance

There are two ways to detect the platform; **both are shaken in production**, with different trade-offs. The previous "use EXPO_OS instead of Platform.OS" advice was wrong — verified against the Expo CLI tree-shaking docs:

```tsx
// option A — direct Platform.OS import (recommended default)
import { Platform } from "react-native";
if (Platform.OS === "ios") { /* iOS-only */ }

// option B — process.env.EXPO_OS
if (process.env.EXPO_OS === "ios") { /* iOS-only */ }
```

What Expo CLI does in production:

- **`Platform.OS`** — platform-shaken when `Platform` is imported **directly** in each file. The other platform's branch is removed and any imports inside it are stripped from that platform's bundle. **Re-exporting `Platform` through a barrel/util file breaks this** — the shaker only handles direct imports.
- **`process.env.EXPO_OS`** — replaced by Metro at build time as a literal string. The unused branch is dead-code-eliminated by minification. **Does not support platform-shaking of imports** (per Expo docs: "this value does not support platform shaking imports due to how Metro minifies code after dependency resolution").

Picking between them:

| Situation | Pick |
|-----------|------|
| Conditional code that imports a platform-only module | `Platform.OS` (direct import) — strips the unused import too |
| Pure value/style branching, no imports inside | Either; `Platform.OS` is more conventional |
| Inside `metro.config.js`, `app.config.ts`, or non-React module where importing `Platform` is awkward | `process.env.EXPO_OS` |
| File that already re-exports `Platform` from a shared util | Stop re-exporting — import directly from `react-native` so shaking works |

Don't memorize "EXPO_OS is faster." It's not faster at runtime — both compile to a string compare. The real win is platform-shaking, which `Platform.OS` does better in the typical conditional-import case.

### 4. `useContext` blowing up the world

A context update re-renders every consumer subtree. For anything beyond theme / current-user, use a state-management library with selectors. See `state.md`.

### 5. AsyncStorage in render-critical paths

`AsyncStorage` is async and slow. If you're reading it in a layout effect to decide what to show, you'll flash. Switch to MMKV (sync), or hydrate at app start before render (see `state.md`).

## Conditional rendering shortlist

The `{cond && <X />}` idiom only works when `cond` is `true | false | null | undefined`. For any number-typed condition, **always** explicit:

```tsx
{items.length > 0 && <List items={items} />}
{!!user && <Greeting user={user} />}
{Boolean(error) && <Error message={error.message} />}
```

ESLint plugin: `@react-native/eslint-plugin` includes a rule for this. Turn it on.

## Permission hooks (Expo)

Modern Expo modules expose `use*Permissions` hooks. Use them.

```tsx
import { useCameraPermissions } from "expo-camera";

const [permission, requestPermission] = useCameraPermissions();

if (!permission) return <Loading />;
if (!permission.granted) {
  return (
    <Pressable onPress={requestPermission}>
      <Text>Grant camera access</Text>
    </Pressable>
  );
}
```

Same shape across `expo-location`, `expo-media-library`, `expo-notifications`, `expo-contacts`, etc. Don't write `getPermissionsAsync()` + `useEffect` patterns — the hook already does that with proper lifecycle handling.

## Native nav polish (Expo Router / native-stack)

Worth setting on screens that warrant them:

- **`headerLargeTitle: true`** — iOS large title that collapses on scroll. Pair with a scroll container that has `contentInsetAdjustmentBehavior="automatic"`.
- **`headerBackButtonDisplayMode: "minimal"`** — chevron-only back button (iOS 14+). Cleaner header on deep stacks.
- **`headerTransparent: true` + blur background** — frosted-glass header.
- **`presentation: "modal"`** / `"formSheet"` — native modal presentation on iOS.
- **`animation: "slide_from_bottom"` / `"fade"`** — per-route nav animations.

Set them on the `Stack.Screen` `options`, not via imperative calls.
