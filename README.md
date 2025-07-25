# iOS WatchMe v9

WatchMeプラットフォームのiOSアプリケーション（バージョン9）。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

## 🌟 主な機能

### 録音・データ収集
- **30分間隔の自動録音**: ライフログとして30分ごとに音声を自動録音
- **ストリーミングアップロード**: 大容量ファイルでも安定したアップロード
- **バックグラウンド処理**: アプリを閉じても録音・アップロードが継続

### 分析・レポート機能
- **心理グラフ (Vibe Graph)**: 日々の感情スコア、ポジティブ/ネガティブの時間分布、AIインサイトを表示
- **行動グラフ (Behavior Graph)**: 1日の行動パターンをランキングと時間帯別で可視化（v9.10.0〜）
- **感情グラフ (Emotion Graph)**: 8つの感情（Joy、Fear、Anger、Trust、Disgust、Sadness、Surprise、Anticipation）の時系列変化を折れ線グラフで表示（v9.10.0〜）

### ユーザー・デバイス管理
- **Supabase認証**: メールアドレスとパスワードによる安全な認証
- **マルチデバイス対応**: 1人のユーザーが複数のデバイスを管理可能
- **タイムゾーン対応**: ユーザーのローカルタイムゾーンでの記録管理

## 重要：ユーザーIDとデバイスIDの関係

このアプリケーションでは、ユーザーとデバイスが以下の構造で管理されています：

### 認証とID管理の流れ

1. **ユーザー認証（SupabaseAuthManager）**
   - ユーザーはメールアドレスとパスワードでログイン
   - 認証成功時にユーザーID（UUID形式）が取得される
   - 例：`user_id: "123e4567-e89b-12d3-a456-426614174000"`

2. **デバイス登録（DeviceManager）**
   - ログイン後、自動的にデバイス登録処理が実行される
   - iOSの`identifierForVendor`を使用してデバイスを識別
   - Supabaseの`devices`テーブルにデバイス情報を登録

3. **デバイスIDの紐付け**
   - `devices`テーブルで`owner_user_id`フィールドにユーザーIDが保存される
   - 一意のデバイスID（UUID形式）が生成される
   - 例：`device_id: "d067d407-cf73-4174-a9c1-d91fb60d64d0"`

### データベース構造

```sql
-- devicesテーブル
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_identifier TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL,
    platform_type TEXT NOT NULL,
    owner_user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- vibe_whisper_summaryテーブル（感情分析データ）
CREATE TABLE vibe_whisper_summary (
    device_id TEXT NOT NULL,  -- devicesテーブルのdevice_idを参照
    date DATE NOT NULL,
    vibe_scores JSONB,
    average_score DOUBLE PRECISION,
    positive_hours DOUBLE PRECISION,
    negative_hours DOUBLE PRECISION,
    neutral_hours DOUBLE PRECISION,
    insights JSONB,
    vibe_changes JSONB,
    processed_at TIMESTAMP WITH TIME ZONE,
    processing_log JSONB,
    PRIMARY KEY (device_id, date)
);
```

### 重要な注意点

- **一対多の関係**: 1人のユーザーが複数のデバイスを持つことができる
- **デバイスIDの永続性**: デバイスIDは一度生成されると変更されない
- **データの関連付け**: すべての音声データや分析結果はデバイスIDに紐付けられる
- **ユーザー削除時の考慮**: ユーザーが削除されてもデバイスデータは残る可能性がある

### ID管理の詳細

#### ユーザーIDとデバイスIDの違い

1. **ユーザーID**
   - Supabase認証で生成されるUUID
   - メールアドレスとパスワードでログインすると取得
   - 例：`164cba5a-dba6-4cbc-9b39-4eea28d98fa5`
   - 1人のユーザーに1つのID

2. **デバイスID**
   - デバイス登録時にSupabaseが自動生成するUUID
   - 例：`d067d407-cf73-4174-a9c1-d91fb60d64d0`
   - 1つのユーザーが複数のデバイスを登録可能
   - VIBEデータなど、すべての分析データはこのIDに紐付く

3. **Platform Identifier（使用しない）**
   - iOSの`identifierForVendor`から取得
   - 例：`8d17fe90-357f-41e5-98c5-e122c1185cc5`
   - デバイス登録時の識別にのみ使用
   - **これはデバイスIDではない**ので注意

