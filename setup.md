# Local development setup

[README](README.md) · [Architecture](folder-structure.md) · [Backlog](todo.md) · [Security](security.md)

These steps run the public homepage on web and in the native Home tab in [`apps/mobile`](apps/mobile). The homepage needs no environment file, database, cloud account, or device credentials.

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

Open the URL printed in the terminal. Verify that the MediShield AI homepage displays the synthetic ward dashboard. Try the theme selector and FAQ. Open Log In and Register Hospital from the homepage, then follow Forgot password? from the sign-in page. Use sample values to check validation and the prototype submission messages. Use `/explore` to check the starter Explore route. Stop the dev server with Ctrl+C.

On Android or iOS, open the **Home** tab to see the same project content in a native layout. The native homepage follows your device theme. If an existing development session still shows the Expo welcome screen, reload the app after restarting Metro with `pnpm start --clear`.

| Command | Purpose |
| --- | --- |
| `pnpm start` | Start Metro and choose a development target from the terminal. |
| `pnpm android` | Launch the app on a running Android emulator or configured device. |
| `pnpm ios` | Launch the app on an iOS simulator on macOS. |
| `pnpm --filter @medishield/mobile exec tsc --noEmit` | Run the mobile app's TypeScript check. See the current result below. |
| `pnpm lint` | Run Expo's lint entry point. First use may install ESLint dependencies and create configuration, which should be reviewed before committing. |

To verify web bundling, run `pnpm --filter @medishield/mobile exec expo export --platform web`. Expo Router uses server output mode and writes the export to `apps/mobile/dist` by default. Use the dev server for the tab navigation smoke test.

The starter includes [`reset-project`](apps/mobile/scripts/reset-project.js), which replaces the sample routes and can move or delete starter files inside `apps/mobile`. Normal development starts with the existing routes.

## NativeWind and Tailwind

The Expo workspace pins NativeWind 4.2.7 and Tailwind CSS 3.4.17. Metro reads the Tailwind directives from [`src/global.css`](apps/mobile/src/global.css). Style homepage components with utility classes. Shared theme and layout classes live in [`styles.ts`](apps/mobile/src/features/home/styles.ts), and [`tailwind.config.js`](apps/mobile/tailwind.config.js) defines the semantic color utilities and web fonts.

The [NativeWind compatibility patch](patches/react-native-css-interop@0.2.7.patch) removes the automatic registration of React Native's deprecated `ImageBackground`. Run `node --test apps/mobile/tests/nativewind-interop.test.cjs` from the root to verify the remaining image and view registrations. Restart Expo with `pnpm web --clear` after changing Tailwind, Babel, or Metro configuration.

## Verification baseline

The workspace migration was checked with Node.js 24.18.0 and pnpm 11.13.0.

| Check | Observed result |
| --- | --- |
| Frozen install | Both workspace packages resolved from the shared lockfile using the local pnpm cache. |
| Web start | The root `pnpm web` command served `/` and `/explore` with HTTP 200. |
| Web export | The client and server bundles built from `apps/mobile`. |
| Native configuration | Expo loaded the Android and iOS prebuild config. Device and emulator runs are pending. |
| TypeScript | The homepage update resolved the web tab ref mismatch. The TypeScript check passes. |

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
