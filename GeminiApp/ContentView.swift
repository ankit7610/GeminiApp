import SwiftUI
import Foundation

// MARK: - Model
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - Gemini API Service
class GeminiService {
    private let apiKey = ""
    private let url = URL(string: "")!
    
    func sendMessage(_ message: String, completion: @escaping(Result<String, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("", forHTTPHeaderField: "X-goog-api-key")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": message]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if let response = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let text = response.candidates.first?.content.parts.first?.text {
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
            }
        }.resume()
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - ViewModel
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let geminiService = GeminiService()
    
    init() {
        // Add welcome message
        messages.append(Message(text: "Hello! I'm Gemini AI. How can I help you today?", isUser: false))
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(text: inputText, isUser: true)
        messages.append(userMessage)
        
        let textToSend = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        geminiService.sendMessage(textToSend) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let reply):
                    let botMessage = Message(text: reply, isUser: false)
                    self?.messages.append(botMessage)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    let errorMessage = Message(text: "Sorry, I encountered an error. Please try again.", isUser: false)
                    self?.messages.append(errorMessage)
                }
            }
        }
    }
    
    func clearChat() {
        messages = [Message(text: "Hello! I'm Gemini AI. How can I help you today?", isUser: false)]
    }
}

// MARK: - Custom Components
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20, corners: [.topLeft, .topRight, .bottomLeft])
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                        .padding(8)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
                        
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LoadingIndicator: View {
    @State private var animateGradient = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.system(size: 20))
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateGradient ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animateGradient
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            animateGradient = true
        }
    }
}

struct HeaderView: View {
    let clearAction: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gemini Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Powered by Google AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: clearAction) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
}

struct InputView: View {
    @Binding var text: String
    let isLoading: Bool
    let sendAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Type your message...", text: $text, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...4)
                    .disabled(isLoading)
                    .onSubmit {
                        if !isLoading {
                            sendAction()
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(25)
            
            Button(action: sendAction) {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(canSend ? .blue : .gray)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            .disabled(!canSend && !isLoading)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
        )
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Main View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HeaderView(clearAction: viewModel.clearChat)
                
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                LoadingIndicator()
                                    .id("loading")
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isLoading) { isLoading in
                        if isLoading {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
                
                InputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    sendAction: viewModel.sendMessage
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - App Entry
@main
struct GeminiChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .preferredColorScheme(.light) // Remove this line to support system theme
        }
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .previewDevice("iPhone 14 Pro")
    }
}