#### 複数デバイスの管理

1. **デバイス選択UI**
   - ユーザーが複数デバイスを持つ場合、プルダウンで選択可能
   - 1つしかない場合は自動選択
   - 選択したデバイスのデータのみが表示される

2. **デバイス取得の流れ**
   ```swift
   // ログイン時に自動実行
   await deviceManager.fetchUserDevices(for: userId)
   
   // 取得したデバイスは以下で参照
   deviceManager.userDevices      // 全デバイスリスト
   deviceManager.selectedDeviceID // 選択中のデバイスID
   deviceManager.actualDeviceID   // 実際に使用するデバイスID
   ```

3. **データ取得時の注意**
   - 常に`selectedDeviceID`または`actualDeviceID`を使用
   - `currentDeviceID`は使用しない（過去の実装の名残）

### トラブルシューティング（ID関連）

#### デバイスが見つからない場合

1. **ユーザーに紐付くデバイスが本当に存在するか確認**
   ```sql
   SELECT * FROM devices WHERE owner_user_id = 'ユーザーID';
   ```

2. **VIBEデータが存在するか確認**
   ```sql
   SELECT * FROM vibe_whisper_summary WHERE device_id = 'デバイスID';
   ```

#### よくある間違い

- ❌ Platform Identifier（`8d17fe90...`）をデバイスIDとして使用
- ❌ `currentDeviceID`を信頼して使用
- ✅ `selectedDeviceID`または`actualDeviceID`を使用

## 技術スタック

- **Swift 5.9+**
- **SwiftUI**
- **AVFoundation** - 音声録音
- **Supabase** - 認証とデータベース
- **Combine** - リアクティブプログラミング

## セットアップ

1. **Xcodeでプロジェクトを開く**
   ```bash
   open ios_watchme_v9.xcodeproj
   ```

2. **パッケージ依存関係の解決**
   - Xcode が自動的に Swift Package Manager の依存関係を解決します
   - Supabase SDK が自動的にインストールされます

3. **ビルドと実行**
   - ターゲットデバイスを選択
   - Run (Cmd + R) でアプリを実行

## アーキテクチャ

### ディレクトリ構造
```
ios_watchme_v9/
├── ios_watchme_v9App.swift    # アプリエントリーポイント
├── ContentView.swift          # TabViewを使用したグローバルナビゲーション
├── Views/
│   ├── HomeView.swift         # 心理グラフ（Vibe Graph）表示
│   ├── RecordingView.swift    # 録音機能とファイル管理
│   ├── BehaviorGraphView.swift # 行動グラフ
│   ├── EmotionGraphView.swift  # 感情グラフ
│   ├── LoginView.swift         # ログインUI
│   └── ReportTestView.swift    # デバッグ用Vibeデータ表示
├── Managers/
│   ├── AudioRecorder.swift        # 録音管理
│   ├── NetworkManager.swift       # API通信
│   ├── DeviceManager.swift        # デバイス管理
│   ├── SupabaseAuthManager.swift  # 認証管理
│   └── SupabaseDataManager.swift  # Vibeデータ取得
├── Models/
│   ├── RecordingModel.swift       # 録音データモデル
│   ├── DailyVibeReport.swift      # Vibeレポートモデル
│   ├── DeviceModel.swift          # デバイスモデル
│   ├── BehaviorReport.swift       # 行動レポートモデル
│   └── EmotionReport.swift        # 感情レポートモデル
├── Utilities/
│   ├── SlotTimeUtility.swift      # 時刻スロット管理
│   └── ConnectionStatus.swift     # 接続状態管理
└── Info.plist                     # アプリ設定
```

### 主要コンポーネント

#### UI/ナビゲーション
1. **TabViewベースのグローバルナビゲーション**
   - 心理グラフ（Vibe Graph）
   - 行動グラフ（Behavior Graph）
   - 感情グラフ（Emotion Graph）
   - 録音

2. **疎結合アーキテクチャ**
   - 各Viewが独立した責務を持つ
   - ContentViewはナビゲーション管理に特化
   - 機能ごとに分離されたView構造

#### データ管理
1. **AudioRecorder**
   - AVAudioRecorderを使用した録音機能
   - WAVフォーマットでの保存
   - 30分間隔での自動録音

