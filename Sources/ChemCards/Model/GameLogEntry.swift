import Foundation

struct GameLogEntry: Identifiable, Equatable {
    let id: Int
    let seat: Int
    let text: String
    /// 有配平方程式的记录，日志抽屉（电子手册）会展开显示
    let reaction: Reaction?

    init(id: Int, seat: Int, text: String, reaction: Reaction? = nil) {
        self.id = id
        self.seat = seat
        self.text = text
        self.reaction = reaction
    }
}
