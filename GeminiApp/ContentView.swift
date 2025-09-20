import SwiftUI
import Foundation

// MARK: - Color Palette
extension Color {
    static let primaryBackground = Color(red: 0.06, green: 0.06, blue: 0.09)
    static let secondaryBackground = Color(red: 0.09, green: 0.09, blue: 0.12)
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let accentBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let accentPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let textPrimary = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.55)
    static let borderColor = Color(red: 0.25, green: 0.25, blue: 0.30)
}

// MARK: - Model
struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Gemini API Service
class GeminiService: ObservableObject {
    private let apiKey = "YOUR_API_KEY_HERE" // Replace with your actual API key
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    
    func sendMessage(_ message: String, completion: @escaping(Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            completion(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": message]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
                if let text = response.candidates.first?.content.parts.first?.text {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response text found"])))
                }
            } catch {
                completion(.failure(error))
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
    @Published var showingSettings: Bool = false
    @Published var expandedMessages: Set<UUID> = []
    
    private let geminiService = GeminiService()
    
    init() {
        setupWelcomeMessage()
    }
    
    private func setupWelcomeMessage() {
        let welcomeMessage = Message(
            text: "Welcome to Gemini AI Chat! I'm here to assist you with any questions or tasks. How can I help you today?",
            isUser: false
        )
        messages.append(welcomeMessage)
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.messages.append(botMessage)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    let errorMessage = Message(text: "I apologize, but I encountered an error. Please check your API key and try again.", isUser: false)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.messages.append(errorMessage)
                    }
                }
            }
        }
    }
    
    func clearChat() {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.removeAll()
            expandedMessages.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupWelcomeMessage()
        }
    }
    
    func deleteMessage(_ message: Message) {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.removeAll { $0.id == message.id }
            expandedMessages.remove(message.id)
        }
    }
    
    func toggleMessageExpansion(_ messageId: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedMessages.contains(messageId) {
                expandedMessages.remove(messageId)
            } else {
                expandedMessages.insert(messageId)
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isExpanded: Bool
    let onDelete: () -> Void
    let onToggleExpansion: () -> Void
    
    private var shouldShowReadMore: Bool {
        !message.isUser && message.text.count > 150
    }
    
    private var displayText: String {
        if isExpanded || message.text.count <= 150 {
            return message.text
        }
        return String(message.text.prefix(150)) + "..."
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 50)
                userMessageView
            } else {
                aiMessageView
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .contextMenu {
            Button("Copy", action: copyMessage)
            if shouldShowReadMore {
                Button(isExpanded ? "Show Less" : "Show More", action: onToggleExpansion)
            }
            Button("Delete", action: onDelete)
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [Color.accentBlue, Color.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.textTertiary)
        }
    }
    
    private var aiMessageView: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [Color.accentPurple, Color.accentBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                    
                    if shouldShowReadMore {
                        Button(action: onToggleExpansion) {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.borderColor, lineWidth: 1)
                        )
                )
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                    .padding(.leading, 4)
            }
        }
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.text
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.accentPurple, Color.accentBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.textSecondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
                
                Text("AI is typing...")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.borderColor, lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 16)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let clearAction: () -> Void
    let settingsAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentPurple, Color.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemini AI Chat")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.accentGreen)
                                .frame(width: 6, height: 6)
                            
                            Text("Online")
                                .font(.system(size: 12))
                                .foregroundColor(.accentGreen)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: settingsAction) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.cardBackground)
                            .clipShape(Circle())
                    }
                    
                    Button(action: clearAction) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.cardBackground)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.borderColor)
        }
        .background(Color.secondaryBackground)
    }
}

// MARK: - Input View
struct InputView: View {
    @Binding var text: String
    let isLoading: Bool
    let sendAction: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.borderColor)
            
            HStack(spacing: 12) {
                HStack {
                    TextField("Type your message here...", text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1...6)
                        .disabled(isLoading)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if canSend {
                                sendAction()
                            }
                        }
                    
                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(isTextFieldFocused ? Color.accentBlue : Color.borderColor, lineWidth: 1)
                        )
                )
                
                Button(action: sendAction) {
                    Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(canSend || isLoading ?
                                      LinearGradient(colors: [Color.accentBlue, Color.accentPurple],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing) :
                                      LinearGradient(colors: [Color.textTertiary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                }
                .disabled(!canSend && !isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.secondaryBackground)
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("App Information") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.accentBlue)
                        Text("Model: Gemini 2.0 Flash")
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentPurple)
                        Text("Version: 1.0.0")
                    }
                }
                
                Section("Configuration") {
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.accentGreen)
                        Text("API Key: Configured")
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.orange)
                        Text("Privacy: Protected")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main Chat View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                clearAction: viewModel.clearChat,
                settingsAction: { viewModel.showingSettings = true }
            )
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isExpanded: viewModel.expandedMessages.contains(message.id),
                                onDelete: { viewModel.deleteMessage(message) },
                                onToggleExpansion: { viewModel.toggleMessageExpansion(message.id) }
                            )
                            .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.primaryBackground)
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    if isLoading {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
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
        .background(Color.primaryBackground)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(isPresented: $viewModel.showingSettings)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

// MARK: - App Entry Point
@main
struct GeminiChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
