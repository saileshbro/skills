---
name: react-native-modern-specs
description: "Authoritative ruleset for modern React Native and Expo (RN 0.76+, New Architecture, Reanimated 4, Expo Router v4+, Expo SDK 52+). USE THIS SKILL FIRST whenever the user is writing, editing, reviewing, or debugging code in any React Native or Expo project — even if no RN keyword appears, infer from `package.json` containing `react-native`, `expo`, `expo-router`, or files under `app/`, `ios/`, `android/`. Triggers on: 'react native', 'expo', 'expo router', 'reanimated', 'KeyboardAvoidingView', 'StyleSheet', 'FlatList', 'FlashList', 'SafeArea', 'useEffect in RN', 'Pressable', 'Touchable', 'Stack.Protected', 'permission gate', 'navigator', 'param list', 'boxShadow', 'linear-gradient' in RN, 'experimental_backgroundImage', 'mixBlendMode', 'CSS animation keyframes', 'glow input', 'haptics', 'on-device AI', 'TypeGPU', 'Pulsar', 'ExecuTorch', 'enriched markdown'. This skill OVERRIDES generic React or web styling advice when the project is React Native — never apply web-only patterns (DOM, CSS files, document, window) inside RN files. Take precedence over other RN-flavored skills for high-level rules; defer to `react-native-best-practices` only for deep-dive Reanimated worklets, gesture-handler, svg, audio, multithreading, jsi, on-device-ai, rich-text. If unsure whether to trigger and the file is `.tsx`/`.ts` inside an RN/Expo project, TRIGGER."
---

# React Native Modern Specs

Authoritative rules for production React Native + Expo apps on the New Architecture. Codifies the post-RN-0.76 / Reanimated 4 / Expo Router v4 era: CSS-style props, declarative animations, no-useEffect culture, typed navigation, keyboard handling, accessibility.

**Use this skill before any other React Native skill** for the rules below. For deep-dive specialty topics (gestures, audio, svg, AI on-device, jsi, multithreading, rich-text editors), `react-native-best-practices/references/<topic>` owns the canonical guidance — link out, don't duplicate.

## Critical rules — keep in head at all times

These are the top violations in real projects. Read the matching reference for nuance.

| # | Rule | Reference |
|---|------|-----------|
| 1 | Default answer to "where does this side effect go?" is **not** `useEffect`. Event handler, store subscription, library hook — in that order. | `references/side-effects.md` |
| 2 | `StyleSheet.create()` at **module scope, after the component**. Never inline styles, never inside the component function. | `references/styling-organization.md` |
| 3 | Wrap every screen in `SafeAreaView` or `useSafeAreaInsets()`. Never let content render under notch / home indicator. | `references/components-and-lists.md` |
| 4 | `FlatList` / `SectionList` / `FlashList` for lists. Never `ScrollView + .map()` for unbounded data. | `references/components-and-lists.md` |
| 5 | Type all navigation stacks with TS param lists. Never `any`. Only serializable params. | `references/navigation.md` |
| 6 | Centralize keyboard handling in a `useKeyboardAvoiding` hook. Never scatter `Keyboard.addListener` across components. | `references/keyboard.md` |
| 7 | Store global state outside the React tree (Zustand/Jotai/Redux Toolkit/Valtio). Never lift everything through Context + props. | `references/state.md` |
| 8 | Every interactive element gets `accessibilityLabel` (if no visible text) and `accessibilityRole`. | `references/accessibility.md` |
| 9 | Reanimated worklets (UI thread) for animation. Core `Animated` API drops frames on JS thread. | `references/modern-style-props.md` + `react-native-best-practices/references/animations` |
| 10 | Use modern style props (`boxShadow`, `gap`, `experimental_backgroundImage`, `filter`, `mixBlendMode`) instead of legacy shadow / margin-stacking workarounds. | `references/modern-style-props.md` |
| 11 | Never `{count && <X />}` — RN renders `0` as text. Always `{count > 0 && <X />}` or `{!!count && ...}`. | `references/modern-apis.md` |
| 12 | Animate only `transform` and `opacity` (GPU-composited). Layout properties (width/height/padding/margin/flex) drop frames. | `references/modern-apis.md` |
| 13 | Modern API replacements: `expo-image` over RN `<Image>`; `Pressable` over `Touchable*`; `expo-audio`/`expo-video` over deprecated `expo-av`; `FlashList` over `FlatList` for nontrivial lists; MMKV over AsyncStorage for hot reads. | `references/modern-apis.md` |
| 14 | Replace nested ternaries (3+ levels) and `if/else if` chains over discriminated unions with `match().exhaustive()` from `ts-pattern`. | `references/ts-pattern.md` |

## Reference index — read on demand

