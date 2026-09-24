import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 平台差异收口：图片类型与「减少动态效果」系统开关。
/// 桌面用 AppKit，iPhone 用 UIKit，其余代码只认这一个入口。
enum Platform {

    #if canImport(UIKit)
    typealias PixelImage = UIImage
    #elseif canImport(AppKit)
    typealias PixelImage = NSImage
    #endif

    static func loadPixelImage(_ url: URL) -> PixelImage? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path)
        #elseif canImport(AppKit)
        return NSImage(contentsOf: url)
        #else
        return nil
        #endif
    }

    static func swiftImage(_ image: PixelImage) -> SwiftUI.Image {
        #if canImport(UIKit)
        return SwiftUI.Image(uiImage: image)
        #elseif canImport(AppKit)
        return SwiftUI.Image(nsImage: image)
        #else
        fatalError("没有可用的图像框架")
        #endif
    }

    /// 系统级「减少动态效果」，立绘时钟据此决定要不要静止
    static var systemReduceMotion: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #elseif canImport(AppKit)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return false
        #endif
    }
}
