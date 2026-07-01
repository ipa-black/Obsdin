import SwiftUI

// رسم شعار OBSIDIAN بصيغة Vector
struct ObsidianCrystal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: width, y: height * 0.4))
        path.addLine(to: CGPoint(x: width * 0.7, y: height))
        path.addLine(to: CGPoint(x: width * 0.3, y: height))
        path.addLine(to: CGPoint(x: 0, y: height * 0.4))
        path.closeSubpath()
        return path
    }
}

// نافذة حفظ الملفات بنظام iOS
struct ShareSheetWrapper: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MainDashboardView: View {
    @AppStorage("githubUser") private var githubUser: String = ""
    @AppStorage("repoName") private var repoName: String = ""
    @AppStorage("githubPAT") private var githubPAT: String = ""
    
    @StateObject private var viewModel = CompilerViewModel()
    
    private let obsBlack = Color(red: 0.02, green: 0.02, blue: 0.03)
    private let obsGray = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let obsGold = Color(red: 0.85, green: 0.72, blue: 0.25)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                obsBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // الهيدر العلوي
                    HStack {
                        ObsidianCrystal()
                            .fill(LinearGradient(gradient: Gradient(colors: [obsGold, .orange]), startPoint: .top, endPoint: .bottom))
                            .frame(width: 25, height: 35)
                            .shadow(color: obsGold.opacity(0.5), radius: 5, x: 0, y: 0)
                            .padding(.trailing, 8)
                            
                        Text("OBSIDIAN")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(obsGray.ignoresSafeArea(edges: .top))
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // 1. بوابة العبور
                            VStack(alignment: .leading, spacing: 16) {
                                Label("بوابة العبور (Auth)", systemImage: "network.badge.shield.half.filled")
                                    .font(.headline)
                                    .foregroundColor(obsGold)
                                
                                CustomField(placeholder: "اسم المستخدم", text: $githubUser, isSecure: false)
                                CustomField(placeholder: "اسم المستودع", text: $repoName, isSecure: false)
                                CustomField(placeholder: "رمز PAT", text: $githubPAT, isSecure: true)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(obsGray)
                            .cornerRadius(18)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(obsGold.opacity(0.4), lineWidth: 1.5))
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            
                            // 2. محرر الأكواد
                            VStack(alignment: .leading, spacing: 12) {
                                Label("بيئة التطوير (Objective-C)", systemImage: "terminal.fill")
                                    .font(.headline)
                                    .foregroundColor(obsGold)
                                
                                TextEditor(text: $viewModel.objCCode)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .background(obsBlack)
                                    .frame(minHeight: geometry.size.height * 0.35)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(obsGray)
                            .cornerRadius(18)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(obsGold.opacity(0.4), lineWidth: 1.5))
                            .padding(.horizontal, 16)
                            
                            // 3. الأزرار
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task { await viewModel.startCompilation(user: githubUser, repo: repoName, token: githubPAT) }
                                }) {
                                    HStack {
                                        if viewModel.isLoading {
                                            ProgressView().tint(obsBlack).padding(.trailing, 8)
                                        }
                                        Text(viewModel.isLoading ? "جاري حقن الأكواد..." : "توليد الـ Dylib الآن")
                                            .font(.system(size: 20, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(viewModel.objCCode.isEmpty ? Color.gray.opacity(0.3) : obsGold)
                                    .foregroundColor(viewModel.objCCode.isEmpty ? .gray : obsBlack)
                                    .cornerRadius(18)
                                    .shadow(color: obsGold.opacity(viewModel.objCCode.isEmpty ? 0 : 0.3), radius: 10, x: 0, y: 5)
                                }
                                .disabled(viewModel.isLoading || viewModel.objCCode.isEmpty)
                                
                                if viewModel.canDownload {
                                    Button(action: {
                                        // التحديث هنا: تمرير التوكن لسحب الملف من المستودع الخاص
                                        Task { await viewModel.fetchCompiledFile(user: githubUser, repo: repoName, token: githubPAT) }
                                    }) {
                                        HStack {
                                            if viewModel.isDownloading {
                                                ProgressView().tint(.white).padding(.trailing, 8)
                                            }
                                            Image(systemName: "square.and.arrow.down.fill")
                                                .font(.system(size: 22))
                                            Text(viewModel.isDownloading ? "جاري سحب الملف..." : "حفظ الـ Dylib في النظام")
                                                .font(.system(size: 20, weight: .bold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(Color.green.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(18)
                                        .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 5)
                                    }
                                    .disabled(viewModel.isDownloading)
                                }
                                
                                if !viewModel.statusMessage.isEmpty {
                                    Text(viewModel.statusMessage)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(16)
                                        .background(obsBlack)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.readyFileURL {
                    ShareSheetWrapper(activityItems: [url])
                }
            }
        }
    }
}

// تصميم حقول الإدخال
struct CustomField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(16)
        .background(Color(red: 0.02, green: 0.02, blue: 0.03))
        .foregroundColor(.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
    }
}
