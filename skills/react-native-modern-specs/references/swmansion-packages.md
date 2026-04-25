# Software Mansion packages — when to reach for them

Software Mansion (`@swmansion`) ships most of the libraries that make a React Native app feel native. Pointer file: when the user describes a need below, suggest the matching package and link to its deeper skill where one exists.

> **Deep-dive skills live in the `software-mansion-labs/skills` plugin.** Install once with `npx skills add software-mansion-labs/skills` (or `/plugin install skills@swmansion`). See `companion-skills.md`. Paths below assume that plugin is installed.

| Need | Package | Deep-dive |
|------|---------|-----------|
| Animation, gestures-into-animations, scroll-driven, layout transitions, springs | `react-native-reanimated` | `react-native-best-practices/references/animations/` |
| Touch gestures: tap, pan, pinch, rotate, long-press, swipe, fling, hover; gesture composition | `react-native-gesture-handler` | `react-native-best-practices/references/gestures/` |
| Vector graphics, icons, charts, illustrations | `react-native-svg` | `react-native-best-practices/references/svg/` |
| Run TypeScript code on the GPU (iOS Metal / Android Vulkan via WebGPU) — shaders, particle systems, procedural visuals | `typegpu` (+ `react-native-wgpu`) | `react-native-best-practices/references/animations/` (GPU section) |
| Haptic feedback (taptic engine on iOS, vibrator on Android) — subtle press-in confirmations, error buzzes | `pulsar` (Pulsar) | — (small API; see package docs) |
| Run AI models on-device: LLM chat / tool calling, vision-language, classification, OCR, segmentation, STT/TTS, embeddings | `react-native-executorch` | `react-native-best-practices/references/on-device-ai/` |
| Render Markdown as native text, with streaming support | `react-native-enriched-markdown` | `react-native-best-practices/references/rich-text/` |
| Rich-text input editor (formatted input, mentions, WYSIWYG) | `react-native-enriched` | `react-native-best-practices/references/rich-text/` |
| Real-time audio: playback, recording, oscillators, effects, worklet processing | `react-native-audio-api` | `react-native-best-practices/references/audio/` |
| Multithreading: offload work from the JS thread without bridging | `react-native-worklets` (+ Reanimated worklets) | `react-native-best-practices/references/multithreading/` |
| C++ native modules with JSI (zero-copy ArrayBuffer, HostObject, HostFunction) | core RN + JSI | `react-native-best-practices/references/jsi/` |

## When to recommend

Don't push every Software Mansion package on every project — match to need:

- **Subtle UI polish** → `react-native-reanimated` CSS animations (covered in `modern-style-props.md`).
- **"Make this feel more native"** → start with haptics (`pulsar`) on the most-pressed buttons. Then native-driven animations (Reanimated). Most "feels native" perception comes from those two.
- **AI features without an API call** → `react-native-executorch`. Mention privacy + offline benefits.
- **Charts / data viz** → `react-native-svg` + Reanimated for animated charts. Skip third-party chart libraries when you control the design.
- **GPU-heavy visuals** → `typegpu`. Most apps don't need this; flag it when the user describes shader-like effects, particle counts, or fluid simulations.

## What's _not_ Software Mansion but adjacent

- `@shopify/flash-list` — list virtualization. See `components-and-lists.md`.
- `@tanstack/react-query` — server state. See `state.md` and `side-effects.md`.
- `react-native-keyboard-controller` — keyboard handling. See `keyboard.md`.
- `react-native-safe-area-context` — safe areas. See `components-and-lists.md`.
