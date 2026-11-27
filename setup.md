# Local development setup

[README](README.md) · [Architecture](folder-structure.md) · [Backlog](todo.md) · [Security](security.md)

These steps run the Expo starter in [`apps/mobile`](apps/mobile). Web is the fastest target to verify. The starter needs no environment file, database, cloud account, or device credentials.

## Prerequisites

| Tool | Requirement |
| --- | --- |
| Node.js | 24.3 or newer in the 24.x line, per the checked-in React Native version's engine range. |
| pnpm | 11.13.0, pinned in the root [package manifest](package.json). |
| Target | A browser for web. Use a running Android emulator for Android, or macOS with Xcode and an installed iOS simulator. |

## Start the app

Open a terminal in the repository root, in the directory containing [`pnpm-workspace.yaml`](pnpm-workspace.yaml). Install from the root to use the shared lockfile. The root scripts forward to the `@medishield/mobile` workspace.

```sh
node --version
pnpm --version
pnpm install --frozen-lockfile
pnpm web
```

Open the URL printed in the terminal. Verify **Welcome to Expo** on the home screen and select **Explore**. Stop the dev server with Ctrl+C.

| Command | Purpose |
| --- | --- |
| `pnpm start` | Start Metro and choose a development target from the terminal. |
| `pnpm android` | Launch the app on a running Android emulator or configured device. |
| `pnpm ios` | Launch the app on an iOS simulator on macOS. |
| `pnpm --filter @medishield/mobile exec tsc --noEmit` | Run the mobile app's TypeScript check. See the current result below. |
| `pnpm lint` | Run Expo's lint entry point. First use may install ESLint dependencies and create configuration, which should be reviewed before committing. |

To verify web bundling, run `pnpm --filter @medishield/mobile exec expo export --platform web`. Expo Router uses server output mode and writes the export to `apps/mobile/dist` by default. Use the dev server for the tab navigation smoke test.

The starter includes [`reset-project`](apps/mobile/scripts/reset-project.js), which replaces the sample routes and can move or delete starter files inside `apps/mobile`. Normal development starts with the existing routes.

## Verification baseline

The workspace migration was checked with Node.js 24.18.0 and pnpm 11.13.0.

| Check | Observed result |
| --- | --- |
| Frozen install | Both workspace packages resolved from the shared lockfile using the local pnpm cache. |
| Web start | The root `pnpm web` command served `/` and `/explore` with HTTP 200. |
| Web export | The client and server bundles built from `apps/mobile`. |
| Native configuration | Expo loaded the Android and iOS prebuild config. Device and emulator runs are pending. |
| TypeScript | TS2322 remains in [`app-tabs.web.tsx`](apps/mobile/src/components/app-tabs.web.tsx#L38) because of incompatible ref types. |

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| pnpm or Node is missing | Open a shell with your Node version manager loaded. Run both version commands from that shell. |
| Frozen install fails | Compare the installed pnpm version with the prerequisite, then inspect the lockfile and manifest. Update the lockfile deliberately when changing dependencies. |
| Metro serves stale output | Stop the server and rerun `pnpm --filter @medishield/mobile exec expo start --web --clear`. |
| Emulator fails to open | Start the emulator or simulator first. Confirm Android exposes the target with `adb devices` or iOS lists it with `xcrun simctl list devices booted`. |

## Planned integration setup

The service and infrastructure directories contain placeholders. As implementations land, follow the [architecture guide](folder-structure.md#production-target). Provision an isolated prototype database, apply versioned migrations, seed fictional patients and encounters, start the API and required workers, then connect the clients and telemetry simulator. Document required environment-variable names with an empty-value template and store credentials server-side.

Verify registration, duplicate-scan blocking, alert acknowledgment, and expired referral handling with the [prototype acceptance criteria](todo.md#prototype-synthetic-workflows). Record the versions and commands used in the corresponding change.
