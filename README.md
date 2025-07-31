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
- **明示的なデバイス連携**: ユーザーが手動でデバイスを連携（v9.13.0〜）
- **QRコードによるデバイス追加**: QRコードスキャンで簡単にデバイスを追加（v9.15.0〜）
  - デバイス選択画面からカメラでQRコードをスキャン
  - QRコード内容はシンプルにdevice_idのみ（UUID形式）
  - デバイスIDの妥当性検証とデータベース存在確認
  - 成功・失敗時のポップアップフィードバック
  - デフォルト権限は「owner」で追加
- **タイムゾーン対応**: ユーザーのローカルタイムゾーンでの記録管理

## 重要：ユーザーIDとデバイスIDの関係

このアプリケーションでは、ユーザーとデバイスが以下の構造で管理されています：

### 認証とID管理の流れ

1. **ユーザー認証（SupabaseAuthManager）**
   - ユーザーはメールアドレスとパスワードでログイン
   - 認証成功時にユーザーID（UUID形式）が取得される
   - 例：`user_id: "123e4567-e89b-12d3-a456-426614174000"`

2. **デバイス連携（DeviceManager）**（v9.13.0で変更）
   - ユーザーが明示的に操作した場合のみデバイスを連携
   - ユーザー情報画面から「このデバイスを連携」ボタンで連携可能
   - iOSの`identifierForVendor`を使用してデバイスを識別
   - Supabaseの`devices`テーブルにデバイス情報を登録

3. **デバイスIDの紐付け**
   - `devices`テーブルで`owner_user_id`フィールドにユーザーIDが保存される
   - 一意のデバイスID（UUID形式）が生成される
   - 例：`device_id: "d067d407-cf73-4174-a9c1-d91fb60d64d0"`

### データベース構造（v9.14.0で更新）

```sql
-- devicesテーブル
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_identifier TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL,
    platform_type TEXT NOT NULL,
    owner_user_id UUID REFERENCES auth.users(id),  -- 廃止予定
    subject_id UUID REFERENCES subjects(subject_id),  -- v9.14.0で追加
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- user_devicesテーブル（新規追加）
CREATE TABLE user_devices (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner', 'viewer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, device_id)
);

-- subjectsテーブル（v9.14.0で追加）
CREATE TABLE subjects (
    subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    age INTEGER,
    gender TEXT,
    avatar_url TEXT,
    notes TEXT,
    created_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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

#### RLS（Row Level Security）の重要性

**user_devicesテーブルには必ずRLSポリシーを設定してください：**

```sql
-- RLSを有効化
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のレコードのみアクセス可能
CREATE POLICY "Users can view their own device associations" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own device associations" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);
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

3. **Platform Identifier（内部使用のみ）**
   - iOSの`identifierForVendor`から取得
   - 例：`8d17fe90-357f-41e5-98c5-e122c1185cc5`
   - デバイス登録時の識別にのみ使用
   - **これはデバイスIDではない**ので注意

#### DeviceManagerで管理されるIDプロパティ

DeviceManagerは以下の3つの主要なプロパティでデバイス情報を管理しています：

1. **`localDeviceIdentifier: String?`**
   - **役割**: このアプリが動作している物理デバイス自身のID
   - Supabaseに登録されたこのデバイスのユニークな識別子
   - UserDefaultsに永続的に保存される
   - 主に、このデバイスから音声データをアップロードする際に使用

2. **`userDevices: [Device]`**
   - **役割**: 現在ログインしているユーザーに紐付けられている全てのデバイスのリスト
   - ユーザーが複数のデバイスを管理できるという要件を満たすために必須

