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

#### ⚠️ 重要: RPC関数の実装について
**このアプリケーションの正常動作には、Supabase側で`get_dashboard_data` RPC関数が正しく実装されている必要があります。**

1. **統合データ取得関数 `get_dashboard_data`**
   - 単一のRPC呼び出しで全グラフデータを取得
   - vibe_whisper_summary、behavior_summary、emotion_opensmile_summary、subjectsの4テーブルを一括取得
   - ネットワークリクエストが5回以上から1回に削減
   - **パラメータ**:
     - `p_device_id`: デバイスID（TEXT型、UUID形式）
     - `p_date`: 日付（TEXT型、YYYY-MM-DD形式）
   - **戻り値**: DashboardData型の配列（各テーブルのデータを含む）

#### 📝 必須: RPC関数の正しい実装

Supabaseの SQL Editor で以下のクエリを実行して、RPC関数を作成してください：

```sql
CREATE OR REPLACE FUNCTION get_dashboard_data(
    p_device_id TEXT,
    p_date TEXT
)
RETURNS TABLE (
    vibe_report JSONB,
    behavior_report JSONB,
    emotion_report JSONB,
    subject_info JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- 日付での絞り込み条件を含める（重要！）
        (SELECT to_jsonb(t) FROM vibe_whisper_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS vibe_report,
        
        (SELECT to_jsonb(t) FROM behavior_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS behavior_report,
        
        (SELECT to_jsonb(t) FROM emotion_opensmile_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS emotion_report,
        
        -- subject_infoは日付に関係ないのでdevice_idのみで検索
        (SELECT to_jsonb(s) FROM subjects s
         JOIN devices d ON s.subject_id = d.subject_id
         WHERE d.device_id = p_device_id::uuid 
         LIMIT 1) AS subject_info;
END;
$$;
```

**⚠️ 注意事項:**
- 各テーブルのクエリで `AND t.date = p_date::date` の条件が必須です
- この条件がないと、すべての日付で同じデータが表示される不具合が発生します
- `p_date`パラメータは`TEXT`型で受け取り、`::date`でキャストして使用します

2. **SupabaseDataManagerの実装**
   ```swift
   // RPCを使った高速データ取得
   func fetchAllReports(deviceId: String, date: Date) async {
       let params = ["p_device_id": deviceId, "p_date": dateString]
       let response: [DashboardData] = try await supabase.rpc("get_dashboard_data", params: params).execute().value
   }
   ```

3. **DashboardData構造体**
   ```swift
   struct DashboardData: Decodable {
       let vibe_report: DailyVibeReport?       // vibe_whisper_summaryテーブルのデータ
       let behavior_report: BehaviorReport?     // behavior_summaryテーブルのデータ
       let emotion_report: EmotionReport?       // emotion_opensmile_summaryテーブルのデータ
       let subject_info: Subject?               // subjectsテーブルのデータ
   }
   ```

4. **パフォーマンスへの影響**
   - ダッシュボード表示の遅延を大幅に短縮
   - データの一貫性を保証（全データが同じタイミングで取得）
   - ネットワーク通信の効率化によりバッテリー消費も改善

#### 🔍 トラブルシューティング: すべての日付で同じデータが表示される場合

もし異なる日付を選択しても同じデータが表示される場合は、以下を確認してください：

1. **RPC関数の実装確認**
   - `get_dashboard_data`関数が`p_date`パラメータを正しく処理しているか
   - WHERE句で日付フィルタリングが適用されているか
   - 日付比較が正しい形式（YYYY-MM-DD）で行われているか

2. **データベースの確認**
   - 各テーブルに異なる日付のデータが存在するか
   - 日付カラムが正しい形式で保存されているか

3. **デバッグ方法**
   - Xcodeのコンソールで送信されているパラメータを確認
   - Supabaseのダッシュボードで直接RPC関数をテスト
   - 各テーブルのデータを個別に確認

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

詳細な更新履歴は [`CHANGELOG.md`](./CHANGELOG.md) を参照してください。

## ライセンス

プロプライエタリ