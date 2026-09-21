import Foundation

/// 「谁和谁能反应」的唯一裁判。
///
/// 运行期只查这张表：键是按登记表顺序规范化的物种 id 对，值是完整的反应记录
/// （配平方程式、反应类型、现象、初高中档位、易错点）。
/// 表本身由 `ReactionTable.generated()` 从规则引擎 + 精选反应表推导生成，
/// 落盘成 `Resources/Data/reactions.json`，可以手工审阅和增删。
enum ReactionTable {

    enum Source: Equatable {
        case file(URL)
        case derived   // 找不到 json 时的兜底：现场推导，保证开发与测试不因缺资源而卡住
    }

    private static let ioLock = NSLock()
    private static var reactions: [String: Reaction] = [:]
    private static var loaded = false

    static private(set) var source: Source = .derived

    /// 手工剔除的记录不对：键与 `key(_:_:)` 同格式。规则推导不出来的错反应写在这里。
    static let denied: Set<String> = []

    // MARK: 键

    /// 与调用顺序无关：位置靠前的物种写在前面
    static func key(_ x: Species, _ y: Species) -> String {
        let (a, b) = Chemistry.ordered(x, y)
        return "\(a.id)+\(b.id)"
    }

    // MARK: 查询

    static func reaction(_ x: Species, _ y: Species) -> Reaction? {
        ensureLoaded()
        guard x.id != y.id else { return nil }
        return reactions[key(x, y)]
    }

    static var count: Int {
        ensureLoaded()
        return reactions.count
    }

    /// 冒烟自检用：说明当前生效的表是打包文件还是现场推导
    static var describeSource: String {
        switch source {
        case .file(let url): return "file(\(url.lastPathComponent)@\(url.deletingLastPathComponent().lastPathComponent))"
        case .derived: return "derived"
        }
    }

    /// 反应手册用：按分值从高到低
    static func all() -> [Reaction] {
        ensureLoaded()
        return reactions.values.sorted { $0.points != $1.points ? $0.points > $1.points : $0.displayEquation < $1.displayEquation }
    }

    // MARK: 装载

    static func ensureLoaded() {
        ioLock.lock()
        defer { ioLock.unlock() }
        if loaded { return }
        loaded = true
        if let url = locateShippedFile(), let map = try? decode(url: url) {
            reactions = map
            source = .file(url)
        } else {
            reactions = generated()
            source = .derived
        }
    }

    /// 强制使用某张表（生成器、单元测试使用）
    static func install(_ map: [String: Reaction], from: URL? = nil) {
        ioLock.lock()
        defer { ioLock.unlock() }
        reactions = map
        loaded = true
        source = from.map { Source.file($0) } ?? .derived
    }

    static func decode(url: URL) throws -> [String: Reaction] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ReactionFile.self, from: data).reactions
    }

    @discardableResult
    static func load(url: URL) throws -> [String: Reaction] {
        let map = try decode(url: url)
        install(map, from: url)
        return map
    }

    /// 依次尝试：外部覆盖目录 → app bundle → 仓库内的 Resources（源码直跑时）
    static func locateShippedFile() -> URL? {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["CHEMCARDS_REACTIONS"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(support.appendingPathComponent("ChemCards/data/reactions.json"))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("Data/reactions.json"))
        }
        for bundle in [Bundle.main] + Bundle.allBundles {
            if let url = bundle.url(forResource: "reactions", withExtension: "json", subdirectory: "Data") {
                candidates.append(url)
            }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: 生成

    /// 遍历全部物种对，用规则引擎 + 精选反应表推导出完整反应表
    static func generated() -> [String: Reaction] {
        var map: [String: Reaction] = [:]
        let species = Chemistry.all
        for i in 0..<species.count {
            for j in (i + 1)..<species.count {
                let a = species[i], b = species[j]
                let pair = key(a, b)
                guard !denied.contains(pair) else { continue }
                guard let reaction = ReactionEngine.derive(a, b) else { continue }
                map[pair] = reaction
            }
        }
        return map
    }

    static func encodedJSON(for map: [String: Reaction]) throws -> Data {
        let file = ReactionFile(version: 1, reactions: map)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    struct ReactionFile: Codable {
        var version: Int
        var reactions: [String: Reaction]
    }
}
