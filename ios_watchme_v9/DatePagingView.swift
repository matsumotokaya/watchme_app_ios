import SwiftUI

/// 日付ベースのページングビュー
/// selectedDateを中心に、スワイプで日付を切り替えるUIを提供
struct DatePagingView<Content: View>: View {
    @Binding var selectedDate: Date
    let dashboardViewModel: DashboardViewModel?
    let content: (Date) -> Content
    
    private let calendar = Calendar.current
    
    /// 選択された日付（日付部分のみ）
    private var normalizedSelectedDate: Date {
        get { calendar.startOfDay(for: selectedDate) }
        set { selectedDate = newValue }
    }
    
    /// 表示する日付の範囲を動的に生成
    private var dateRange: [Date] {
        let today = calendar.startOfDay(for: Date())
        
        // プロトタイプ版：過去30日から今日まで
        // 後で必要に応じて動的な範囲に変更可能
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: today) else {
            return [today]
        }
        
        var dates: [Date] = []
        var currentDate = startDate
        while currentDate <= today {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return dates
    }
    
    init(selectedDate: Binding<Date>, dashboardViewModel: DashboardViewModel?, @ViewBuilder content: @escaping (Date) -> Content) {
        self._selectedDate = selectedDate
        self.dashboardViewModel = dashboardViewModel
        self.content = content
    }
    
    var body: some View {
        TabView(selection: Binding(
            get: { normalizedSelectedDate },
            set: { selectedDate = $0 }
        )) {
            ForEach(dateRange, id: \.self) { date in
                content(date)
                    .tag(date)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedDate) { oldValue, newValue in
            // 未来の日付が選択された場合、今日に戻す
            let today = calendar.startOfDay(for: Date())
            let normalized = calendar.startOfDay(for: newValue)
            if normalized > today {
                selectedDate = today
            }
            
            // 前後の日付をプリロード
            preloadAdjacentDates(for: normalized)
        }
        .onAppear {
            // 初回表示時に前後の日付をプリロード
            preloadAdjacentDates(for: normalizedSelectedDate)
        }
    }
    
    /// 前後の日付のデータをプリロードする
    private func preloadAdjacentDates(for date: Date) {
        // DashboardViewModelがある場合のみプリロード
        if let dashboardViewModel = dashboardViewModel {
            var datesToPreload: [Date] = []
            
            // 前日
            if let previousDate = calendar.date(byAdding: .day, value: -1, to: date) {
                datesToPreload.append(previousDate)
            }
            
            // 翌日（今日を超えない範囲で）
            let today = calendar.startOfDay(for: Date())
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: date),
               nextDate <= today {
                datesToPreload.append(nextDate)
            }
            
            // プリロード実行
            if !datesToPreload.isEmpty {
                dashboardViewModel.preloadReports(for: datesToPreload)
            }
        }
    }
    
}

// MARK: - Preview
struct DatePagingView_Previews: PreviewProvider {
    static var previews: some View {
        DatePagingView(selectedDate: .constant(Date()), dashboardViewModel: nil) { date in
            VStack {
                Text(date, style: .date)
                    .font(.largeTitle)
                    .padding()
                
                Text("スワイプで日付を切り替え")
                    .foregroundColor(.secondary)
            }
        }
    }
}