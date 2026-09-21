import SwiftUI

/// 侧边抽屉：上半是「实录」（每一步发生了什么），下半是「手册」（本局出现过的反应，可复习）
struct LogDrawerView: View {
    @ObservedObject var state: GameState
    var onClose: () -> Void

    @State private var tab: Tab = .log

    enum Tab: String, CaseIterable, Identifiable {
        case log = "实录"
        case book = "反应手册"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider().overlay(Theme.Color.panelStroke)

            switch tab {
            case .log: logList
            case .book: handbook
            }
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(SwiftUI.Color(white: 0.07).opacity(0.86))
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.Color.panelStroke).frame(width: 1)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(state.log.reversed()) { entry in
                        LogRow(entry: entry, name: state.players[entry.seat % state.seatCount].name)
                            .id(entry.id)
                    }
                }
                .padding(12)
            }
            .onAppear { proxy.scrollTo(state.log.last?.id ?? 0, anchor: .top) }
        }
    }

    /// 手册：把本局发生过的反应去重，复杂反应排前面，附上易错点
    private var handbook: some View {
        let reactions = handbookReactions
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if reactions.isEmpty {
                    Text("还没有发生任何反应。打出一张能和容器里物质反应的牌，这里就会记下它的方程式。")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .padding(14)
                }
                ForEach(Array(reactions.enumerated()), id: \.offset) { _, reaction in
                    HandbookRow(reaction: reaction)
                }
            }
            .padding(12)
        }
    }

    private var handbookReactions: [Reaction] {
        var seen = Set<String>()
        var list: [Reaction] = []
        for entry in state.log {
            guard let reaction = entry.reaction else { continue }
            guard seen.insert(reaction.displayEquation).inserted else { continue }
            list.append(reaction)
        }
        return list.sorted { $0.points > $1.points }
    }
}

private struct LogRow: View {
    let entry: GameLogEntry
    let name: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.Color.textPrimary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                if let reaction = entry.reaction, let note = reaction.note {
                    Text("考点：\(note)")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.42).opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.Color.panel))
    }

    private var tint: SwiftUI.Color {
        if entry.reaction != nil { return Theme.Color.legalGlow }
        return Theme.Color.textSecondary
    }
}

private struct HandbookRow: View {
    let reaction: Reaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reaction.rule)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.accent)
                Spacer()
                Text(reaction.tier.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(reaction.displayEquation)
                .font(Theme.Font.formula(15))
                .foregroundStyle(Theme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(reaction.phenomenonText)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary)
            if let note = reaction.note {
                Text("易错点：\(note)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.Color.panel))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
    }
}
