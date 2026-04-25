# Accessibility

Apps that fail TalkBack / VoiceOver get rejected by enterprise procurement and embarrass everyone. Each rule below is cheap; skipping them is what makes the cleanup expensive later.

## Label every interactive element without visible text

Icon buttons, image buttons, swipe handles, anything where the screen reader has nothing to read.

```tsx
<Pressable
  onPress={onClose}
  accessibilityLabel="Close"
  accessibilityRole="button"
>
  <Icon name="x" />
</Pressable>
```

If the visible text already describes the action (e.g. a `<Text>Submit</Text>` button), you can skip the label — the visible text becomes the accessible name.

## Set `accessibilityRole`

Every interactive element gets a role: `"button"`, `"link"`, `"checkbox"`, `"radio"`, `"switch"`, `"search"`, `"image"`, `"header"`, `"adjustable"`. Picks the right gesture and announcement for the screen reader.

```tsx
<Pressable accessibilityRole="link" onPress={openWeb}>
  <Text>Read more</Text>
</Pressable>
```

## `accessibilityState` for toggleable elements

```tsx
<Pressable
  accessibilityRole="checkbox"
  accessibilityState={{ checked: isChecked, disabled: !canEdit }}
  onPress={toggle}
>
  ...
</Pressable>
```

Common keys: `checked`, `disabled`, `selected`, `expanded`, `busy`. Set them whenever the visual state changes.

## `accessibilityHint` — sparingly

A hint describes the **result** of activating an element. Use only when the result is non-obvious from the label.

```tsx
// Label says what; hint says what happens after.
<Pressable
  accessibilityLabel="Like"
  accessibilityHint="Adds this post to your favorites"
  accessibilityRole="button"
/>
```

If the label already implies the result ("Submit form"), skip the hint. Hints add reader latency; don't pile them onto every button.

## Group related elements

For a row that visually reads as one unit (avatar + name + timestamp), let the screen reader treat it as one:

```tsx
<View
  accessible
  accessibilityLabel={`${name}, posted ${timeAgo}`}
  accessibilityRole="button"
  onPress={openProfile}
>
  <Avatar uri={avatarUrl} />
  <Text>{name}</Text>
  <Text>{timeAgo}</Text>
</View>
```

Without grouping, the screen reader walks each child individually — slow, confusing, repetitive.

## Dynamic Type / large text

iOS users can scale text up to 310%. Android has font scale settings too.

- **Never set fixed heights on text containers.** Use `paddingVertical` / `flex` / intrinsic sizing.
- **Use relative font sizes** through a typography scale, and let users' OS settings scale them.
- **Test at 200% scale.** Most layout breakage happens above 150%.
- **Disable scaling only with very strong reason** — `allowFontScaling={false}` is almost always wrong. Numerals in tables / charts are sometimes the exception.

```tsx
// ❌ clips at large text sizes
<View style={{ height: 40, justifyContent: "center" }}>
  <Text>{label}</Text>
</View>

// ✅
<View style={{ paddingVertical: 8, justifyContent: "center" }}>
  <Text>{label}</Text>
</View>
```

## Touch targets

Minimum 44×44pt (iOS HIG) / 48×48dp (Material). Use `hitSlop` if the visual element is smaller:

```tsx
<Pressable hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}>
  <Icon name="x" size={20} />
</Pressable>
```

## Color contrast

Body text: WCAG AA = 4.5:1. Large text (18pt+ regular, 14pt+ bold): 3:1. Don't ship gray-on-gray placeholder text.

## Reduced motion

Some users disable animations system-wide. Honor it:

```tsx
import { AccessibilityInfo } from "react-native";

const [reduceMotion, setReduceMotion] = useState(false);
useEffect(() => {
  AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
  const sub = AccessibilityInfo.addEventListener("reduceMotionChanged", setReduceMotion);
  return () => sub.remove();
}, []);

<Animated.View style={reduceMotion ? null : { animationName: glowIn }} />
```

(This is a legitimate `useEffect` — imperative subscription with no library hook. Comment why if challenged.)

## Test it

- **iOS**: VoiceOver (Settings → Accessibility → VoiceOver), Dynamic Type slider.
- **Android**: TalkBack, Font size in display settings.
- **Automated**: `eslint-plugin-react-native-a11y` for the obvious misses.