2. **NetworkManager**
   - サーバーとの通信管理
   - ストリーミング方式によるメモリ効率的なアップロード（v9.7.0〜）
   - multipart/form-dataでのファイルアップロード
   - エラーハンドリングとリトライ機能

3. **SupabaseDataManager**（v9.9.0でSingle Source of Truth実装）
   - Vibeデータの取得と管理
   - 日次レポートの取得
   - リアルタイムデータ更新
   - **一元化されたデータ管理**: `@EnvironmentObject`パターンによりアプリ全体で単一インスタンスを共有
   - **データの一貫性保証**: 全ビューが同じデータソースを参照し、状態同期を自動化

4. **認証・デバイス管理**
   - SupabaseAuthManager: ユーザー認証とセッション管理
   - DeviceManager: マルチデバイス対応とデバイス選択

#### 環境オブジェクトパターン（v9.9.0〜）
アプリケーションのデータ管理は、SwiftUIの`@EnvironmentObject`パターンを使用してSingle Source of Truthを実現：

```swift
// アプリレベルでの初期化
@main
struct ios_watchme_v9App: App {
    @StateObject private var dataManager = SupabaseDataManager()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(dataManager)  // 環境に注入
        }
    }
}

// 各ビューでの利用
struct HomeView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager  // 共有インスタンスを取得
    // ...
}
```

このアーキテクチャにより：
- **効率性**: 不要なAPIコールの削減
- **一貫性**: ビュー間でのデータ同期の自動化
- **拡張性**: 新しいグラフビューでも同じデータソースを利用可能

## API連携とデータフロー

### データの流れ
1. **音声録音** → デバイスローカルにWAV形式で保存
2. **アップロード** → API経由でS3に保存（生音声）
3. **Whisper処理** → 音声をテキストに変換
4. **感情分析** → ChatGPTで感情スコアを生成
5. **集計保存** → `vibe_whisper_summary`テーブルに日次サマリーを保存
6. **データ取得** → アプリからデバイスIDで分析結果を照会

### 心理グラフ（Vibe Graph）の実装

1. **HomeView（メインレポート画面）**
   - 日付ナビゲーション（前日/次日ボタン）
   - 平均スコアの大きな表示
   - ポジティブ/ニュートラル/ネガティブの時間分布バー
   - AIインサイトの表示
   - 時間帯別感情推移グラフ

2. **SupabaseDataManager**
   - vibe_whisper_summaryテーブルからデータ取得
   - デバイスIDと日付を指定してデータを取得
   - リアルタイムデータ更新

3. **データモデル（DailyVibeReport）**
   ```swift
   struct DailyVibeReport {
       let deviceId: String
       let date: String
       let vibeScores: [Double?]?    // 48要素（30分刻み）
       let averageScore: Double
       let positiveHours: Double
       let negativeHours: Double
       let neutralHours: Double
       let insights: [String]
       let vibeChanges: [VibeChange]?
   }
   ```

## API仕様

### アップロードエンドポイント
```
POST https://api.hey-watch.me/upload
Content-Type: multipart/form-data

Parameters:
- file: 音声ファイル (WAV形式)
- user_id: ユーザーID
- timestamp: 録音時刻 (ISO 8601形式、タイムゾーン情報付き)
  例: 2025-07-19T14:15:00+09:00
- metadata: デバイス情報とタイムスタンプを含むJSON
  {
    "device_id": "device_xxxxx",
    "recorded_at": "2025-07-19T14:15:00+09:00"
  }
```

### タイムゾーン処理

本アプリケーションは、ユーザーのローカルタイムゾーンを基準として動作します：

1. **録音時刻の記録**
   - デバイスのローカルタイムゾーンで記録
   - ISO 8601形式でタイムゾーンオフセットを含む（例：+09:00）

2. **タイムスタンプの送信**
   ```swift
   let isoFormatter = ISO8601DateFormatter()
   isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withFractionalSeconds]
   isoFormatter.timeZone = TimeZone.current  // 明示的にローカルタイムゾーンを設定
   let recordedAtString = isoFormatter.string(from: recording.date)
   ```

3. **重要な注意点**
   - `ISO8601DateFormatter`はデフォルトでUTCを使用するため、明示的に`timeZone`プロパティを設定する必要があります
   - サーバー側でもタイムゾーン情報を保持し、UTCに変換しないよう設定が必要です

## 開発時の注意点

