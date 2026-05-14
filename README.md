# uHosts

A tiny, native menu-bar editor for `/etc/hosts` on Apple Silicon Macs.

- **288 KB** app bundle, **~66 MB** RAM at idle
- Native `arm64`, SwiftUI + AppKit, no third-party dependencies, no Electron
- Imports your existing `/etc/hosts` on first launch
- Backs up the original before the first write
- Compatible with [iHosts](https://github.com/toolinbox/iHosts) (standard hosts-file format)

Built because the original iHosts doesn't ship a native Apple Silicon binary.

## Install

Grab the latest `uHosts-X.Y.Z.zip` from [Releases](https://github.com/vLX42/uHosts/releases),
then:

```sh
unzip uHosts-*.zip
mv uHosts.app /Applications/
xattr -d com.apple.quarantine /Applications/uHosts.app
open /Applications/uHosts.app
```

The `xattr` step bypasses Gatekeeper, which blocks the app on first launch
because this build is ad-hoc signed (no paid Apple Developer Program
membership, hence no notarization). You only need to run it once.

The first time you click **Apply**, macOS will prompt for your admin
password — required to write `/etc/hosts`.

**Requires:** macOS 14 (Sonoma) or later, Apple Silicon.

## Build from source

```sh
git clone https://github.com/vLX42/uHosts.git
cd uHosts
./build.sh                # produces build/uHosts.app
./release.sh              # produces dist/uHosts-1.0.0.zip
```

`swift build` handles compilation; `build.sh` wraps the binary in a proper
`.app` bundle and ad-hoc signs it.

## Project layout

```
.
├── Package.swift                  SwiftPM manifest
├── Sources/uHosts/
│   ├── App.swift                  @main, MenuBarExtra scene
│   ├── ContentView.swift          Popover UI
│   └── HostsManager.swift         Parse, render, write /etc/hosts
├── Resources/Info.plist           Bundle metadata (LSUIElement)
├── build.sh                       Compile + bundle .app
├── release.sh                     Build + zip + release notes
├── website/index.html             Homepage (deployed to Vercel)
├── INSTALL.txt                    Shipped inside the release zip
└── .github/workflows/
    ├── build.yml                  CI on every push/PR
    └── release.yml                Build + publish on v* tag push
```

## Hosting

- **Source:** this private repo.
- **Homepage:** hosted on **Vercel**, deployed directly from the `website/`
  subfolder of this private repo. Vercel handles private GitHub repos on
  the free tier, so no public mirror is required. Every push to `main`
  that touches `website/` triggers a redeploy automatically.
- **Releases:** attached to GitHub Releases here in the private repo.
  Direct download URL stays stable:
  `https://github.com/vLX42/uHosts/releases/latest/download/uHosts-X.Y.Z.zip`.

### Vercel project settings

When importing the repo into Vercel:

| Setting | Value |
|---|---|
| Framework Preset | Other |
| Root Directory | `website` |
| Build Command | _(leave empty)_ |
| Output Directory | _(leave empty)_ |
| Install Command | _(leave empty)_ |

The site is a single static `index.html`, so no build step is needed.

## Cutting a release

```sh
git tag v1.0.1
git push origin v1.0.1
```

The `Release` workflow builds the app, zips it, generates notes, and
publishes a GitHub Release with the artifact attached.

## License

MIT — see [LICENSE](LICENSE).