3. **`selectedDeviceID: String?`**
   - **役割**: 現在アプリケーションのUI上でデータ閲覧のために選択されているデバイスのID
   - グラフ表示など、どのデバイスのデータを見ているかを制御する主要なID
   - userDevicesから選択されるか、デバイスが1つしかない場合は自動設定
   - ユーザーに紐づくデバイスがない場合は、localDeviceIdentifierがデフォルトとして使用される

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
   deviceManager.userDevices          // 全デバイスリスト
   deviceManager.selectedDeviceID     // 選択中のデバイスID
   deviceManager.localDeviceIdentifier // この物理デバイス自身のID
   ```

3. **データ取得時の注意**
   - 通常は`selectedDeviceID`を使用
   - `selectedDeviceID`がnilの場合は`localDeviceIdentifier`をフォールバックとして使用

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
- ❌ 過去の実装の名残である古いプロパティ名を使用
- ✅ `selectedDeviceID`を使用（UI上で選択されたデバイス）
- ✅ `localDeviceIdentifier`を使用（この物理デバイス自身のID）

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
├── ios_watchme_v9App.swift        # アプリエントリーポイント
├── ContentView.swift              # 日付選択とTabViewを使用したグローバルナビゲーション
├── HomeView.swift                 # 心理グラフ（Vibe Graph）表示
├── BehaviorGraphView.swift        # 行動グラフ
├── EmotionGraphView.swift         # 感情グラフ
├── RecordingView.swift            # 録音機能とファイル管理
├── LoginView.swift                # ログインUI
├── ReportTestView.swift           # デバッグ用Vibeデータ表示
├── AudioRecorder.swift            # 録音管理
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── SupabaseAuthManager.swift      # 認証管理
├── SupabaseDataManager.swift      # 統合データ管理
├── Models/
│   ├── BehaviorReport.swift       # 行動レポートモデル
│   └── EmotionReport.swift        # 感情レポートモデル
├── DailyVibeReport.swift          # Vibeレポートモデル
├── RecordingModel.swift           # 録音データモデル
├── SlotTimeUtility.swift          # 時刻スロット管理
├── ConnectionStatus.swift         # 接続状態管理
├── UploadUIUpdateTest.swift       # アップロードUIテスト
├── Assets.xcassets/               # アプリアイコンとカラーセット
└── Info.plist                     # アプリ設定
```

### 主要コンポーネント

#### UI/ナビゲーション（v9.11.0で階層構造化）
1. **「デバイス → 日付 → グラフ」階層構造**
   - **最上位階層**: ContentViewでデバイスと日付を一元管理
   - **固定ヘッダー**: デバイス選択ボタンとユーザー情報ボタンを配置
   - **日付ナビゲーション**: TabViewの上に配置され、全グラフで共有（前日/次日ボタンと日付表示）
   - **タブ構成**: 心理グラフ、行動グラフ、感情グラフ、録音

2. **統合データフロー**
   - デバイスまたは日付の変更時に、全グラフのデータを一括取得
   - 各グラフビューは個別のデータ取得を行わず、SupabaseDataManagerの`@Published`プロパティを参照
   - データの一貫性と効率性を保証

3. **疎結合アーキテクチャ**
   - 各Viewが独立した責務を持つ
   - ContentViewは日付・デバイス選択とデータフロー制御に特化
   - 各グラフビューは表示に特化し、データフェッチは行わない
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

3. **SupabaseDataManager**（v9.11.0で統合データ管理を実装）
   - **統合データ取得**: `fetchAllReports`メソッドで全グラフデータを並行取得
   - **Published プロパティ**:
     - `dailyReport`: 心理グラフ用データ
     - `dailyBehaviorReport`: 行動グラフ用データ
     - `dailyEmotionReport`: 感情グラフ用データ
   - **一元化されたデータ管理**: `@EnvironmentObject`パターンによりアプリ全体で単一インスタンスを共有
   - **データの一貫性保証**: 全ビューが同じデータソースを参照し、状態同期を自動化
   - **Swift 6対応**: TaskブロックとMainActor.runに`[weak self]`を追加

4. **認証・デバイス管理**
   - SupabaseAuthManager: ユーザー認証とセッション管理
   - DeviceManager: デバイス連携管理とデバイス選択（手動連携方式）

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

### 高速データ取得（RPC実装）

本アプリケーションは、Supabaseのデータベース関数（RPC）を使用して、複数テーブルからのデータ取得を最適化しています。

1. **統合データ取得関数 `get_dashboard_data`**
   - 単一のRPC呼び出しで全グラフデータを取得
   - vibe_whisper_summary、behavior_summary、emotion_opensmile_summary、subjectsの4テーブルを一括取得
   - ネットワークリクエストが5回以上から1回に削減

2. **SupabaseDataManagerの実装**
   ```swift
   // RPCを使った高速データ取得
   func fetchAllReports(deviceId: String, date: Date) async {
       let params = ["p_device_id": deviceId, "p_date": dateString]
       let response: [DashboardData] = try await supabase.rpc("get_dashboard_data", params: params).execute().value
   }
   ```

