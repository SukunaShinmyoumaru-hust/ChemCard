import Foundation

/// 无界面的工具命令：跑完就退出，不起窗口。
enum CLI {

    static func run(arguments: [String]) -> Int32? {
        switch arguments.first {
        case "--dump-reactions": return dumpReactions(Array(arguments.dropFirst()))
        case "--render": return RenderHarness.run(Array(arguments.dropFirst()))
        default: return nil
        }
    }

    /// 把规则引擎推导出的反应全集写成 Resources/Data/reactions.json
    private static func dumpReactions(_ arguments: [String]) -> Int32 {
        let path = arguments.first(where: { !$0.hasPrefix("-") }) ?? "Resources/Data/reactions.json"
        let map = ReactionTable.generated()
        let url = URL(fileURLWithPath: path)
        do {
            let data = try ReactionTable.encodedJSON(for: map)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            print("✓ 已生成 \(map.count) 条反应 → \(url.path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("生成反应表失败：\(error)\n".utf8))
            return 1
        }
    }
}
