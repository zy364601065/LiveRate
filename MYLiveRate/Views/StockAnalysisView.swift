import SwiftUI

struct StockAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    let record: HoldingRecord
    @State private var result: StockAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    private let service = StockAnalysisService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.stockName).font(.title2.bold())
                        Text(record.stockCode ?? "无股票代码").foregroundStyle(.secondary)
                    }
                    if isLoading { ProgressView("正在获取行情并生成分析…").frame(maxWidth: .infinity).padding(.vertical, 60) }
                    else if let errorMessage { ContentUnavailableView("分析失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage)); retryButton }
                    else if let result { Text(try! AttributedString(markdown: result.content)).font(.body); Text("生成于 \(result.createdAt.formatted()) · AI 分析仅供参考，不构成投资建议").font(.caption).foregroundStyle(.secondary) }
                    else { ContentUnavailableView("开始 AI 分析", systemImage: "sparkles", description: Text("将根据最新公开行情和策略生成中文报告。")); analyzeButton }
                }.padding(20)
            }
            .navigationTitle("AI 分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
    }

    private var analyzeButton: some View { Button("开始分析", systemImage: "sparkles") { Task { await analyze() } }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity) }
    private var retryButton: some View { Button("重试") { Task { await analyze() } }.buttonStyle(.bordered).frame(maxWidth: .infinity) }
    private func analyze() async {
        guard let symbol = record.stockCode, !symbol.isEmpty else { errorMessage = "请先在更多菜单中补充股票代码"; return }
        isLoading = true; errorMessage = nil
        do { result = try await service.analyze(symbol: symbol, name: record.stockName) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