3. **パフォーマンスへの影響**
   - ダッシュボード表示の遅延を大幅に短縮
   - データの一貫性を保証（全データが同じタイミングで取得）
   - ネットワーク通信の効率化によりバッテリー消費も改善

### 心理グラフ（Vibe Graph）の実装

1. **HomeView（メインレポート画面）**
   - 日付ナビゲーション（前日/次日ボタン）
   - 平均スコアの大きな表示
   - ポジティブ/ニュートラル/ネガティブの時間分布バー
   - AIインサイトの表示
   - 時間帯別感情推移グラフ

2. **SupabaseDataManager**
   - RPC関数経由でvibe_whisper_summaryテーブルからデータ取得
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

### 1. Supabase認証の重要事項 🚨

#### ❌ やってはいけないこと
```swift
// ⚠️ 手動でAPIを呼び出さない！
URLSession.shared.dataTask(with: "supabaseURL/auth/v1/token") { ... }
URLSession.shared.dataTask(with: "supabaseURL/rest/v1/table") { ... }
```

#### ✅ 正しい実装
```swift
// 🔐 認証: Supabase SDKの標準メソッドを使用
let session = try await supabase.auth.signIn(email: email, password: password)

// 📊 データ取得: SDKのクエリビルダーを使用
let data: [MyModel] = try await supabase
    .from("table_name")
    .select()
    .eq("column", value: "value")
    .execute()
    .value
```

#### 🔍 認証情報不整合問題の解決（v9.12.1で修正済み）
- **問題**: 手動API呼び出しではRLSポリシーを通過できない
- **解決**: 全てのデータアクセスをSDK標準メソッドに統一
- **効果**: 認証状態とデータアクセスの完全な整合性を実現

#### 認証状態の復元（アプリ再起動時）
```swift
// 保存されたトークンでセッションを復元
_ = try await supabase.auth.setSession(
    accessToken: savedUser.accessToken,
    refreshToken: savedUser.refreshToken
)
```

#### グローバルSupabaseクライアントの使用
```swift
// SupabaseAuthManager.swiftで定義されているグローバルインスタンスを使用
let supabase = SupabaseClient(...)  // グローバル定義

// 各クラスで独自のクライアントを作成しない！
// ❌ self.supabase = SupabaseClient(...)  // これはNG
```

### 2. RLS（Row Level Security）の設定

新しいテーブルを作成する際は、必ずRLSポリシーを設定してください：

1. **RLSを有効化**
2. **適切なポリシーを設定**（認証ユーザーのみアクセス可能など）
3. **テストユーザーでアクセス確認**

### 3. デバイス管理の新アーキテクチャ（v9.13.0〜）

- **手動デバイス連携方式**：
  - ログイン時の自動デバイス登録を廃止
  - ユーザー情報画面から「このデバイスを連携」ボタンで手動連携
  - デバイス未連携時は「デバイス連携: なし」と表示
- **user_devicesテーブル**を経由してデバイスを管理
- ユーザーは複数デバイスを持てる（owner/viewerロール付き）
- `DeviceManager.fetchUserDevices`は以下の流れ：
  1. user_devicesテーブルからユーザーのデバイス一覧を取得
  2. devicesテーブルから詳細情報を取得
  3. role情報を付与してUIに反映

### 4. マイク権限
- Info.plistに`NSMicrophoneUsageDescription`が必要
- 初回起動時にユーザーに権限を求める

### 5. バックグラウンド処理
- Background Modesでaudioを有効化
- アップロードはバックグラウンドでも継続

### 6. ストレージ管理
- アップロード済みファイルの定期的な削除
- ディスク容量の監視

### 7. ストリーミングアップロード仕様（v9.7.0〜）

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

### 認証・データアクセスの問題

#### デバイスデータが取得できない場合

1. **認証状態の確認**
   ```swift
   // DeviceManagerのログで確認
   "✅ 認証済みユーザー: [ID]" または "❌ 認証されていません"
   ```

2. **RLSポリシーの確認**
   - user_devicesテーブルにRLSが有効か確認
   - 適切なポリシーが設定されているか確認

3. **一度ログアウトして再ログイン**
   - 古い認証情報が残っている可能性
   - 新しい認証フローで問題解決

