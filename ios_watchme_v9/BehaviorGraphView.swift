//
//  BehaviorGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct BehaviorGraphView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var selectedDate = Date()
    @State private var behaviorReport: BehaviorReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var expandedTimeBlocks: Set<String> = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Date Navigation
            HStack(spacing: 20) {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.headline)
                    .frame(minWidth: 150)
                
                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("データを読み込み中...")
                            .padding(.top, 50)
                    } else if let report = behaviorReport {
                        // Summary Ranking Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                Text("1日の行動ランキング")
                                    .font(.headline)
                                Spacer()
                                Text("合計: \(report.totalEventCount)件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(report.summaryRanking.prefix(5).enumerated()), id: \.offset) { index, event in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .frame(width: 25, alignment: .trailing)
                                    
                                    Text(event.event)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text("\(event.count)回")
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
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Time Blocks Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                Text("時間帯別の行動")
                                    .font(.headline)
                                Spacer()
                                Text("\(report.activeTimeBlocks.count)/48 スロット")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Time blocks grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(report.sortedTimeBlocks, id: \.time) { block in
                                    TimeBlockCell(
                                        timeBlock: block,
                                        isExpanded: expandedTimeBlocks.contains(block.time)
                                    ) {
                                        toggleTimeBlock(block.time)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("この日のデータがありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("行動グラフ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchBehaviorData()
        }
        .alert("エラー", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
        }
    }
    
    private func fetchBehaviorData() {
        guard authManager.isAuthenticated else {
            errorMessage = "ログインが必要です"
            showingError = true
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.actualDeviceID else {
            errorMessage = "デバイスが登録されていません"
            showingError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateString = formatter.string(from: selectedDate)
                
                let report = try await dataManager.fetchBehaviorReport(
                    deviceId: deviceId,
                    date: dateString
                )
                
                await MainActor.run {
                    self.behaviorReport = report
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            expandedTimeBlocks.removeAll()
            fetchBehaviorData()
        }
    }
    
    private func toggleTimeBlock(_ time: String) {
        if expandedTimeBlocks.contains(time) {
            expandedTimeBlocks.remove(time)
        } else {
            expandedTimeBlocks.insert(time)
        }
    }
}

// MARK: - Time Block Cell
struct TimeBlockCell: View {
    let timeBlock: TimeBlock
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(timeBlock.displayTime)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(timeBlock.isEmpty ? .secondary : .primary)
                
                if timeBlock.isEmpty {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 20)
                        .overlay(
                            Text("-")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(backgroundGradient(for: timeBlock.hourInt))
                        .frame(height: 20)
                        .overlay(
                            Text("\(timeBlock.events?.count ?? 0)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: .constant(isExpanded && !timeBlock.isEmpty)) {
            TimeBlockDetailView(timeBlock: timeBlock, onDismiss: onTap)
                .presentationDetents([.medium])
        }
    }
    
    private func backgroundGradient(for hour: Int) -> LinearGradient {
        let colors: [Color]
        switch hour {
        case 0..<6:
            colors = [.purple, .indigo] // 深夜
        case 6..<9:
            colors = [.orange, .yellow] // 朝
        case 9..<12:
            colors = [.blue, .cyan] // 午前
        case 12..<15:
            colors = [.green, .mint] // 午後早め
        case 15..<18:
            colors = [.teal, .blue] // 午後
        case 18..<21:
            colors = [.orange, .red] // 夕方
        default:
            colors = [.indigo, .purple] // 夜
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Time Block Detail View
struct TimeBlockDetailView: View {
    let timeBlock: TimeBlock
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("\(timeBlock.displayTime) の行動")) {
                    if let events = timeBlock.events {
                        ForEach(events) { event in
                            HStack {
                                Text(event.event)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(event.count)回")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("時間帯詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        BehaviorGraphView()
    }
}