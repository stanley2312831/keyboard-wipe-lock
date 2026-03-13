# KeyboardWipeLock (macOS)

A tiny macOS utility for keyboard cleaning mode:

- Enter **Wipe Mode** to black out screen with top-level overlay windows.
- Keep keyboard/mouse input inside this app while active.
- Only unlock with your configured password.

## Notes

- This is a user-space app. It does **not physically power off** your monitor.
- It provides a black full-screen overlay and active-app input capture behavior.

## Local build

```bash
chmod +x build_app.sh make_dmg.sh
./build_app.sh
./make_dmg.sh 1.0.0
```

Outputs:

- `build/KeyboardWipeLock.app`
- `build/KeyboardWipeLock-1.0.0.dmg`

## GitHub Actions

Workflow: `.github/workflows/build-dmg.yml`

- Trigger manually (`workflow_dispatch`) or by tag push (`v*`).
- Uploads DMG as an artifact.
- On tag push, also creates a GitHub Release and attaches DMG.

## Usage

1. Launch app
2. Set password and click **Save Password**
3. Click **Enter Wipe Mode**
4. Clean keyboard
5. Enter password in unlock panel