#### "Decoded user_devices count: 0"エラー

**原因**: 認証トークンが正しく設定されていない
**解決策**: 
1. SupabaseAuthManagerが標準のSDKメソッドを使用しているか確認
2. DeviceManagerがグローバルsupabaseクライアントを使用しているか確認
3. checkAuthStatusでセッション復元が正しく行われているか確認

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

### 2025年7月31日
- **v9.16.0 - アバター機能の実装（ペンディング）**
  - **⚠️ 現在ペンディング状態 ⚠️**
    - アバターアップロード専用APIの実装待ち
    - APIエンドポイントが提供され次第、実装を更新予定
    - 現在はローカルファイルシステムに保存する暫定実装
    
  - **実装した機能**
    - UserアバターとSubjectアバターの画像選択・編集機能
    - 共通のアバター選択コンポーネント（AvatarPickerView）
    - PHPickerViewControllerを使用した写真ライブラリからの選択
    - カメラ撮影機能（UIImagePickerController）
    - 画像トリミング機能（300x300の正方形）
    
  - **暫定実装の詳細**
    - 画像はDocumentsディレクトリに保存
    - パス形式: `Documents/{type}/{id}/avatar.jpg`
    - typeは "users" または "subjects"
    - JPEG形式、品質80%で保存
    
  - **API実装後の想定仕様**
    - エンドポイント: `POST /api/avatar/upload`
    - リクエスト: multipart/form-data
      - file: 画像ファイル
      - type: "users" or "subjects"
      - id: ユーザーIDまたはサブジェクトID
    - レスポンス: `{ url: "https://..." }`
    - アップロード後はS3のURLを使用してアバターを表示
    
  - **実装ファイル**
    - `AWSManager.swift`: アバターアップロード管理（ペンディング実装）
    - `AvatarPickerView.swift`: 共通の画像選択・編集コンポーネント
    - `ContentView.swift`: UserアバターのUI実装
    - `SubjectRegistrationView.swift`: Subjectアバターの実装
    - `DashboardView.swift`: Subjectアバター表示の更新

- **v9.15.0 - QRコードによるデバイス追加機能の実装**
  - **QRコードスキャン機能**
    - デバイス選択画面に「デバイスを追加」ボタンを追加
    - カメラを使用したQRコードのリアルタイムスキャン機能
    - QRコード内容はシンプルにdevice_idのみ（UUID形式のテキスト）
    - AVFoundationを活用したカメラベースのスキャナーを実装
    - カメラ使用許可（NSCameraUsageDescription）をInfo.plistに設定
    
  - **デバイス追加処理の安全性**
    - UUIDフォーマットの妥当性検証
    - データベース内のデバイス存在確認
    - 既に追加済みデバイスの重複チェック
    - user_devicesテーブルへの安全な追加処理
    
  - **ユーザーフィードバック機能**
    - 成功時：「device_id: xxxxx... が閲覧可能になりました！」ポップアップ
    - 失敗時：エラー内容別の詳細メッセージ表示
    - 無効なQRコード、既に追加済み、デバイス未登録などのケース別対応
    
  - **権限管理の改善**
    - デフォルト権限を「viewer」から「owner」に変更
    - QRコードで追加したデバイスは即座にフル機能で利用可能
    
  - **実装ファイル**
    - `QRCodeScannerView.swift`: カメラベースのQRスキャナー
    - `DeviceSelectionView.swift`: デバイス選択UIと追加機能
    - `DeviceManager.swift`: QRコードデバイス追加ロジック
    - `Info.plist`: カメラ使用許可の設定

### 2025年7月30日
- **v9.14.0 - 観測対象管理をsubjectsテーブルに移行**
  - **データベース構造の変更**
    - 新規`subjects`テーブルを追加（観測対象の情報を独立して管理）
    - `devices`テーブルに`subject_id`フィールドを追加
    - `device_metadata`テーブルの参照を`subjects`テーブルに変更（device_metadataは今後削除予定）
    
  - **観測対象管理の改善**
    - 観測対象（subjects）をデバイスから独立して管理
    - 1つのデバイスに1つの観測対象を紐付け
    - 複数のデバイスが同じ観測対象を参照可能（デバイス買い替え時などに対応）
    
  - **アプリケーションの変更**
    - `DeviceMetadata`モデルを`Subject`モデルに置き換え
    - `SupabaseDataManager`の`fetchDeviceMetadata`を`fetchSubjectForDevice`に変更
    - デバイスに観測対象が未登録の場合の表示を実装
    
  - **今後の拡張予定**
    - 観測対象の登録・編集機能の追加
    - 観測対象の切り替え機能の実装

