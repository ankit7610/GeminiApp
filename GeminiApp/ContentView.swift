import SwiftUI
import Foundation

// MARK: - Color Palette
extension Color {
    static let primaryBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let secondaryBackground = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let tertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let quaternaryBackground = Color(red: 0.18, green: 0.18, blue: 0.20)
    static let accentBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let accentPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let borderColor = Color(red: 0.25, green: 0.25, blue: 0.27)
}

// MARK: - Model
struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
    let messageType: MessageType = .text
    
    enum MessageType {
        case text, code, error, system
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Gemini API Service
class GeminiService: ObservableObject {
    private let apiKey = "YOUR_API_KEY_HERE"
    private let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")!
    
    func sendMessage(_ message: String, completion: @escaping(Result<String, Error>) -> Void) {
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
    @Published var showingSettings: Bool = false
    @Published var typingIndicator: Bool = false
    
    private let geminiService = GeminiService()
    
    init() {
        setupWelcomeMessage()
    }
    
    private func setupWelcomeMessage() {
        let welcomeMessage = Message(
            text: "Welcome to Gemini AI Pro! I'm here to assist you with any questions or tasks. How can I help you today?",
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
        typingIndicator = true
        errorMessage = nil
        
        // Add slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.geminiService.sendMessage(textToSend) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.typingIndicator = false
                    
                    switch result {
                    case .success(let reply):
                        let botMessage = Message(text: reply, isUser: false)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self?.messages.append(botMessage)
                        }
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        let errorMessage = Message(text: "I apologize, but I encountered an error. Please try again in a moment.", isUser: false)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self?.messages.append(errorMessage)
                        }
                    }
                }
            }
        }
    }
    
    func clearChat() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            messages.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupWelcomeMessage()
        }
    }
    
    func deleteMessage(_ message: Message) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            messages.removeAll { $0.id == message.id }
        }
    }
}

// MARK: - Advanced Message Bubble
struct AdvancedMessageBubble: View {
    let message: Message
    let onDelete: () -> Void
    @State private var showingOptions = false
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
                userMessageView
            } else {
                aiMessageView
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 20)
        .contextMenu {
            Button(action: copyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text(message.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentBlue, Color.accentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.accentBlue.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
            
            HStack(spacing: 6) {
                Text(formatTime(message.timestamp))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentGreen)
            }
        }
    }
    
    private var aiMessageView: some View {
        HStack(alignment: .top, spacing: 16) {
            // AI Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPurple.opacity(0.8), Color.accentBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.accentPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.tertiaryBackground)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.borderColor, lineWidth: 1)
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 12, weight: .medium))
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

// MARK: - Advanced Typing Indicator
struct AdvancedTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // AI Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPurple.opacity(0.8), Color.accentBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.accentPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentBlue, Color.accentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 10, height: 10)
                            .scaleEffect(animationOffset == CGFloat(index) ? 1.3 : 1.0)
                            .opacity(animationOffset == CGFloat(index) ? 1.0 : 0.6)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                value: animationOffset
                            )
                    }
                    
                    Text("AI is thinking...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.tertiaryBackground)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
            }
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationOffset = 2
            }
        }
    }
}

// MARK: - Professional Header
struct ProfessionalHeader: View {
    let clearAction: () -> Void
    let settingsAction: () -> Void
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentPurple, Color.accentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.accentPurple.opacity(glowIntensity), radius: 10, x: 0, y: 0)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemini AI Pro")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.accentGreen)
                                .frame(width: 8, height: 8)
                                .shadow(color: Color.accentGreen, radius: 3, x: 0, y: 0)
                            
                            Text("Online")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentGreen)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: settingsAction) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondaryBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(ProfessionalButtonStyle())
                
                Button(action: clearAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(ProfessionalButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.secondaryBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
    }
}

// MARK: - Advanced Input View
struct AdvancedInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let sendAction: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.borderColor)
                .frame(height: 1)
            
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField("Type your message here...", text: $text, axis: .vertical)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1...6)
                        .disabled(isLoading)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if !isLoading && canSend {
                                sendAction()
                            }
                        }
                    
                    if !text.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                text = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.textTertiary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(Color.tertiaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .stroke(
                                    isTextFieldFocused ?
                                    LinearGradient(colors: [Color.accentBlue, Color.accentPurple], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [Color.borderColor], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: isTextFieldFocused ? 2 : 1
                                )
                        )
                )
                .shadow(color: isTextFieldFocused ? Color.accentBlue.opacity(0.2) : Color.clear, radius: 10, x: 0, y: 0)
                
                Button(action: sendAction) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                canSend || isLoading ?
                                LinearGradient(colors: [Color.accentBlue, Color.accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.textTertiary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 50, height: 50)
                            .scaleEffect(pulseAnimation && isLoading ? 1.1 : 1.0)
                            .shadow(color: (canSend || isLoading) ? Color.accentBlue.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(isLoading ? 0 : 0))
                    }
                }
                .disabled(!canSend && !isLoading)
                .buttonStyle(ProfessionalButtonStyle())
                .onChange(of: isLoading) { loading in
                    if loading {
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    } else {
                        pulseAnimation = false
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.secondaryBackground)
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Professional Button Style
struct ProfessionalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.accentBlue)
                        Text("Dark Mode")
                        Spacer()
                        Text("Always On")
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Section("AI Settings") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.accentPurple)
                        Text("Model")
                        Spacer()
                        Text("Gemini Pro")
                            .foregroundColor(.textSecondary)
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
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main Chat View
struct AdvancedChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProfessionalHeader(
                    clearAction: viewModel.clearChat,
                    settingsAction: { viewModel.showingSettings = true }
                )
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(viewModel.messages) { message in
                                AdvancedMessageBubble(
                                    message: message,
                                    onDelete: { viewModel.deleteMessage(message) }
                                )
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -20))
                                ))
                            }
                            
                            if viewModel.typingIndicator {
                                AdvancedTypingIndicator()
                                    .id("typing")
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                                        removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -20))
                                    ))
                            }
                        }
                        .padding(.vertical, 30)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.typingIndicator) { isTyping in
                        if isTyping {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                AdvancedInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    sendAction: viewModel.sendMessage
                )
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(isPresented: $viewModel.showingSettings)
        }
        .alert("Connection Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Retry") {
                viewModel.errorMessage = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - App Entry Point
@main
struct AdvancedGeminiChatApp: App {
    var body: some Scene {
        WindowGroup {
            AdvancedChatView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Preview
struct AdvancedChatView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedChatView()
            .preferredColorScheme(.dark)
    }
}
