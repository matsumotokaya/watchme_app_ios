//
//  EmotionGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Charts

struct EmotionGraphView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // オプショナルでデータを受け取る
    var emotionReport: EmotionReport?
    
    @State private var selectedEmotions: Set<EmotionType> = Set(EmotionType.allCases)
    @State private var showingLegend = true
    
    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if dataManager.isLoading {
                        ProgressView("データを読み込み中...")
                            .padding(.top, 50)
                    } else if let report = emotionReport ?? dataManager.dailyEmotionReport {
                        // Emotion Ranking Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "list.number")
                                    .foregroundColor(.blue)
                                Text("1日の感情ランキング")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(report.emotionRanking.prefix(8).enumerated()), id: \.offset) { index, emotion in
                                if emotion.value > 0 {
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .trailing)
                                        
                                        Circle()
                                            .fill(emotion.color)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(emotion.name)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(emotion.value)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Emotion Chart Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.line")
                                    .foregroundColor(.blue)
                                Text("時間帯別感情推移")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showingLegend.toggle() }) {
                                    Image(systemName: showingLegend ? "eye.fill" : "eye.slash.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Line Chart
                            if report.activeTimePoints.count > 0 {
                                Chart {
                                    ForEach(EmotionType.allCases, id: \.self) { emotionType in
                                        if selectedEmotions.contains(emotionType) {
                                            ForEach(report.emotionGraph, id: \.time) { point in
                                                LineMark(
                                                    x: .value("時間", point.timeValue),
                                                    y: .value("値", getValue(for: emotionType, from: point))
                                                )
                                                .foregroundStyle(emotionType.color)
                                                .lineStyle(StrokeStyle(lineWidth: 2))
                                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                                .symbolSize(30)
                                                .interpolationMethod(.catmullRom)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 300)
                                .padding(.horizontal)
                                .chartXScale(domain: 0...24)
                                .chartXAxis {
                                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let hour = value.as(Double.self) {
                                                Text("\(Int(hour)):00")
                                            }
                                        }
                                    }
                                }
                                .chartYScale(domain: 0...10)
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                
                                // Legend
                                if showingLegend {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("感情の種類")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: 8) {
                                            ForEach(EmotionType.allCases, id: \.self) { emotionType in
                                                Button(action: {
                                                    toggleEmotion(emotionType)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(emotionType.color)
                                                            .frame(width: 10, height: 10)
                                                        Text(emotionType.rawValue)
                                                            .font(.caption)
                                                            .foregroundColor(selectedEmotions.contains(emotionType) ? .primary : .secondary)
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(selectedEmotions.contains(emotionType) ? emotionType.lightColor : Color(.systemGray6))
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.top, 8)
                                }
                            } else {
                                Text("データがありません")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        
                    } else {
                        // エンプティステート表示（共通コンポーネント使用）
                        GraphEmptyStateView(
                            graphType: .emotion,
                            isDeviceLinked: !deviceManager.userDevices.isEmpty
                        )
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 20)
            }
        .navigationTitle("感情グラフ")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleEmotion(_ emotionType: EmotionType) {
        if selectedEmotions.contains(emotionType) {
            selectedEmotions.remove(emotionType)
        } else {
            selectedEmotions.insert(emotionType)
        }
    }
    
    private func getValue(for emotionType: EmotionType, from point: EmotionTimePoint) -> Int {
        switch emotionType {
        case .joy: return point.joy
        case .fear: return point.fear
        case .anger: return point.anger
        case .trust: return point.trust
        case .disgust: return point.disgust
        case .sadness: return point.sadness
        case .surprise: return point.surprise
        case .anticipation: return point.anticipation
        }
    }
}

#Preview {
    NavigationView {
        EmotionGraphView()
    }
}