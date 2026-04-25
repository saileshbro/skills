# Styling organization

The rules here are about **where styles live**, not what they look like. For modern style props (gradients, shadows, blends, gap, CSS animations), see `modern-style-props.md`.

## `StyleSheet.create()` at module scope

Always at module scope, **after** the component definition. Never inline objects, never inside the component function.

```tsx
export function Card({ title }: { title: string }) {
  return (
    <View style={styles.card}>
      <Text style={styles.title}>{title}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { padding: 16, borderRadius: 12, backgroundColor: "#fff" },
  title: { fontSize: 16, fontWeight: "600" },
});
```

Why:
- `StyleSheet.create()` registers styles once and passes integer IDs across the bridge / JSI. Inline `{}` re-allocates per render and re-serializes.
- Style identity affects `React.memo` and list item recycling. Inline styles bust both.

## No inline objects, even tiny ones

```tsx
// ❌ new object each render → memo busts
<View style={{ flex: 1 }} />

// ✅
<View style={styles.fill} />
```

Exception: a single dynamic value computed from props/state (e.g., `style={[styles.bar, { width: progress * 100 }]}`). Keep the dynamic part minimal and composed with a static stylesheet entry.

## No single-element style arrays

```tsx
// ❌ allocates an array per render for nothing
<View style={[styles.container]} />

// ✅
<View style={styles.container} />
```

Use the array form only when actually composing.

## Dynamic styles: factory or styling library

Styles that depend on props, theme, or screen size — never compute as inline objects on every render.

### Factory pattern

```tsx
const makeStyles = (theme: Theme) =>
  StyleSheet.create({
    card: {
      backgroundColor: theme.surface,
      borderColor: theme.border,
    },
  });

function Card() {
  const theme = useTheme();
  const styles = useMemo(() => makeStyles(theme), [theme]);
  return <View style={styles.card} />;
}
```

### Styling libraries

- **NativeWind** — Tailwind classes, compiles to `StyleSheet.create()` entries.
- **Restyle** (Shopify) — typed theme-aware components.
- **Tamagui** — theme + animation + perf-tuned components.
- **Unistyles** — theme-aware StyleSheet with breakpoints.

Pick one per project. Don't stack them.

## Centralize tokens

- **Colors**: one `colors.ts` (or theme object). Never hardcode `#1c1c1e` in components.
- **Spacing**: a `spacing.ts` (`{ xs: 4, sm: 8, md: 16, lg: 24, xl: 40 }`). Never magic-number `padding: 17`.
- **Radii**: same — `{ sm: 4, md: 12, full: 999 }`.
- **Typography**: a font scale (`{ body: { fontSize: 16, lineHeight: 24 }, ... }`).
- **Breakpoints**: a `breakpoints.ts` for responsive design.

Put these under `src/theme/` (or wherever your project keeps shared modules).

## Property order inside a stylesheet entry

Group by category for readability:

```tsx
{
  // 1. layout / flex
  flex: 1,
  flexDirection: "row",
  alignItems: "center",
  gap: 12,

  // 2. box model
  width: 200,
  padding: 16,
  margin: 8,

  // 3. visual
  backgroundColor: theme.surface,
  borderRadius: 12,
  boxShadow: "0 4px 24px rgba(0,0,0,0.15)",

  // 4. typography
  fontSize: 16,
  fontWeight: "600",
  color: theme.text,

  // 5. transform
  transform: [{ scale: 0.98 }],
}
```

Not enforced by tooling, but consistent ordering makes diffs and reviews easier.

## Dark mode through a theme hook

Don't swap colors with inline ternaries.

❌ Bad:
```tsx
const isDark = useColorScheme() === "dark";
<View style={{ backgroundColor: isDark ? "#000" : "#fff" }} />
```

✅ Good:
```tsx
const theme = useTheme();
<View style={{ backgroundColor: theme.background }} />
```

The theme hook reads color scheme **and** any user override (some apps let users force light/dark independent of the system).

## Responsive design — breakpoints, not device detection

Don't branch on `Platform.isPad` or `Device.modelName`. Use width breakpoints from `Dimensions` or a hook (`useWindowDimensions`).

```tsx
const { width } = useWindowDimensions();
const isWide = width >= breakpoints.tablet;
```

Branch on the width, not the device class. Rotation, split-screen, foldables — all break device-class detection.

## Don't `StyleSheet.flatten()` at render

`StyleSheet.flatten()` resolves an array/ID style into a plain object — useful for measurement, but it allocates and bypasses the optimization. Don't call it in `style={...}` or in a render path.

## Animations via Reanimated, not Animated

Inline animated style objects on the JS thread are the slowest possible animation. Use Reanimated's `useAnimatedStyle` (worklet, UI thread) or CSS animations (`animationName` keyframes). See `modern-style-props.md`.
