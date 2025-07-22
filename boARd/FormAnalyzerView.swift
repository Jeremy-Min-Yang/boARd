import SwiftUI
import PhotosUI
import Foundation

struct FormAnalyzerView: View {
    @State private var showPicker = false
    @State private var videoURL: URL?
    @State private var feedback: String?

    var body: some View {
        VStack {
            if let feedback = feedback {
                Text("Feedback: \(feedback)")
                    .padding()
            }
            Button("Select Video") {
                showPicker = true
            }
            .padding()
        }
        .sheet(isPresented: $showPicker) {
            VideoPicker(videoURL: $videoURL)
        }
        .onChange(of: videoURL) { url in
            if let url = url {
                uploadVideo(url: url) { result in
                    DispatchQueue.main.async {
                        self.feedback = result ?? "Failed to get feedback."
                    }
                }
            }
        }
    }
}

struct FormAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        FormAnalyzerView()
    }
}

// VideoPicker and uploadVideo are defined below

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.hasItemConformingToTypeIdentifier("public.movie") else { return }
            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                if let url = url {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    DispatchQueue.main.async {
                        self.parent.videoURL = tempURL
                    }
                }
            }
        }
    }
}

func uploadVideo(url: URL, completion: @escaping (String?) -> Void) {
    let endpoint = URL(string: "http://localhost:8000/analyze")! // Change to your backend URL
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()
    let filename = url.lastPathComponent
    let mimetype = "video/mp4"

    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
    data.append(try! Data(contentsOf: url))
    data.append("\r\n".data(using: .utf8)!)
    data.append("--\(boundary)--\r\n".data(using: .utf8)!)

    URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
        guard let responseData = responseData, error == nil else {
            completion(nil)
            return
        }
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let feedback = json["feedback"] as? String {
            completion(feedback)
        } else {
            completion(nil)
        }
    }.resume()
} 