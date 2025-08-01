//
//  VibeLineChartView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/01.
//

import SwiftUI
import Charts

struct VibeLineChartView: View {
    let vibeScores: [Double?]
    let vibeChanges: [VibeChange]?
    
    @State private var selectedTimeSlot: Double?
    @State private var selectedChange: VibeChange?
    
    // データポイントの構造体
    struct DataPoint: Identifiable {
        let id = UUID()
        let timeSlot: Int
        let score: Double
        let time: String
    }
    
    // データポイントのグループ（連続したデータを線でつなぐため）
    struct DataGroup: Identifiable {
        let id = UUID()
        let points: [DataPoint]
    }
    
    // 時間スロットから時刻文字列を生成
    private func timeString(for slot: Int) -> String {
        let hour = slot / 2
        let minute = (slot % 2) * 30
        return String(format: "%02d:%02d", hour, minute)
    }
    
    // 時刻文字列から時間スロットを取得
    private func timeSlotFromString(_ timeString: String) -> Int? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        let hour = components[0]
        let minute = components[1]
        return hour * 2 + (minute >= 30 ? 1 : 0)
    }
    
    // 特定の時間スロットにvibeChangeがあるか確認
    private func vibeChangeAt(slot: Int) -> VibeChange? {
        guard let changes = vibeChanges else { return nil }
        return changes.first { change in
            timeSlotFromString(change.time) == slot
        }
    }
    
    // データポイントをグループ化（連続したデータを同じグループに）
    private var dataGroups: [DataGroup] {
        var groups: [DataGroup] = []
        var currentGroup: [DataPoint] = []
        
        for (index, score) in vibeScores.enumerated() {
            if let scoreValue = score {
                let point = DataPoint(
                    timeSlot: index,
                    score: scoreValue,
                    time: timeString(for: index)
                )
                currentGroup.append(point)
            } else {
                // nullデータの場合、現在のグループを終了
                if !currentGroup.isEmpty {
                    groups.append(DataGroup(points: currentGroup))
                    currentGroup = []
                }
            }
        }
        
        // 最後のグループを追加
        if !currentGroup.isEmpty {
            groups.append(DataGroup(points: currentGroup))
        }
        
        return groups
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("時間帯別の推移")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                // ゼロライン
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                // 選択されたポイントの縦線
                if let selectedSlot = selectedTimeSlot {
                    RuleMark(x: .value("Selected", selectedSlot))
                        .foregroundStyle(Color.blue.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                // 各データグループを描画
                ForEach(dataGroups) { group in
                    ForEach(group.points) { point in
                        // データポイント
                        PointMark(
                            x: .value("時間", Double(point.timeSlot)),
                            y: .value("スコア", point.score)
                        )
                        .foregroundStyle(vibeChangeAt(slot: point.timeSlot) != nil ? Color.orange : scoreColor(for: point.score))
                        .symbolSize(vibeChangeAt(slot: point.timeSlot) != nil ? 150 : 100)
                        .symbol {
                            if vibeChangeAt(slot: point.timeSlot) != nil {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            } else {
                                Circle()
                                    .fill(scoreColor(for: point.score))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        // グループ内で線を描画（2点以上ある場合）
                        if group.points.count > 1 {
                            LineMark(
                                x: .value("時間", Double(point.timeSlot)),
                                y: .value("スコア", point.score)
                            )
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal)
            .chartXScale(domain: 0...47)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 24, 30, 36, 42]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let slot = value.as(Int.self) {
                            Text(timeString(for: slot))
                                .font(.caption2)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .chartYScale(domain: -100...100)
            .chartYAxis {
                AxisMarks(values: [-100, -50, 0, 50, 100]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let score = value.as(Int.self) {
                            Text("\(score)")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedTimeSlot)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            .overlay(alignment: .topLeading) {
                // 吹き出し表示
                if let selectedSlot = selectedTimeSlot,
                   let change = vibeChanges?.first(where: { timeSlotFromString($0.time) == Int(selectedSlot) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.event)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Text("スコア: \(Int(change.score))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    )
                    .offset(x: CGFloat(selectedSlot / 47) * (UIScreen.main.bounds.width - 80) + 20, y: 20)
                    .animation(.easeInOut(duration: 0.2), value: selectedSlot)
                }
            }
            .onTapGesture { location in
                // タップ位置から最も近いvibeChangeを探す
                if let changes = vibeChanges, !changes.isEmpty {
                    // チャートの幅を取得
                    let chartWidth = UIScreen.main.bounds.width - 80
                    let xPosition = location.x - 40  // パディングを考慮
                    let tappedSlot = Int((xPosition / chartWidth) * 47)
                    
                    // タップした位置に近いvibeChangeを探す
                    if let nearestChange = changes.min(by: { change1, change2 in
                        let slot1 = timeSlotFromString(change1.time) ?? 0
                        let slot2 = timeSlotFromString(change2.time) ?? 0
                        return abs(slot1 - tappedSlot) < abs(slot2 - tappedSlot)
                    }) {
                        if let slot = timeSlotFromString(nearestChange.time),
                           abs(slot - tappedSlot) < 3 {  // 3スロット以内なら選択
                            withAnimation {
                                selectedTimeSlot = Double(slot)
                                selectedChange = nearestChange
                            }
                        } else {
                            withAnimation {
                                selectedTimeSlot = nil
                                selectedChange = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    // スコアに基づく色を返す
    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 60...:
            return .green
        case 20..<60:
            return .blue
        case -20..<20:
            return .gray
        case -60..<(-20):
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    VibeLineChartView(
        vibeScores: [
            nil, nil, 30, 45, 50, nil, nil, nil, -20, -30, -40, nil,
            60, 70, 80, 75, nil, nil, nil, 10, 20, 30, 40, 50,
            nil, nil, nil, nil, -50, -60, -70, nil, nil, nil, nil, nil,
            90, 85, 80, nil, nil, nil, 0, 10, 20, nil, nil, nil
        ],
        vibeChanges: [
            VibeChange(time: "02:00", event: "朝の目覚め - 気分が良い", score: 30),
            VibeChange(time: "04:30", event: "朝の運動 - エネルギッシュ", score: 50),
            VibeChange(time: "14:00", event: "仕事のストレス - 疲労感", score: -60),
            VibeChange(time: "19:00", event: "夕食後のリラックス", score: 80)
        ]
    )
}