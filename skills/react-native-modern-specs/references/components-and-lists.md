# Components and lists

## Component shape rules

- **Under 200 lines.** Past that, split: extract logic into a hook, extract sub-UI into a separate component file. Long components hide bugs and re-render needlessly.
- **Module scope only.** Never define a component inside another component — every render of the parent creates a new component identity, breaking memoization, hooks, and reconciliation.
- **One component per file** for screens and significant components. Co-located helper components are fine if small and only used in one place.

```tsx
// ❌ new component identity each render
function Parent() {
  function Child() { return <Text>...</Text>; }
  return <Child />;
}

// ✅
function Child() { return <Text>...</Text>; }
function Parent() { return <Child />; }
```

## Pressable, not Touchable*

`TouchableOpacity` / `TouchableHighlight` / `TouchableWithoutFeedback` are the legacy API. New interactive elements use `Pressable` — it gives you press states, hover/focus on web, and a more flexible style API.

```tsx
<Pressable
  onPress={onPress}
  style={({ pressed }) => [styles.btn, pressed && styles.btnPressed]}
  android_ripple={{ color: colors.ripple }}
  accessibilityRole="button"
  accessibilityLabel="Submit form"
>
  <Text style={styles.btnText}>Submit</Text>
</Pressable>
```

For gesture-driven press feedback (animated scale, haptic on press-in), reach for Gesture Handler's `Gesture.Tap()` — see `react-native-best-practices/references/gestures/`.

## Lists — `FlatList` / `SectionList` / `FlashList`

Never `ScrollView + .map()` for lists of unknown or unbounded length. ScrollViews render every child up front; FlatList virtualizes.

- **`FlashList`** (`@shopify/flash-list`) — drop-in replacement for `FlatList`, dramatically better perf for heterogeneous or long lists. Default pick for production.
- **`FlatList`** — fine for small uniform lists, no extra dep.
- **`SectionList`** — when you need section headers natively.

### Tuning

```tsx
<FlatList
  data={items}
  keyExtractor={item => item.id}
  renderItem={renderItem}
  // virtualization
  removeClippedSubviews
  initialNumToRender={10}
  maxToRenderPerBatch={10}
  windowSize={10}
  // skip measurement when item heights are fixed
  getItemLayout={(_, index) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * index, index })}
  // input handling
  keyboardShouldPersistTaps="handled"
/>
```

Rules:
- **`getItemLayout`** when items have fixed/known heights. Removes the measurement pass — huge scroll jank win.
- **`removeClippedSubviews={true}`** on long lists.
- **Stable `keyExtractor`** — return a real ID, not the index, unless data is truly static.
- **Memoize `renderItem`** and the item component (`React.memo`). Define `renderItem` outside render or with `useCallback`.

### `FlashList` specifics

- Pass an `estimatedItemSize` (a single representative height). FlashList uses it for windowing math.
- `overrideItemLayout` for varying types if you know the dimensions ahead.
- `getItemType` for heterogeneous lists so FlashList can recycle correctly.

## SafeArea — every screen

Content under the notch / status bar / home indicator looks broken. Wrap every screen.

Two approaches, pick per screen:

### `SafeAreaView` — coarse

```tsx
import { SafeAreaView } from "react-native-safe-area-context";

<SafeAreaView style={{ flex: 1 }} edges={["top", "bottom"]}>
  {/* screen */}
</SafeAreaView>
```

Use `edges` to control which insets apply. Default is all four.

### `useSafeAreaInsets` — fine-grained

When you need to apply insets selectively (e.g., apply `top` to the header but let a list extend through `bottom`):

```tsx
import { useSafeAreaInsets } from "react-native-safe-area-context";

const insets = useSafeAreaInsets();
<View style={{ paddingTop: insets.top }}>{/* header */}</View>
<FlatList contentContainerStyle={{ paddingBottom: insets.bottom + 16 }} />
```

Always `react-native-safe-area-context`'s `SafeAreaView`, not the one from `react-native` core (deprecated, iOS-only).

## Performance defaults

- **Reanimated worklets** for any non-trivial animation. Core `Animated` runs on JS thread.
- **Lazy-load heavy screens.** Expo Router lazy routes, or dynamic `import()` in React Navigation.
- **Memoize expensive computations** with `useMemo`, but only after measuring. Premature `useMemo` adds noise.
- **Memoize callbacks passed to memoized children** with `useCallback`. Otherwise every parent render breaks the child's `React.memo`.
- **Avoid `StyleSheet.flatten()` at render time** — it negates `StyleSheet.create()`'s optimization. Pre-compute outside render.

## What goes in `useEffect` here? Almost nothing.

For component-level effects (mount, focus, app-state, gesture lifecycle) — see `side-effects.md` and `navigation.md`. The TL;DR: don't reach for `useEffect` first.