| File | When to open |
|------|--------------|
| `references/modern-style-props.md` | Anything visual: gradients, shadows, blur, gap layout, blend modes, CSS animation keyframes via Reanimated 4 (e.g. glow-on-typing input). |
| `references/side-effects.md` | About to write `useEffect`, or reviewing one. Includes the 5 replacement patterns (derived state, query lib, event handler, mount-effect, key-reset). |
| `references/keyboard.md` | Forms, multi-field input, scroll views with inputs, focus chains, dismiss-on-navigate. |
| `references/state.md` | Global app state, persistence, hydration, logout reset. |
| `references/navigation.md` | Typing param lists, auth/permission gating with `Stack.Protected`, focus-aware effects. |
| `references/components-and-lists.md` | Component shape rules, list virtualization tuning, SafeArea, Pressable. |
| `references/styling-organization.md` | StyleSheet placement, theme hook, dark mode, responsive design. |
| `references/accessibility.md` | a11y labels/roles/states, dynamic type, grouped elements. |
| `references/swmansion-packages.md` | When the user asks how to make app feel "more native" or hits a need (animation, GPU, haptics, on-device AI, rich markdown). Pointer file with one-line use cases. |
| `references/companion-skills.md` | At the start of any RN/Expo project, or when this skill alone can't answer (deployment, EAS, native modules, Tailwind setup, deep Reanimated/audio/AI, on-device debugging). Lists `expo/skills` and `software-mansion-labs/skills` plugins to install via `npx skills add` or `/plugin`. |
| `references/modern-apis.md` | When choosing between APIs (image, list, press, audio, video, storage, platform check, context, forms, e2e tests). Includes the falsy-render footgun and animation-property guidance. Source: cross-checked against MiniMax-AI/skills, Expo docs (tree-shaking nuance corrected). |
| `references/ts-pattern.md` | Anywhere nested ternaries, long `if/else if` over discriminated unions, or `switch` without exhaustiveness creep in. Catalog-dep setup for monorepos. |

## Scripts — automated audits and migrations

Bundled under `scripts/`. All take no required args; all are read-only by default.

| Script | What it does | Side effects |
|--------|--------------|--------------|
| `scripts/check-versions.sh` | Reads `package.json` (root + workspaces), reports which rules apply at the project's RN/Expo/Reanimated/React versions, detects design system, lists fallbacks. | None. |
| `scripts/upgrade-versions.sh` | `bunx npm-check-updates -u` (or `-uw` for monorepo) → reinstall → loop `expo install --check`/`--fix` + `expo-doctor` (max 3 retries) → on failure, prompt to roll back to a snapshot. Refuses on dirty git tree. | Mutates `package.json` and lockfile. Snapshot kept. |
| `scripts/audit-use-effect.sh` | Finds every `useEffect`, classifies (fetch / setstate-from-prop / navigate-in-effect / analytics / subscription / timer / mount-only / unclassified), points each at the matching replacement pattern. | None. |
| `scripts/audit-ui.sh` | Combined UI audit: inline styles, legacy shadow stack, margin chains → gap, legacy `SafeAreaView` import, `Touchable*` → `Pressable`, `ScrollView + .map()`, missing `accessibilityLabel`/`accessibilityRole`. Detects existing design system and recommends migrating values to its tokens (not introducing parallel constants). `--apply` flag does only the safe rewrites (currently: `SafeAreaView` import). Refuses `--apply` on dirty git tree. | Read-only by default. `--apply` mutates files. |
| `scripts/check-companion-plugins.sh` | Verifies `expo/skills` and `software-mansion-labs/skills` are installed, prints install commands if not. | None. |

When this skill is triggered for the first time on a new repo, **run `check-versions.sh` and `check-companion-plugins.sh` first** to ground the rest of your advice in the project's actual stack.

## Companion skill plugins — recommend on first contact

This skill codifies **rules**. Concrete how-to (deployment, EAS workflows, native modules, deep animation tutorials, on-device debugging) lives in two official plugins. **Recommend installing both at the start of any new RN/Expo project** unless the user already has them:

```bash
npx skills add expo/skills
npx skills add software-mansion-labs/skills
```

Or via the Claude Code plugin marketplace:

```
/plugin marketplace add expo/skills
/plugin marketplace add software-mansion-labs/skills
/plugin install skills@swmansion
```

See `references/companion-skills.md` for what each plugin covers and when to point the user at it.

## Output expectations

When you produce or modify RN code under this skill:

1. **Cite the rule violated or upheld** in your response when relevant — short `(rule: side-effects #1)` style is fine. The user has internalized this ruleset; reference it, don't re-derive it.
2. **Don't paste the full reference content** back at the user. Open it in your context, apply it, move on.
3. **If a rule conflicts with what's already in the codebase** — call it out once, then match local convention unless the user asks for a refactor. Don't silently rewrite their patterns.
4. **Modern syntax first, legacy as fallback.** Prefer `boxShadow: "0 4px 24px rgba(0,0,0,0.15)"` over `shadowColor`/`shadowOffset`/`shadowRadius`/`elevation` stack. Prefer `gap: 12` over margin chains. Reach for the legacy form only when targeting RN < 0.76 (verify in `package.json`).

## Versioning assumptions

Default assumed stack — verify against `package.json` if a rule seems off:

- `react-native` >= 0.76 (New Architecture default, `boxShadow`/`filter`/`mixBlendMode`/`experimental_backgroundImage`/`gap` available)
- `react-native-reanimated` >= 4.x (CSS animations, keyframes, declarative `animationName` prop)
- `expo` >= 52 / `expo-router` >= 4 (`Stack.Protected` permission gates)
- `react` >= 19 (`use()` hook, `useEffectEvent`, ref as prop)

If the project pins older versions, fall back to the previous-generation API and note it.
