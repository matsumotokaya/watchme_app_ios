//
//  HomeView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // ローディング表示
                if dataManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("レポートを取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                }
                
                // エラー表示
                if let error = dataManager.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("データを取得できませんでした")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // レポート表示
                if let report = dataManager.dailyReport {
                    VStack(alignment: .leading, spacing: 16) {
                        // 感情サマリーカード
                        VStack(spacing: 16) {
                            // 平均スコア
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("今日の平均スコア")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", report.averageScore))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(report.averageScoreColor)
                                }
                                Spacer()
                                Image(systemName: report.averageScoreIcon)
                                    .font(.system(size: 60))
                                    .foregroundColor(report.averageScoreColor)
                            }
                            .padding()
                            .background(report.averageScoreColor.opacity(0.1))
                            .cornerRadius(16)
                            
                            // 感情の時間分布
                            VStack(spacing: 12) {
                                EmotionTimeBar(
                                    label: "ポジティブ",
                                    hours: report.positiveHours,
                                    percentage: report.positivePercentage,
                                    color: .green
                                )
                                EmotionTimeBar(
                                    label: "ニュートラル",
                                    hours: report.neutralHours,
                                    percentage: report.neutralPercentage,
                                    color: .gray
                                )
                                EmotionTimeBar(
                                    label: "ネガティブ",
                                    hours: report.negativeHours,
                                    percentage: report.negativePercentage,
                                    color: .red
                                )
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // インサイト
                        if !report.insights.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("今日のインサイト")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(report.insights.enumerated()), id: \.offset) { index, insight in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                            Text(insight)
                                                .font(.subheadline)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        // 時間帯別グラフ (折れ線グラフ版)
                        if let vibeScores = report.vibeScores {
                            VibeLineChartView(vibeScores: vibeScores, vibeChanges: report.vibeChanges)
                        }
                    }
                } else if !dataManager.isLoading && dataManager.errorMessage == nil {
                    // エンプティステート表示（共通コンポーネント使用）
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !deviceManager.userDevices.isEmpty
                    )
                }
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle("心理グラフ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Views

struct EmotionTimeBar: View {
    let label: String
    let hours: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(String(format: "%.1f", hours))時間 (\(String(format: "%.0f", percentage))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    return NavigationView {
        HomeView()
        .environmentObject(authManager)
        .environmentObject(SupabaseDataManager())
        .environmentObject(deviceManager)
    }
}