### 1. マイク権限
- Info.plistに`NSMicrophoneUsageDescription`が必要
- 初回起動時にユーザーに権限を求める

### 2. バックグラウンド処理
- Background Modesでaudioを有効化
- アップロードはバックグラウンドでも継続

### 3. ストレージ管理
- アップロード済みファイルの定期的な削除
- ディスク容量の監視

### 4. ストリーミングアップロード仕様（v9.7.0〜）

#### 概要
従来の`Data(contentsOf:)`による一括メモリ読み込み方式から、ストリーミング方式に移行しました。これにより、ファイルサイズに関係なく安定したアップロードが可能になりました。

#### 技術仕様
1. **一時ファイル戦略**
   - multipart/form-dataのリクエストボディを一時ファイルとして構築
   - `FileManager.default.temporaryDirectory`に一時ファイルを作成
   - UUIDベースのユニークなファイル名で衝突を回避

2. **ストリーミングコピー**
   - 音声ファイルを64KB単位のチャンクで読み込み
   - FileHandleを使用したメモリ効率的なファイル操作
   - autoreleasepoolによるメモリの適切な解放

3. **URLSessionUploadTask**
   - `dataTask`から`uploadTask(with:fromFile:)`に変更
   - OSレベルでの効率的なファイルストリーミング
   - バックグラウンドでの安定した転送

4. **クリーンアップ処理**
   - アップロード完了後に一時ファイルを自動削除
   - deferブロックによる確実なリソース解放
   - エラー時も適切にクリーンアップ

#### メリット
- **メモリ効率**: ファイル全体をメモリに読み込まないため、大容量ファイルでも安定動作
- **信頼性向上**: メモリ不足によるアップロード失敗を完全に解消
- **パフォーマンス**: OSレベルの最適化により、効率的なデータ転送を実現

#### 実装例
```swift
// 一時ファイルへの書き込み
let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tmp")
let fileHandle = FileHandle(forWritingAtPath: tempFileURL.path)

// 64KBごとにストリーミングコピー
let bufferSize = 65536 // 64KB
while true {
    let chunk = audioFileHandle.readData(ofLength: bufferSize)
    if chunk.isEmpty { break }
    fileHandle.write(chunk)
}

// URLSessionUploadTaskでアップロード
let uploadTask = URLSession.shared.uploadTask(with: request, fromFile: tempFileURL) { data, response, error in
    // クリーンアップ
    defer { try? FileManager.default.removeItem(at: tempFileURL) }
    // レスポンス処理
}
```

### 5. Xcodeビルドエラーの対処

#### "Missing package product 'Supabase'" エラー

このエラーが発生した場合、以下の手順で解決できます：

1. **クリーンアップスクリプトの実行**
   ```bash
   ./reset_packages.sh
   ```

2. **Xcodeでの操作**
   - Xcodeを完全に終了
   - Xcodeを再起動してプロジェクトを開く
   - File → Packages → Reset Package Caches
   - File → Packages → Resolve Package Versions
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)

3. **それでも解決しない場合**
   - Project Navigator でプロジェクトを選択
   - Package Dependencies タブを選択
   - Supabase パッケージを削除（−ボタン）
   - +ボタンでパッケージを再追加：`https://github.com/supabase/supabase-swift`

#### "Duplicate GUID reference" エラー

プロジェクトファイルに重複した参照がある場合：

1. DerivedDataを削除
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. Xcodeキャッシュをクリア
   ```bash
   rm -rf ~/Library/Caches/com.apple.dt.Xcode
   ```

3. プロジェクトをクリーンビルド

## トラブルシューティング

### 一般的な問題

- **録音が開始されない**: マイク権限を確認
- **アップロードが失敗する**: ネットワーク接続とサーバーURLを確認
- **認証エラー**: Supabaseの設定とAPIキーを確認

### タイムゾーン関連

- **時刻がUTCで保存される**: `ISO8601DateFormatter`に明示的に`timeZone`を設定しているか確認
- **S3パスが間違った時刻になる**: サーバー側でタイムゾーン情報を保持しているか確認

### ビルドエラー

- **パッケージ依存関係エラー**: 上記の「Xcodeビルドエラーの対処」を参照
- **シミュレータでのビルドエラー**: 実機を選択するか、適切なシミュレータを選択

## デバッグ方法

