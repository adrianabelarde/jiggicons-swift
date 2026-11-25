# Jiggicons for SwiftUI

Animated Jiggicons for iOS, iPadOS, macOS, tvOS and visionOS. Every icon has a spring motion and a
spatial sound. This package has the 80 free icons, and plays any icon from the full set that you add
with the Jiggicons CLI.

In Xcode choose File → Add Package Dependencies and enter `https://github.com/adrianabelarde/jiggicons-swift`,
or add it to `Package.swift`:

```swift
.package(url: "https://github.com/adrianabelarde/jiggicons-swift", from: "0.2.0")
```

Then:

```swift
import Jiggicons

JiggIcon("bell", variant: .solid, size: 28, sound: true, label: "Notifications")
```

Tap it and it plays. Parameters: `variant` (`.outline`, `.solid`, `.duotone`,
`.glass`), `size`, `color` (default: the view's `.foregroundStyle`), `sound`, `volume`, `trigger`
(`.tap`, `.appear`, `.none`), `label` (accessible name) and `playWhen` (plays whenever the value changes).
Motion follows Reduce Motion. Requires iOS 15 or macOS 12.

To play it from a button or your own code, change `playWhen`:

```swift
@State private var saved = 0

Button { saved += 1 } label: {
    Label { Text("Save") } icon: { JiggIcon("saved", variant: .duotone, trigger: .none, playWhen: saved) }
}
```

## Sound

The sounds are made by the same synthesis as on the web, already placed between the two speakers along
the path the icon moves, and ship as small .m4a files (about 1.4 MB for all 80 icons). They play through
`AVAudioPlayer` in the ambient category, so they mix with the user's music and stay quiet when the phone
is set to silent. Your app's own audio session is left alone if it already set one.

```swift
JiggiconsAudio.shared.volume = 0.6
```

## Icons from the full set

This package has the 80 free icons. With a Jiggicons licence, the CLI puts any of the other icons into your
Xcode project. In the folder that holds your `.xcodeproj`:

```bash
npx jiggicons login
npx jiggicons add shopping-bag search
```

It writes each icon's data and sounds into `YourApp/Jiggicons`. Xcode 16 includes that folder in your app by
itself; in an older project, drag the folder into Xcode once. Then use the icon by name:

```swift
JiggIcon("shopping-bag", variant: .glass, size: 28, sound: true)
```

Icons are looked for in your app's main bundle. If they live in a framework or a Swift package, call
`Jiggicons.register(bundle: .module)` first; `Jiggicons.register(folder:)` adds a folder on disk.

## Frames and other icons

`JiggiconFrame(icon:variant:seconds:)` draws a single pose, for previews or your own timing.
`Jiggicons.all` lists the bundled icons; `Jiggicons.load(contentsOf:)` reads an icon in the same JSON
format from your own bundle.

## Try it

```bash
swift run JiggiconsDemo           # a macOS window with every free icon
swift run JiggiconsCheck          # checks the data, drawing and sounds (no Xcode needed)
```

The icon data and sounds in `Sources/Jiggicons/Resources` are generated from the Jiggicons sources; this
repository is updated with each release. The full set of 6,010 icons is at https://jiggicons.com.

Docs: https://jiggicons.com/docs/swiftui
