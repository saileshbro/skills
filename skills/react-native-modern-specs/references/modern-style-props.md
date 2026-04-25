# Modern style props (RN 0.76+, Reanimated 4)

These props replace older shadow/gradient/animation patterns. Use them by default. Fall back only when the project pins an older RN.

## `experimental_backgroundImage` — gradients without a library

CSS-like string. No more `react-native-linear-gradient` for simple cases.

```tsx
<View
  style={{
    width: 200,
    height: 60,
    experimental_backgroundImage:
      "linear-gradient(to right, red 20%, orange 20% 40%, yellow 40% 60%, green 60% 80%, blue 80%)",
  }}
/>
```

Notes:
- Works on iOS and Android with the New Architecture.
- Multi-stop syntax matches CSS: `color start% end%`.
- Still experimental — name will likely lose the prefix in a later RN. Don't depend on the prefix in public API.

## `filter` — visual effects

```tsx
<Image source={...} style={{ filter: "blur(8px) brightness(1.1)" }} />
// or array form
<Image source={...} style={{ filter: [{ blur: 8 }, { brightness: 1.1 }] }} />
```

Coverage:
- **Android** (12+): full set, including `blur`.
- **iOS**: only `brightness` and `opacity`. Don't ship `blur` cross-platform via `filter`; use `expo-blur` / `BlurView` for iOS blur.

Always platform-check before relying on a filter:

```tsx
const blurStyle = Platform.OS === "android" ? { filter: "blur(8px)" } : null;
```

## `boxShadow` — single string instead of 4 props

Replace the legacy `shadowColor` / `shadowOffset` / `shadowOpacity` / `shadowRadius` (iOS) + `elevation` (Android) split.

```tsx
const styles = StyleSheet.create({
  card: {
    borderRadius: 16,
    boxShadow: "0 4px 24px rgba(0,0,0,0.15)",
  },
  layered: {
    boxShadow: [
      "0 1px 2px rgba(0,0,0,0.1)",
      "0 8px 32px rgba(0,0,0,0.08)",
    ].join(", "),
  },
});
```

- Cross-platform; emits the right native shadow on each.
- Multiple layers: comma-separate inside one string.
- Don't mix `boxShadow` with the legacy `shadow*` props on the same element — pick one.

## `gap`, `rowGap`, `columnGap` — flex spacing

Stop margin-stacking children for spacing.

```tsx
const styles = StyleSheet.create({
  row: { flexDirection: "row", gap: 12 },
  grid: { flexDirection: "row", flexWrap: "wrap", rowGap: 6, columnGap: 28 },
});
```

`gap` sets both axes; `rowGap`/`columnGap` override per-axis.

## `mixBlendMode` + `isolation`

```tsx
<View style={{ isolation: "isolate" }}>
  <View style={{ mixBlendMode: "multiply" }} />
  <View style={{ mixBlendMode: "screen" }} />
</View>
```

- `mixBlendMode` blends a child against its backdrop (`multiply`, `screen`, `overlay`, etc.).
- Set `isolation: "isolate"` on the parent to confine the blend so it doesn't bleed up to ancestors.

## CSS animations via Reanimated 4

Reanimated 4 supports declarative CSS animations: define keyframes, name them, set them via `animationName`. No `useSharedValue`, no `useAnimatedStyle` for simple state-driven animations.

### Pattern: glow-on-typing input

```tsx
import { useState } from "react";
import { StyleSheet, TextInput, View } from "react-native";
import Animated, { type CSSAnimationKeyframes } from "react-native-reanimated";

const GLOW_COLOR = "#6C63FF";

const glowIn: CSSAnimationKeyframes = {
  from: { boxShadow: `0 0 0 0 ${GLOW_COLOR}00` },
  to:   { boxShadow: `0 0 32px 4px ${GLOW_COLOR}80` },
};

const glowOut: CSSAnimationKeyframes = {
  from: { boxShadow: `0 0 32px 4px ${GLOW_COLOR}59` },
  to:   { boxShadow: `0 0 0 0 ${GLOW_COLOR}00` },
};

export function GlowInput() {
  const [text, setText] = useState("");
  const hasText = text.length > 0;

  return (
    <View style={styles.container}>
      <Animated.View
        style={[
          styles.glow,
          {
            animationName: hasText ? glowIn : glowOut,
            animationDuration: hasText ? "400ms" : "500ms",
            animationFillMode: "forwards",
            animationTimingFunction: "ease-out",
          },
        ]}
      >
        <TextInput
          autoFocus
          value={text}
          onChangeText={setText}
          placeholder="Type something..."
          placeholderTextColor="#999"
          cursorColor={GLOW_COLOR}
          style={styles.input}
        />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: "center", paddingHorizontal: 24 },
  glow: { borderRadius: 999 },
  input: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "500",
    paddingHorizontal: 20,
    paddingVertical: 16,
    backgroundColor: "#1c1c1e",
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#333",
  },
});
```

### Variations
- **Match the app accent.** Swap `GLOW_COLOR`. Red on validation error, green on success.
- **Subtle glow.** Drop blur radius from `32px` to `12px`, spread from `4px` to `1px`.
- **Trigger on focus instead of typing.** Replace `hasText` with `isFocused` from `onFocus`/`onBlur`.

### When to reach for `useSharedValue` instead
CSS animations are great for:
- State-driven transitions (idle ↔ active)
- Mount/unmount enter/exit
- Anything that maps to "play this keyframe sequence on change"

Reach for shared values + worklets when you need:
- Gesture-driven values (drag offset, pinch scale)
- Scroll-linked animations
- Decay / spring / interpolation against continuous input

For those, see `react-native-best-practices/references/animations/`.

## Animation thread guarantee

Reanimated runs on the UI thread. The core RN `Animated` API runs on the JS thread and drops frames during heavy renders or list scrolls. Default to Reanimated for anything user-visible.