### ログの確認
アプリケーションは詳細なログを出力します：
- 🚀 アップロード開始
- ✅ アップロード成功
- ❌ エラー発生
- 📊 タイムゾーン情報
- 🔍 デバイスID確認
- 📱 デバイス登録状態

### ネットワーク通信の確認
Xcodeのネットワークデバッガーを使用して、送信されるリクエストの内容を確認できます。

### データベースクエリの確認
VIBEデータが見つからない場合の確認手順：

1. **現在のデバイスIDを確認**
   ```swift
   print("Current Device ID: \(deviceManager.currentDeviceID)")
   ```

2. **Supabaseでデータ存在確認**
   ```sql
   -- デバイスの確認
   SELECT * FROM devices WHERE owner_user_id = 'ユーザーID';
   
   -- VIBEデータの確認
   SELECT * FROM vibe_whisper_summary WHERE device_id = 'デバイスID';
   ```

3. **日付フォーマットの確認**
   - 日付は`YYYY-MM-DD`形式で保存される
   - タイムゾーンは考慮されない（日付のみ）

## Git 運用ルール（ブランチベース開発フロー）

このプロジェクトでは、**ブランチベースの開発フロー**を採用しています。  
main ブランチで直接開発せず、以下のルールに従って作業を進めてください。

---

### 🔹 運用ルール概要

1. `main` ブランチは常に安定した状態を保ちます（リリース可能な状態）。
2. 開発作業はすべて **`feature/xxx` ブランチ** で行ってください。
3. 作業が完了したら、GitHub上で Pull Request（PR）を作成し、差分を確認した上で `main` にマージしてください。
4. **1人開発の場合でも、必ずPRを経由して `main` にマージしてください**（レビューは不要、自分で確認＆マージOK）。

---

### 🔧 ブランチ運用の手順

#### 1. `main` を最新化して作業ブランチを作成
```bash
git checkout main
git pull origin main
git checkout -b feature/機能名
```

#### 2. 作業内容をコミット
```bash
git add .
git commit -m "変更内容の説明"
```

#### 3. リモートにプッシュしてPR作成
```bash
git push origin feature/機能名
# GitHub上でPull Requestを作成
```

## 更新履歴

### 2025年7月27日
- **v9.10.0 - 行動グラフと感情グラフの実装**
  - **行動グラフ (Behavior Graph) の実装**
    - behavior_summaryテーブルからのデータ取得機能
    - 1日の行動ランキング表示（上位5件）
    - 48個の時間ブロック（30分単位）での行動可視化
    - 時間帯別の色分け表示（深夜・朝・昼・夕方・夜）
    - タップで各時間帯の詳細表示
  
  - **感情グラフ (Emotion Graph) の実装**
    - emotion_opensmile_summaryテーブルからのデータ取得機能
    - 8つの感情の1日の合計値をランキング表示
    - 48時間帯の感情推移を折れ線グラフで表示
    - Charts frameworkを使用した美しいグラフ描画
    - 各感情の表示/非表示切り替え機能
    - 凡例の表示/非表示機能
  
  - **データモデルの追加**
    - BehaviorReport.swift: 行動データモデル
    - EmotionReport.swift: 感情データモデル（8感情対応）
  
  - **SupabaseDataManagerの拡張**
    - fetchBehaviorReport()メソッドの追加
    - fetchEmotionReport()メソッドの追加
    - 既存の認証・デバイス管理機能との統合

### 2025年7月25日
- **v9.9.0 - データ管理の一元化リファクタリング**
  - **Single Source of Truthの実現**
    - `SupabaseDataManager`を`@EnvironmentObject`パターンで一元管理
    - `ios_watchme_v9App.swift`でアプリレベルでの初期化を実装
    - `HomeView`の`@StateObject`を`@EnvironmentObject`に移行
  
  - **アーキテクチャの改善**
    - データの一貫性保証：全ビューが同じデータソースを参照
    - 効率性向上：不要なAPIコールとインスタンス生成を削減
    - スケーラビリティ：新しいグラフビューでも同じデータソースを利用可能
  
  - **今後の拡張に向けた基盤整備**
    - 行動グラフ・感情グラフ実装時のデータ共有基盤を確立
    - ビュー間での状態同期の自動化を実現

