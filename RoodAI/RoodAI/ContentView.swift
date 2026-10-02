import PhotosUI
import SwiftUI

@MainActor
struct ContentView: View {
    @State private var image: UIImage?
    @State private var analysis: MealAnalysis?
    @State private var errorMessage: String?
    @State private var isAnalyzing = false
    @State private var note = ""

    @State private var showCamera = false
    @State private var showSettings = false
    @State private var photoItem: PhotosPickerItem?
    @State private var analysisTask: Task<Void, Never>?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        emptyState
                    }

                    if isAnalyzing {
                        ProgressView("Analyzing your meal…")
                            .padding(.vertical, 24)
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    } else if let analysis {
                        MealResultView(analysis: analysis)
                    }

                    if image != nil && !isAnalyzing {
                        refineSection
                    }
                }
                .padding()
            }
            .navigationTitle("RoodAI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { captureBar }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { captured in use(captured) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let picked = UIImage(data: data) {
                        use(picked)
                    }
                    photoItem = nil
                }
            }
            .onAppear {
                if KeychainStore.apiKey.isEmpty { showSettings = true }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Snap your meal")
                .font(.title2.bold())
            Text("Take a photo of any meal or snack to get calories, protein, carbs and fat.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 60)
    }

    private var refineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add details (optional)")
                .font(.subheadline.weight(.semibold))
            TextField("e.g. large portion, cooked in butter, no dressing", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            Button("Re-analyze") { analyze() }
                .buttonStyle(.bordered)
                .disabled(image == nil)
        }
    }

    private var captureBar: some View {
        HStack(spacing: 12) {
            if cameraAvailable {
                Button { showCamera = true } label: {
                    Label("Snap", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding()
        .background(.bar)
    }

    private func use(_ newImage: UIImage) {
        image = newImage
        note = ""
        analyze()
    }

    private func analyze() {
        guard let image else { return }
        analysisTask?.cancel()
        isAnalyzing = true
        errorMessage = nil
        analysis = nil

        let analyzer = MacroAnalyzer(apiKey: KeychainStore.apiKey)
        let currentNote = note
        analysisTask = Task {
            do {
                let result = try await analyzer.analyze(image: image, note: currentNote)
                guard !Task.isCancelled else { return }
                analysis = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

#Preview {
    ContentView()
}