### 2025年7月30日
- **v9.13.1 - デバイス未連携時の録音制御機能を実装**
  - **録音開始時のデバイス連携チェック機能**
    - デバイス未連携の状態で録音開始ボタンを押すと、デバイス連携を促すダイアログを表示
    - 「デバイスが連携されていないため録音できません。このデバイスを連携しますか？」というメッセージで確認
    - 「はい」を選択すると、デバイス連携処理を実行し、成功後に自動的に録音を開始
    - 「キャンセル」を選択すると、録音は開始されない
    
  - **UI/UXの改善点**
    - デバイス連携中は画面全体にオーバーレイを表示し、進行状況を明示
    - 連携成功後は自動的に録音が開始されるため、ユーザーの手間を削減
    - エラー時は適切なエラーメッセージを表示
    
  - **技術的な実装**
    - RecordingViewに`showDeviceLinkAlert`と`isLinkingDevice`の状態管理を追加
    - `linkDeviceAndStartRecording()`メソッドでデバイス連携と録音開始を連続実行
    - デバイスIDなしでアップロードされる無効な録音データを防止
    
  - **グラフ表示のエラーメッセージ共通化**
    - `GraphEmptyStateView`コンポーネントを作成し、エラー表示ロジックを一元化
    - デバイス未連携時：「デバイスが連携されていません」（オレンジ色のアイコン）
    - データなし時：「指定した日付のデータがありません」（グレー色のアイコン）
    - 全グラフビュー（心理、行動、感情、ダッシュボード）で統一された表示

- **v9.13.0 - ログイン時のデバイス自動登録機能を削除**
  - **デバイス登録の仕様変更**
    - ログイン時の自動デバイス登録を完全に削除
    - ユーザーが明示的に操作した場合のみデバイス登録を行うように変更
    - 録音ボタン押下時にデバイス未登録の場合は登録を促すUIを実装（v9.13.1で実装済み）
    
  - **コード変更の詳細**
    - `SupabaseAuthManager`から`checkAndRegisterDevice`の呼び出しを削除
    - 代わりに`fetchUserDevices`のみを呼び出し、既存のデバイス一覧を取得
    - `DeviceManager.checkAndRegisterDevice`関数を完全に削除
    - `DeviceManager.registerDevice`のuserIdパラメータを必須に変更
    
  - **影響と注意点**
    - 新規ユーザーはログイン後、デバイスが未登録の状態となる
    - デバイス未登録の場合、録音のアップロードは失敗する（既存の仕様通り）
    - 既存ユーザーには影響なし（すでに登録済みのデバイスはそのまま使用可能）
    
  - **UI改善**
    - ユーザー情報画面にデバイス連携状態を表示
    - デバイス未連携時は「デバイスが連携されていません」と表示
    - 「このデバイスを連携」ボタンで簡単に連携可能
    - ホーム画面左上にデバイス連携状態を表示（「デバイス連携: なし」）

### 2025年7月29日
- **v9.12.1 - 手動API呼び出しからSDK標準メソッド化による認証情報不整合問題の根本解決**
  - **SupabaseAuthManagerの完全SDK化**
    - signUpメソッドを`supabase.auth.signUp()`に変更
    - signOutメソッドを`supabase.auth.signOut()`に変更
    - fetchUserInfoメソッドを`supabase.auth.session.user`に変更
    - resendConfirmationEmailメソッドを`supabase.auth.resend()`に変更
    - fetchUserProfileメソッドを`supabase.from("users").select()`に変更
    - refreshTokenメソッドを削除（SDKが自動管理）
    
  - **SupabaseDataManagerの完全SDK化**
    - fetchDailyReportメソッドを`supabase.from("vibe_whisper_summary").select()`に変更
    - fetchBehaviorReportメソッドを`supabase.from("behavior_summary").select()`に変更
    - fetchEmotionReportメソッドを`supabase.from("emotion_opensmile_summary").select()`に変更
    - fetchDeviceMetadataメソッドを`supabase.from("device_metadata").select()`に変更（v9.14.0で`fetchSubjectForDevice`に変更）
    - fetchWeeklyReportsメソッドを`supabase.from("vibe_whisper_summary").select()`に変更
    
  - **認証情報の不整合問題を根本解決**
    - 手動のURLSession API呼び出しを完全に排除
    - SDKが自動的に認証トークンを管理し、RLSポリシーを正しく通過
    - PostgrestErrorの詳細表示機能を追加してデバッグを改善
    - トークンの自動リフレッシュによる堅牢なセッション管理

