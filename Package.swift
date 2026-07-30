// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Science Club Diary",
    platforms: [
        .iOS("18.1")
    ],
    products: [
        .iOSApplication(
            name: "Science Club Diary",
            targets: ["DiaryApp"],
            bundleIdentifier: "viuk.scienceclub.diary",
            teamIdentifier: "34CN68272C",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .sparkle),
            accentColor: .presetColor(.pink),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [],
            appCategory: .lifestyle
        )
    ],
    targets: [
        .executableTarget(
            name: "DiaryApp",
            path: "Diary"
        )
    ]
)
