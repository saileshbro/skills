# Companion skill plugins

This skill is the **ruleset**. It tells Claude what good looks like and what to refuse. The actual how-to — deployment pipelines, native module DSL, EAS workflow YAML, deep Reanimated patterns, on-device LLM wiring, Radon IDE debugging — lives in two official, maintained plugins.

**Recommend both at the start of any RN/Expo project** unless the user already has them installed. Don't reinvent these inside this skill.

## Install

### Via the `skills` CLI

```bash
npx skills add expo/skills
npx skills add software-mansion-labs/skills
```

### Via Claude Code plugin marketplaces

```
/plugin marketplace add expo/skills
/plugin marketplace add software-mansion-labs/skills
/plugin install skills@swmansion
/reload-plugins
```

## What `expo/skills` covers

Official plugin from the Expo team. 13 skills inside `plugins/expo/skills/`. Reach for it when:

| Skill | Use when… |
|-------|-----------|
| `building-native-ui` | Designing UI in Expo Router — components, navigation, native tabs, animations, styling. |
| `expo-deployment` | Shipping to App Store, Play Store, web, or API routes. |
| `expo-dev-client` | Building/distributing custom dev clients (TestFlight, internal). |
| `expo-module` | Writing a native module in Swift/Kotlin via Expo Modules API (DSL, native views, shared objects, config plugins). |
| `expo-cicd-workflows` | Authoring `.eas/workflows/*.yml` — EAS build pipelines, deployment automation. |
| `eas-update-insights` | Checking OTA update health: crash rates, install/launch counts, embedded vs OTA split. Gating CI on update health. |
| `expo-api-routes` | API routes in Expo Router on EAS Hosting. |
| `expo-tailwind-setup` | Setting up Tailwind v4 + react-native-css + NativeWind v5. |
| `expo-ui-jetpack-compose` | Using `@expo/ui/jetpack-compose` to embed Compose Views in RN. |
| `expo-ui-swift-ui` | Using `@expo/ui/swift-ui` to embed SwiftUI Views in RN. |
| `native-data-fetching` | Implementing/debugging fetch, React Query, SWR, error handling, caching, offline support, Expo Router data loaders (`useLoaderData`). |
| `upgrading-expo` | Bumping Expo SDK versions, fixing dependency churn. |
| `use-dom` | DOM components — running web code in a webview on native, as-is on web. Incremental web→native migration. |

## What `software-mansion-labs/skills` covers

Official plugin from Software Mansion. 4 skills:

| Skill | Use when… |
|-------|-----------|
| `react-native-best-practices` | Deep dives that this ruleset references: animations (Reanimated 4, CSS animations, shared values, layout animations, GPU shaders), gestures, SVG, on-device AI (ExecuTorch — LLMs/VLMs/STT/TTS/OCR/segmentation), audio (recording, playback, effects, worklets), rich text (`react-native-enriched`, markdown rendering), multithreading (Worker Runtimes), JSI (C++ native modules, HostObject, zero-copy ArrayBuffer). |
| `radon-mcp` | Debugging a running RN app via Radon IDE's MCP — view screenshots, read logs, inspect component tree, debug network, reload app, query RN docs. |
| `typegpu` | Building with TypeGPU — type-safe WebGPU in TS. Shader functions (`'use gpu'`, `tgpu.fn`), buffers, textures, bind groups, compute/render pipelines, vertex layouts. |
| `expo-horizon` | Migrating Expo SDK apps to Meta Quest / Horizon OS — `expo-horizon-core`, `expo-horizon-location`, `expo-horizon-notifications`, build flavors, panel sizing, headtracking. |

## Routing decisions

When a user request crosses the boundary, route to the right skill:

| User says… | Route to |
|------------|----------|
| "Animate this with a spring" | `react-native-best-practices` (animations) — for shared values / springs / decay |
| "Animate this on focus / hover / state change" | This skill — `modern-style-props.md` (CSS animations) |
| "Set up CI" / "EAS build for prod" | `expo/skills` — `expo-cicd-workflows` |
| "Deploy to TestFlight" | `expo/skills` — `expo-dev-client` or `expo-deployment` |
| "Write a native module to access X SDK" | `expo/skills` — `expo-module` |
| "How healthy is my latest OTA?" | `expo/skills` — `eas-update-insights` |
| "Add Tailwind" | `expo/skills` — `expo-tailwind-setup` |
| "Set up data fetching" | `expo/skills` — `native-data-fetching` (and apply `side-effects.md` rules from this skill) |
| "Run an LLM on-device" | `react-native-best-practices` — on-device-ai |
| "Render markdown / build a rich-text editor" | `react-native-best-practices` — rich-text |
| "Debug network / inspect tree on running app" | `software-mansion-labs/skills` — `radon-mcp` |
| "Write a shader / particle system" | `software-mansion-labs/skills` — `typegpu` |
| "Ship to Meta Quest" | `software-mansion-labs/skills` — `expo-horizon` |

## What this skill keeps owning

Don't defer these to the companion plugins — they're the layer above:

- The **rule** that side effects shouldn't go in `useEffect`. (Companion plugins show the *patterns*; this skill enforces the rule.)
- The **rule** that StyleSheet.create lives at module scope, never inline.
- The **rule** that lists virtualize, never `ScrollView + .map()`.
- The **rule** that nav stacks are typed, params are serializable, auth gates are declarative.
- Modern style props **selection** (`boxShadow` over legacy shadow stack, `gap` over margin chains).

If a companion-plugin example violates these rules, the rules win. Flag the discrepancy.