- **v9.12.0 - user_devicesテーブル対応と認証フロー修正**
  - **データベース構造の変更**
    - `user_devices`中間テーブルに対応
    - ユーザーとデバイスの多対多関係を実現
    - owner/viewerロールによる権限管理
    
  - **認証フローの根本的修正**
    - SupabaseAuthManagerの`signIn`を標準SDKメソッドに変更
    - 手動のAPI呼び出しを廃止し、`supabase.auth.signIn()`を使用
    - 認証トークンの自動管理を実現
    
  - **認証状態復元の実装**
    - `checkAuthStatus`で`supabase.auth.setSession()`を呼び出し
    - アプリ再起動時も認証状態を正しく維持
    
  - **DeviceManagerの改修**
    - 独自のSupabaseクライアント初期化を削除
    - グローバルな認証済みクライアントを使用
    - `fetchUserDevices`をuser_devices経由に変更
    
  - **トラブルシューティング情報追加**
    - RLSポリシーの重要性を強調
    - 認証関連の問題解決方法を詳細化

### 2025年7月27日（追加修正）
- **v9.11.1 - 日付選択機能の最終調整とコード整理**
  - **HomeView.swiftの修正**
    - 不要な`showUserInfoSheet`への参照を削除
    - 個別のデータフェッチロジックを削除し、ContentViewで管理されるデータフローに統一
    - toolbarからユーザーアイコンボタンを削除（ContentViewのヘッダーに集約）
    
  - **ディレクトリ構造の正確化**
    - README.mdのディレクトリ構造を実際のファイル配置に合わせて修正
    - ManagersディレクトリとViewsディレクトリは存在せず、全ファイルがルート直下に配置
    - ContentView.swiftの説明を「日付選択とTabViewを使用したグローバルナビゲーション」に更新
    
  - **DailyVibeReport.swiftの確認**
    - scoreColorとemotionIconメソッドが既に実装済みであることを確認
    - 各グラフビューがエクステンションメソッドを正しく使用していることを確認
    
  - **グラフビューの確認**
    - BehaviorGraphViewとEmotionGraphViewは既に日付ナビゲーションUIが削除済み
    - dataManagerから直接データを参照する実装になっていることを確認

### 2025年7月27日
- **v9.11.0 - データフロー階層構造への大規模リファクタリング**
  - **「デバイス → 日付 → グラフ」階層構造の実装**
    - ライフログツールとして最適なUI階層を実現
    - デバイスと日付の選択を最上位（ContentView）に集約
    - すべてのグラフが同一のデバイス・日付のデータを表示
    
  - **統合データ管理の実現**
    - `ContentView`に`selectedDate`の状態管理を一元化
    - 固定ヘッダー（ユーザーアイコンとアプリタイトル）の実装
    - 日付ナビゲーションをTabViewの上に配置し、全グラフで共有
    - デバイスまたは日付変更時に、すべてのレポートを自動的に再取得
    
  - **SupabaseDataManagerの拡張**
    - `dailyBehaviorReport`と`dailyEmotionReport`の`@Published`プロパティを追加
    - `fetchAllReports`メソッドで3つのレポートを並行取得
    - Swift 6対応: TaskブロックとMainActor.runに`[weak self]`を追加
    
  - **各グラフビューの簡素化**
    - HomeView、BehaviorGraphView、EmotionGraphViewから日付ナビゲーションUIを削除
    - 個別のデータフェッチロジックを削除
    - SupabaseDataManagerの`@Published`プロパティを直接参照する設計に変更
    
  - **コード品質の向上**
    - ContentViewのbodyを簡素化（AppHeaderView、DateNavigationViewに分割）
    - `scoreColor`と`emotionIcon`をDailyVibeReportのエクステンションに移動
    - 冗長なコードの削除とエラー処理の改善

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