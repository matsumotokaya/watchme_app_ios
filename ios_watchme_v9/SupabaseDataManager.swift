//
//  SupabaseDataManager.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Supabaseデータ管理クラス
// vibe_whisper_summaryテーブルからデータを取得・管理する責務を持つ
@MainActor
class SupabaseDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyReport: DailyVibeReport?
    @Published var dailyBehaviorReport: BehaviorReport? // 新しく追加
    @Published var dailyEmotionReport: EmotionReport?   // 新しく追加
    @Published var weeklyReports: [DailyVibeReport] = []
    @Published var subject: Subject?
    @Published var subjects: [Subject] = []  // 複数のSubjectを管理
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 現在のユーザーID
    var currentUserId: String? {
        // Supabaseの現在のセッションからユーザーIDを取得
        // 実際の実装では SupabaseAuthManager から取得する必要がある
        return nil
    }
    
    // MARK: - Private Properties
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Initialization
    init() {
        print("📊 SupabaseDataManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// 特定の日付のレポートを取得
    func fetchDailyReport(for deviceId: String, date: Date) async {
        // このメソッドはfetchAllReportsから呼ばれることを想定
        // エラー時はerrorMessageを設定し、UIに即座に反映させる
        
        let dateString = dateFormatter.string(from: date)
        print("📅 Fetching daily report for device: \(deviceId), date: \(dateString)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [DailyVibeReport] = try await supabase
                .from("vibe_whisper_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: dateString)
                .execute()
                .value
            
            print("📊 Decoded reports count: \(reports.count)")
            
            await MainActor.run { [weak self] in
                if let report = reports.first {
                    self?.dailyReport = report
                    print("✅ Daily report fetched successfully")
                    print("   Average score: \(report.averageScore)")
                    print("   Insights count: \(report.insights.count)")
                } else {
                    print("⚠️ No report found for the specified date")
                    self?.dailyReport = nil
                }
            }
            
        } catch {
            print("❌ Fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "データの取得に失敗しました: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }
    }
    
    /// 日付範囲でレポートを取得（週次表示用）
    /// - Note: 現在は未使用。将来の週次グラフ機能実装時に使用予定
    /// - TODO: 週次グラフ機能を実装する際にこのメソッドを活用
    func fetchWeeklyReports(for deviceId: String, startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        weeklyReports = []
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        print("📅 Fetching weekly reports for device: \(deviceId)")
        print("   From: \(startDateString) To: \(endDateString)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [DailyVibeReport] = try await supabase
                .from("vibe_whisper_summary")
                .select()
                .eq("device_id", value: deviceId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .order("date", ascending: true)
                .execute()
                .value
            
            self.weeklyReports = reports
            
            print("✅ Weekly reports fetched successfully")
            print("   Reports count: \(reports.count)")
            
        } catch {
            print("❌ Fetch error: \(error)")
            errorMessage = "エラー: \(error.localizedDescription)"
            
            // PostgrestErrorの詳細を表示
            if let dbError = error as? PostgrestError {
                print("   - コード: \(dbError.code ?? "不明")")
                print("   - メッセージ: \(dbError.message)")
            }
        }
        
        isLoading = false
    }
    
    /// データをクリア
    func clearData() {
        dailyReport = nil
        dailyBehaviorReport = nil
        dailyEmotionReport = nil
        weeklyReports = []
        subject = nil
        errorMessage = nil
    }
    
    /// 統合データフェッチメソッド - RPCを使ってすべてのグラフデータを一括で取得（高速版）
    func fetchAllReports(deviceId: String, date: Date) async {
        await MainActor.run { [weak self] in
            self?.isLoading = true
            self?.errorMessage = nil
            // データをクリアして、古い情報が残らないようにする
            self?.dailyReport = nil
            self?.dailyBehaviorReport = nil
            self?.dailyEmotionReport = nil
            self?.subject = nil
        }

        let dateString = dateFormatter.string(from: date)
        print("🚀 Fetching all reports via RPC for device: \(deviceId), date: \(dateString)")

        do {
            // RPCを呼び出す
            let params = ["p_device_id": deviceId, "p_date": dateString]
            let response: [DashboardData] = try await supabase.rpc("get_dashboard_data", params: params).execute().value

            // レスポンスを処理
            if let data = response.first {
                await MainActor.run { [weak self] in
                    self?.dailyReport = data.vibe_report
                    self?.dailyBehaviorReport = data.behavior_report
                    self?.dailyEmotionReport = data.emotion_report
                    self?.subject = data.subject_info

                    print("✅ All reports fetched successfully via RPC")
                    if data.vibe_report == nil { print("   - Vibe report: Not found") }
                    if data.behavior_report == nil { print("   - Behavior report: Not found") }
                    if data.emotion_report == nil { print("   - Emotion report: Not found") }
                    if data.subject_info == nil { print("   - Subject info: Not found") }
                }
            } else {
                print("⚠️ RPC returned no data.")
            }

        } catch {
            print("❌ RPC fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "データの一括取得に失敗しました: \(error.localizedDescription)"
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }

        await MainActor.run { [weak self] in
            self?.isLoading = false
        }
    }
    
    // MARK: - Behavior Report Methods
    
    /// 特定の日付の行動レポートを取得
    func fetchBehaviorReport(deviceId: String, date: String) async -> BehaviorReport? {
        print("📊 Fetching behavior report for device: \(deviceId), date: \(date)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [BehaviorReport] = try await supabase
                .from("behavior_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: date)
                .execute()
                .value
            
            if let report = reports.first {
                print("✅ Behavior report fetched successfully")
                print("   Total events: \(report.totalEventCount)")
                print("   Active time blocks: \(report.activeTimeBlocks.count)")
                return report
            } else {
                print("⚠️ No behavior report found for the specified date")
                return nil
            }
            
        } catch {
            print("❌ Behavior fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "行動データの取得エラー: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
            return nil
        }
    }
    
    // MARK: - Emotion Report Methods
    
    /// 特定の日付の感情レポートを取得
    func fetchEmotionReport(deviceId: String, date: String) async -> EmotionReport? {
        print("🎭 Fetching emotion report for device: \(deviceId), date: \(date)")
        
        do {
            // Supabase SDKの標準メソッドを使用
            let reports: [EmotionReport] = try await supabase
                .from("emotion_opensmile_summary")
                .select()
                .eq("device_id", value: deviceId)
                .eq("date", value: date)
                .execute()
                .value
            
            if let report = reports.first {
                print("✅ Emotion report fetched successfully")
                print("   Emotion graph points: \(report.emotionGraph.count)")
                print("   Active time points: \(report.activeTimePoints.count)")
                return report
            } else {
                print("⚠️ No emotion report found for the specified date")
                return nil
            }
            
        } catch {
            print("❌ Emotion fetch error: \(error)")
            await MainActor.run { [weak self] in
                self?.errorMessage = "感情データの取得エラー: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
            return nil
        }
    }
    
    /// デバイスに紐づく観測対象情報を取得
    func fetchSubjectForDevice(deviceId: String) async {
        print("👤 Fetching subject for device: \(deviceId)")
        
        do {
            // まずdevicesテーブルからsubject_idを取得
            struct DeviceResponse: Codable {
                let device_id: String
                let subject_id: String?
            }
            
            let devices: [DeviceResponse] = try await supabase
                .from("devices")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            guard let device = devices.first, let subjectId = device.subject_id else {
                print("ℹ️ No subject assigned to this device")
                await MainActor.run { [weak self] in
                    self?.subject = nil
                }
                return
            }
            
            // subject_idを使ってsubjectsテーブルから情報を取得
            let subjects: [Subject] = try await supabase
                .from("subjects")
                .select()
                .eq("subject_id", value: subjectId)
                .execute()
                .value
            
            // MainActorで@Publishedプロパティを更新
            await MainActor.run { [weak self] in
                self?.subject = subjects.first
                if let subject = subjects.first {
                    print("✅ Subject fetched successfully")
                    print("   Name: \(subject.name ?? "N/A")")
                    print("   Age: \(subject.age ?? 0)")
                    print("   Gender: \(subject.gender ?? "N/A")")
                } else {
                    print("ℹ️ Subject not found in subjects table")
                }
            }
            
        } catch {
            print("❌ Subject fetch error: \(error)")
            // PostgrestErrorの詳細を表示
            if let dbError = error as? PostgrestError {
                print("   - コード: \(dbError.code ?? "不明")")
                print("   - メッセージ: \(dbError.message)")
            }
        }
    }
    
    // MARK: - Avatar Methods
    
    /// ユーザーのアバター画像の署名付きURLを取得する
    /// - Parameter userId: 取得対象のユーザーID
    /// - Returns: 1時間有効なアバター画像のURL。存在しない、またはエラーの場合はnil。
    func fetchAvatarUrl(for userId: String) async -> URL? {
        print("👤 Fetching avatar URL for user: \(userId)")
        
        // 1. ファイルパスを構築
        let path = "\(userId)/avatar.webp"
        
        do {
            // 2. ファイルの存在を確認 (任意だが推奨)
            //    Web側の実装に合わせて、listで存在確認を行う
            let files = try await supabase.storage
                .from("avatars")
                .list(path: userId, options: SearchOptions(limit: 1, search: "avatar.webp"))
            
            // ファイルが見つからなければ、URLは存在しないのでnilを返す
            guard !files.isEmpty else {
                print("🤷‍♂️ Avatar file not found at path: \(path)")
                return nil
            }
            print("✅ Avatar file found. Proceeding to get signed URL.")
            
            // 3. 署名付きURLを生成 (Web側と同じく1時間有効)
            let signedURL = try await supabase.storage
                .from("avatars")
                .createSignedURL(path: path, expiresIn: 3600)
            
            print("🔗 Successfully created signed URL: \(signedURL)")
            return signedURL
            
        } catch {
            // エラーログを出力
            print("❌ Failed to fetch avatar URL: \(error.localizedDescription)")
            
            // エラー内容をUIに表示したい場合は、ここでerrorMessageを更新しても良い
            // await MainActor.run {
            //     self.errorMessage = "アバターの取得に失敗しました。"
            // }
            
            return nil
        }
    }
    
    // MARK: - Subject Management Methods
    
    /// 新しい観測対象を登録
    func registerSubject(
        name: String,
        age: Int?,
        gender: String?,
        avatarUrl: String?,
        notes: String?,
        createdByUserId: String
    ) async throws -> String {
        print("👤 Registering new subject: \(name)")
        
        struct SubjectInsert: Codable {
            let name: String
            let age: Int?
            let gender: String?
            let avatar_url: String?
            let notes: String?
            let created_by_user_id: String
        }
        
        let subjectInsert = SubjectInsert(
            name: name,
            age: age,
            gender: gender,
            avatar_url: avatarUrl,
            notes: notes,
            created_by_user_id: createdByUserId
        )
        
        let subjects: [Subject] = try await supabase
            .from("subjects")
            .insert(subjectInsert)
            .select()
            .execute()
            .value
        
        guard let subject = subjects.first else {
            throw SupabaseDataError.noDataReturned
        }
        
        print("✅ Subject registered successfully: \(subject.subjectId)")
        return subject.subjectId
    }
    
    /// デバイスのsubject_idを更新
    func updateDeviceSubjectId(deviceId: String, subjectId: String) async throws {
        print("🔗 Updating device subject_id: \(deviceId) -> \(subjectId)")
        
        struct DeviceUpdate: Codable {
            let subject_id: String
        }
        
        let deviceUpdate = DeviceUpdate(subject_id: subjectId)
        
        try await supabase
            .from("devices")
            .update(deviceUpdate)
            .eq("device_id", value: deviceId)
            .execute()
        
        print("✅ Device subject_id updated successfully")
    }
    
    /// 観測対象を更新
    func updateSubject(
        subjectId: String,
        name: String,
        age: Int?,
        gender: String?,
        avatarUrl: String?,
        notes: String?
    ) async throws {
        print("👤 Updating subject: \(subjectId)")
        
        struct SubjectUpdate: Codable {
            let name: String
            let age: Int?
            let gender: String?
            let avatar_url: String?
            let notes: String?
            let updated_at: String
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let subjectUpdate = SubjectUpdate(
            name: name,
            age: age,
            gender: gender,
            avatar_url: avatarUrl,
            notes: notes,
            updated_at: now
        )
        
        try await supabase
            .from("subjects")
            .update(subjectUpdate)
            .eq("subject_id", value: subjectId)
            .execute()
        
        print("✅ Subject updated successfully: \(subjectId)")
    }
}

// MARK: - RPC Response Models
// RPCからのレスポンスをデコードするための構造体
struct DashboardData: Decodable {
    let vibe_report: DailyVibeReport?
    let behavior_report: BehaviorReport?
    let emotion_report: EmotionReport?
    let subject_info: Subject?
}

// MARK: - Error Types
enum SupabaseDataError: Error, LocalizedError {
    case noDataReturned
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noDataReturned:
            return "データが返されませんでした"
        case .invalidData:
            return "無効なデータです"
        }
    }
}