import Foundation
import SwiftUI

/// 素材查找顺序：用户可写目录里的同名文件覆盖 app bundle 内的资源，
/// 换立绘、换牌桌背景都不需要重新编译（换完重启一次游戏生效）。
/// macOS 用 `~/Library/Application Support/ChemCards/assets/`，
/// iOS 用 Documents ——「文件」App 看到的就是它，相对路径和 bundle 内一致。
/// 裸可执行文件（swift run / --render）还会回退到仓库根目录的 Resources/。
/// 立绘每一帧都要查，所以路径存在性和图片本身都做记忆化。
enum AssetLoader {

    private static let images = NSCache<NSString, Platform.PixelImage>()
    private static let fileManager = FileManager.default
    private static var urls: [String: URL?] = [:]
    private static var layers: [CharacterID: Set<String>] = [:]

    static let overrideRoot: URL = {
        #if os(iOS)
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ChemCards/assets", isDirectory: true)
            ?? URL(fileURLWithPath: "/tmp/ChemCards-assets")
        #endif
    }()

    static func url(_ relative: String) -> URL? {
        if let hit = urls[relative] { return hit }
        let found = resolve(relative)
        urls[relative] = found
        return found
    }

    private static func resolve(_ relative: String) -> URL? {
        let override = overrideRoot.appendingPathComponent(relative)
        if fileManager.fileExists(atPath: override.path) { return override }
        let hit = searchRoots.lazy.map { $0.appendingPathComponent(relative) }
            .first { fileManager.fileExists(atPath: $0.path) }
        return hit
    }

    /// .app 里的 Contents/Resources，以及开发时（裸可执行文件）仓库根目录下的 Resources/
    private static let searchRoots: [URL] = {
        var roots: [URL] = []
        if let packed = Bundle.main.resourceURL {
            roots.append(packed)
            // iOS bundle 有可能把资源目录整个嵌一层，这里兜底；macOS 上这条路径不存在
            roots.append(packed.appendingPathComponent("Resources", isDirectory: true))
        }
        var directory = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        for _ in 0..<4 {
            roots.append(directory.appendingPathComponent("Resources", isDirectory: true))
            directory = directory.deletingLastPathComponent()
        }
        roots.append(URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("Resources", isDirectory: true))
        return roots
    }()

    static func pixelImage(_ relative: String) -> Platform.PixelImage? {
        guard let url = url(relative) else { return nil }
        let key = relative as NSString
        if let hit = images.object(forKey: key) { return hit }
        guard let image = Platform.loadPixelImage(url) else { return nil }
        images.setObject(image, forKey: key)
        return image
    }

    static func image(_ relative: String) -> Image? {
        pixelImage(relative).map(Platform.swiftImage)
    }

    /// 立绘分层：Resources/Characters/<角色>/<图层>.png，缺图层由 PortraitRig 自行降级
    static func portrait(_ character: CharacterID, layer: String = "base") -> Image? {
        image("Characters/\(character.folder)/\(layer).png")
    }

    static func tableBackground() -> Image? { image("Table/table_bg.png") }

    /// 立绘目录里到底有哪几层，用来决定要不要启用分层动画
    static func availableLayers(_ character: CharacterID) -> Set<String> {
        if let hit = layers[character] { return hit }
        let known = ["base", "hair_front", "sleeve_l", "sleeve_r", "eyes_open", "eyes_close",
                     "mouth_0", "mouth_1", "mouth_2", "mouth_3", "blush"]
        let found = Set(known.filter { url("Characters/\(character.folder)/\($0).png") != nil })
        layers[character] = found
        return found
    }
}