- **v9.8.0 - UI/UXの大幅改善と疎結合アーキテクチャの導入**
  - **TabViewベースのグローバルナビゲーション導入**
    - 「心理グラフ」「行動グラフ」「感情グラフ」「録音」の4タブ構成
    - 各機能への直感的なアクセスを実現
  
  - **疎結合アーキテクチャへのリファクタリング**
    - ContentViewから機能を分離
    - RecordingView: 録音機能を独立したViewに
    - HomeView: 心理グラフ表示専用Viewに
    - BehaviorGraphView/EmotionGraphView: 将来機能用プレースホルダー
  
  - **心理グラフ（Vibe Graph）のUI完全リニューアル**
    - タブ選択時に即座にレポートを表示
    - 日付ナビゲーション（前日/次日）を追加
    - 平均スコアの大きな表示と視覚的な感情アイコン
    - 感情の時間分布をプログレスバーで表現
    - 時間帯別グラフを簡易バーチャートで実装
  
  - **不要な機能の削除**
    - サーバー接続テストボタンを削除
    - 「開発・テスト用機能」フッターを削除
    - 接続ステータス表示を削除

### 2025年7月24日
- **v9.7.0 - アップロード安定化とUI改善**
  - **ストリーミングアップロード方式への移行**
    - NetworkManager.swiftの`uploadRecording`メソッドを全面改修
    - 従来の`Data(contentsOf:)`による一括メモリ読み込みを廃止し、メモリ不足によるアップロード失敗を根本解決
    - 一時ファイル戦略の採用：
      - multipart/form-dataリクエストボディを一時ファイルとして構築
      - FileHandleを使用した効率的なファイル操作
      - 64KB単位のチャンクでストリーミングコピー
    - URLSessionUploadTaskによるOSレベルの最適化：
      - `dataTask`から`uploadTask(with:fromFile:)`に変更
      - バックグラウンドでの安定した転送を実現
    - 確実なリソース管理：
      - deferブロックによる一時ファイルの自動削除
      - エラー時も適切なクリーンアップを保証
    - 結果：大容量ファイルでも安定したアップロードが可能に
  
  - **UI簡素化**
    - RecordingRowViewから個別アップロードボタンを削除
    - 一括アップロード機能に統一してユーザー体験を向上
    - 不要なnetworkManagerプロパティを削除しコードを整理

- **v9.6.0 - スロット切り替え録音の安定化**
  - **performSlotSwitch()の問題解決**
    - Thread.sleepとasyncAfterを除去してメインスレッドブロッキングを解消
    - AVAudioRecorderDelegateを活用した堅牢な非同期処理を実装
    - ファイル保存完了を確実に待ってから次の処理を実行
  - **録音ファイル保存の問題修正**
    - cleanup()タイミングの最適化でcurrentSlotStartTimeが消去される問題を解決
    - 責務の分離によりhandleRecordingCompletion()とスロット切り替え処理を分離
  - **スロット名計算の修正**
    - getCurrentSlot()の代わりにgetNextSlotStartTime()を使用
    - スロット境界での正確な時刻計算により同一ファイル名の上書きを防止
    - 30分をまたぐ録音で複数ファイルが正常に保存されることを確認
  - **デバッグ機能強化**
    - スロット切り替えプロセスの詳細ログを追加
    - pendingSlotSwitchとcurrentSlotStartTimeの状態追跡
    - 同一ファイル名検出時の警告メッセージ

- **コードクリーンアップ**
  - UploadManager.swiftの削除（未使用の古いコード）
  - ContentView.swiftのコメントアウトされた古いコードの削除
  - AudioRecorder.swiftのpendingRecordings冗長プロパティの削除
  - アップロード処理をNetworkManagerに一元化

### 2025年7月19日
- **タイムゾーン処理の改善**
  - `ISO8601DateFormatter`に明示的な`timeZone`設定を追加
  - ローカルタイムゾーンでのタイムスタンプ送信を実装
  - Vault APIとの連携でタイムゾーン情報を保持

### 2025年7月12日
- **v9.5.0 - アップロードシステム安定化リファクタリング**
  - UploadManagerキューシステムの無効化
  - 逐次アップロード機能の実装
  - 完了ハンドラ対応

### 2025年7月9日
- **v9.4.1 - ファイル保存構造変更**
  - ローカルファイル保存構造の階層化
  - アップロードパスにrawディレクトリ追加

## ライセンス

プロプライエタリ