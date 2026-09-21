import Foundation

/// 自检开关：`ChemCards --smoke-test` 启动时打印窗口状态后退出，用于验证打包产物真的能起 GUI。
enum Smoke {
    static var enabled = CommandLine.arguments.contains("--smoke-test")
}
