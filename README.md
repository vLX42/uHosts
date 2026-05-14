# uHosts

A tiny, native menu-bar editor for `/etc/hosts` on Apple Silicon Macs.

- **392 KB** app bundle, **~37 MB** RAM at idle
- Native `arm64`, AppKit menu bar with a SwiftUI editor window
- Launch at login (optional, via macOS Login Items / `SMAppService`)
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

The first time you click **Apply Changes** (⌘S), macOS will prompt for your
admin password — required to write `/etc/hosts`.

**Requires:** macOS 14 (Sonoma) or later, Apple Silicon.

## Using it

Click the network icon in the menu bar:

- Each entry shows as a menu item with a ✓ when enabled. Click to toggle.
- **Apply Changes (⌘S)** — write the current state to `/etc/hosts`.
- **Reload from /etc/hosts (⌘R)** — re-import after a manual edit.
- **Edit Hosts… (⌘,)** — open the editor window to rename, change IP, etc.
- **Add Entry… (⌘N)** — opens the editor with a new blank row.
- **Launch at Login** — register the app as a Login Item.

NSMenu closes after each click, so to flip several entries you reopen the
menu between toggles, then Apply once.

## Build from source

```sh
git clone https://github.com/vLX42/uHosts.git
cd uHosts
./build.sh                # produces build/uHosts.app
./release.sh              # produces dist/uHosts-1.1.0.zip
```

`swift build` handles compilation; `build.sh` wraps the binary in a proper
`.app` bundle and ad-hoc signs it.

## Project layout

```
.
├── Package.swift                  SwiftPM manifest
├── Sources/uHosts/
│   ├── App.swift                  @main NSApplication + status-item menu
│   ├── ContentView.swift          SwiftUI editor view (lazy-loaded)
│   ├── HostsManager.swift         Parse, render, write /etc/hosts
│   └── LaunchAtLogin.swift        Login Item via SMAppService
├── Resources/Info.plist           Bundle metadata (LSUIElement, version)
├── build.sh                       Compile + bundle .app
├── release.sh                     Build + zip + release notes
├── bump.sh                        Update version string in every file
├── deploy-site.sh                 Push website/ to the public Pages mirror
├── website/index.html             Homepage (vLX42/uhosts-site → GitHub Pages)
├── INSTALL.txt                    Shipped inside the release zip
└── .github/workflows/
    ├── build.yml                  CI on every push/PR
    └── release.yml                Build + publish on v* tag push
```

## Hosting

- **Source:** this repo, [`vLX42/uHosts`](https://github.com/vLX42/uHosts).
- **Homepage:** mirrored to the public [`vLX42/uhosts-site`](https://github.com/vLX42/uhosts-site)
  repo and served by GitHub Pages at
  [vlx42.github.io/uhosts-site](https://vlx42.github.io/uhosts-site/).
- **Releases:** attached to GitHub Releases here.
  Versioned download URL is stable per release:
  `https://github.com/vLX42/uHosts/releases/download/vX.Y.Z/uHosts-X.Y.Z.zip`.

To push homepage changes to Pages:

```sh
./deploy-site.sh
```

## Cutting a release

```sh
./bump.sh 1.2.0                                # updates Info.plist, release.sh, README, homepage
git commit -am "Bump version to 1.2.0"
git tag v1.2.0 && git push origin main v1.2.0  # triggers the Release workflow
./deploy-site.sh                               # publish updated download link on Pages
```

The `Release` workflow builds the app, zips it, generates notes, and
publishes a GitHub Release with the artifact attached.

## License

MIT — see [LICENSE](LICENSE).
