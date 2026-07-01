import Foundation

@MainActor
final class CompilerViewModel: ObservableObject {
    @Published var objCCode: String = ""
    @Published var statusMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var isDownloading: Bool = false
    @Published var canDownload: Bool = false
    @Published var readyFileURL: URL? = nil
    @Published var showShareSheet: Bool = false

    func startCompilation(user: String, repo: String, token: String) async {
        guard !user.isEmpty, !repo.isEmpty, !token.isEmpty else {
            statusMessage = "⚠️ نرجو إكمال كافة الحقول الأمنية (Auth Fields)."
            return
        }
        
        isLoading = true
        canDownload = false
        statusMessage = "⚙️ جاري تشفير الطلب وإرساله إلى محرك OBSIDIAN..."

        do {
            try await GitHubService.shared.triggerWorkflow(user: user, repo: repo, token: token, code: objCCode)
            statusMessage = "✅ تم الإطلاق بنجاح! السيرفر يطبخ الكود الآن. انتظر 60 ثانية تقريباً لظهور زر التحميل."
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            canDownload = true
        } catch {
            statusMessage = "❌ فشل الاتصال: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func fetchCompiledFile(user: String, repo: String, token: String) async {
        isDownloading = true
        statusMessage = "📥 جاري الفحص وسحب الـ Dylib المكتمل من الخوادم..."

        do {
            let fileURL = try await GitHubService.shared.downloadDylib(user: user, repo: repo, token: token)
            self.readyFileURL = fileURL
            self.showShareSheet = true
            statusMessage = "🎉 تم السحب والتجهيز بنجاح! يرجى الحفظ في النظام."
        } catch {
            statusMessage = "⏳ الملف غير متوفر بعد! المحرك لا يزال يبني، يرجى المحاولة بعد قليل."
        }
        isDownloading = false
    }
}
