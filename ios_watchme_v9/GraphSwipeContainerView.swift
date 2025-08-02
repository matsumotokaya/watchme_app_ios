import SwiftUI

struct GraphSwipeContainerView<Content: View>: View {
    @Binding var selectedDate: Date
    let content: (Date) -> Content
    
    @State private var currentIndex: Int = 1
    @State private var dates: [Date] = []
    
    private let calendar = Calendar.current
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(0..<3, id: \.self) { index in
                    content(dates[safe: index] ?? selectedDate)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { oldValue, newValue in
                // スワイプの役割：表示されているページの日付をselectedDateに設定
                if let date = dates[safe: newValue] {
                    // 未来の日付かチェック（日単位で比較）
                    let today = calendar.startOfDay(for: Date())
                    let targetDay = calendar.startOfDay(for: date)
                    
                    if targetDay > today {
                        // 未来の日付の場合、元の位置に戻す
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentIndex = oldValue
                        }
                    } else {
                        // 過去または今日の日付の場合、選択日付を更新
                        selectedDate = date
                    }
                }
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                // 外部からの日付変更の役割：日付配列を再構築し、中央にリセット
                // oldDateとnewDateが異なる場合のみ処理（無限ループ防止）
                if !calendar.isDate(oldDate, inSameDayAs: newDate) {
                    updateDatesAndReset(for: newDate)
                }
            }
            .onAppear {
                updateDatesAndReset(for: selectedDate)
            }
        }
    }
    
    private func updateDatesAndReset(for date: Date) {
        // 日付配列を更新
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        // 常に標準的な配列構成を使用
        dates = [yesterday, date, tomorrow]
        
        // 中央のページにリセット
        currentIndex = 1
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Calendar {
    func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        return self.isDate(date1, equalTo: date2, toGranularity: .day)
    }
}

struct GraphSwipeContainerView_Previews: PreviewProvider {
    static var previews: some View {
        GraphSwipeContainerView(selectedDate: .constant(Date())) { date in
            Text("Graph for \(date, formatter: DateFormatter())")
        }
    }
}