import Foundation
import SwiftUI

#if os(iOS)
/// iPhone 入口。桌面版的入口在 `Sources/ChemCards/App/GameMain.swift`，
/// 那套 NSApplication + 手搭 .app 的装配方式在 iOS 上不存在，两边只共享界面与内核。
@main
struct ChemCardsApp: App {
    var body: some Scene {
        WindowGroup {
            PhoneRootView()
        }
    }
}

/// 根视图：强制深色，并接住 `--smoke-test` 与 `--scene=`
struct PhoneRootView: View {
    var body: some View {
        GameRootView(scene: Smoke.scene)
            .preferredColorScheme(.dark)
            .task {
                guard Smoke.enabled else { return }
                // 等一帧，让界面真的装上再报，不然自检只能证明进程起来了
                try? await Task.sleep(nanoseconds: 800_000_000)
                print("SMOKE \(Smoke.report())")
                exit(0)
            }
    }
}
#endif
