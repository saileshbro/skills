# Keyboard handling

Never let the keyboard cover a focused input. That's the only rule that matters; everything below is how to keep it true without scattering listeners across components.

## Platform setup

- **iOS**: wrap screens with `KeyboardAvoidingView behavior="padding"` (or `"position"` for specific layouts). `"height"` is almost always wrong.
- **Android**: don't try to push layout from JS. Set `android:windowSoftInputMode="adjustResize"` in `AndroidManifest.xml` and let the OS resize the view. `KeyboardAvoidingView` becomes a no-op (or `behavior={undefined}`) on Android.

```tsx
<KeyboardAvoidingView
  style={{ flex: 1 }}
  behavior={Platform.OS === "ios" ? "padding" : undefined}
>
  {/* form */}
</KeyboardAvoidingView>
```

## Centralize in a hook

Don't sprinkle `Keyboard.addListener` across screens. One hook owns lifecycle, cleanup, and exposes height + open state.

```tsx
import { useEffect, useState } from "react";
import { Keyboard, Platform } from "react-native";

export function useKeyboardAvoiding() {
  const [height, setHeight] = useState(0);
  const [isOpen, setOpen] = useState(false);

  useEffect(() => {
    const showEvt = Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow";
    const hideEvt = Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide";

    const onShow = Keyboard.addListener(showEvt, e => {
      setHeight(e.endCoordinates.height);
      setOpen(true);
    });
    const onHide = Keyboard.addListener(hideEvt, () => {
      setHeight(0);
      setOpen(false);
    });

    return () => {
      onShow.remove();
      onHide.remove();
    };
  }, []);

  return { height, isOpen };
}
```

Rules baked in:

- Platform-correct event names (`Will*` on iOS for matched timing, `Did*` on Android because `Will*` doesn't fire there).
- Always clean up listeners in teardown.
- Read height from `event.endCoordinates.height`. Never hardcode a constant.

## Animation thread

If you animate layout against keyboard height (slide a button up, expand a panel), use Reanimated. The core `Animated` API is on the JS thread and stutters during keyboard transitions on lower-end Android.

```tsx
const { height } = useKeyboardAvoiding();
const animatedStyle = useAnimatedStyle(() => ({
  transform: [{ translateY: -withTiming(height) }],
}));
```

## ScrollViews and lists with inputs

- **Never** nest `KeyboardAvoidingView` inside a `ScrollView`. Use a keyboard-aware scroll component (`react-native-keyboard-aware-scroll-view`, `react-native-keyboard-controller`'s `KeyboardAwareScrollView`) instead.
- Set `keyboardShouldPersistTaps="handled"` on every `ScrollView` / `FlatList` / `SectionList` that contains inputs. Otherwise the first tap dismisses the keyboard instead of hitting the target.

```tsx
<ScrollView keyboardShouldPersistTaps="handled">{/* ... */}</ScrollView>
```

## Multi-field forms — focus chain

Wire `ref` + `onSubmitEditing` to advance focus. Set `returnKeyType="next"` mid-form, `"done"` on the last field. Disables the brain-dead default of dismissing the keyboard between every field.

```tsx
const lastNameRef = useRef<TextInput>(null);
const emailRef = useRef<TextInput>(null);

<TextInput
  returnKeyType="next"
  onSubmitEditing={() => lastNameRef.current?.focus()}
/>
<TextInput
  ref={lastNameRef}
  returnKeyType="next"
  onSubmitEditing={() => emailRef.current?.focus()}
/>
<TextInput
  ref={emailRef}
  returnKeyType="done"
  onSubmitEditing={submit}
/>
```

## Dismiss before navigating

Triggering a navigation while the keyboard is open causes a layout flicker on the destination screen. Dismiss first.

```tsx
const onSubmit = async () => {
  Keyboard.dismiss();
  await save();
  navigation.navigate("Next");
};
```

## When to reach for `react-native-keyboard-controller`

If you need:
- Synchronized keyboard animations (height tracked frame-perfect on the UI thread)
- iOS-style interactive dismiss on Android
- Sticky toolbars above the keyboard

Drop in `react-native-keyboard-controller`. It's the modern replacement for the patchwork of keyboard libraries.
