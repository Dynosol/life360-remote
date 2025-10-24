//
//  Life720App.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import SwiftUI
import Foundation

@main
struct Life720App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var phone = ConfigLoader.defaultPhoneNumber
    @State private var country = ConfigLoader.defaultCountryCode
    @State private var otp = ""
    @State private var txId: String?
    @State private var bearer: String?
    @State private var log: String = ""
    @State private var circleId = ""
    @State private var selectedTab = 0
    @State private var authSectionExpanded = true
    @State private var apiSectionExpanded = false
    @State private var circles: [Circle] = []
    @State private var selectedCircleIds: Set<String> = []
    @State private var serverIP = UserDefaults.standard.string(forKey: "serverIP") ?? "10.0.0.0"
    @State private var serverPort = UserDefaults.standard.string(forKey: "serverPort") ?? "8000"
    @State private var showServerSettings = false
    @FocusState private var focusedField: Field?
    @StateObject private var wsManager = WebSocketManager()
    
    private let client = Life360Client()

    enum Field {
        case phone, country, otp, circleId, serverIP, serverPort
    }

    init() {
        setLogHandler { text in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appendLogNotification, object: text)
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Controls Tab
            controlsTab()
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
                .tag(0)
            
            // Logs Tab
            logsTab()
                .tabItem {
                    Label("Logs", systemImage: "doc.text.fill")
                }
                .tag(1)
                .badge(log.isEmpty ? nil : "•")
        }
        .onReceive(NotificationCenter.default.publisher(for: .appendLogNotification)) { note in
            if let text = note.object as? String {
                log += text
            }
        }
        .onAppear {
            debugPrintLog("App started - Connecting to remote server...")
            connectToServer()
        }
        .onDisappear {
            wsManager.disconnect()
        }
    }
}

private extension ContentView {
    func connectToServer() {
        let serverURL = "ws://\(serverIP):\(serverPort)"
        wsManager.updateServerURL(serverURL)
        wsManager.connect()
    }
    
    @ViewBuilder
    func controlsTab() -> some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    statusCard()
                    serverSettingsSection()
                    authenticationSection()
                    apiActionsSection()
                }
                .padding()
            }
            .navigationTitle("Life360 Client")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func logsTab() -> some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(log.isEmpty ? "No logs yet. Perform an action to see logs here." : log)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(log.isEmpty ? .gray : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .id("bottom")
                        }
                        .onChange(of: log) { _ in
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.systemGray6))
                
                // Bottom toolbar
                HStack {
                    Button(action: {
                        UIPasteboard.general.string = log
                        debugPrintLog("✓ Log copied to clipboard")
                    }) {
                        Label("Copy", systemImage: "doc.on.doc.fill")
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(log.isEmpty)
                    
                    Button(action: {
                        log = ""
                        debugPrintLog("✓ Logs cleared")
                    }) {
                        Label("Clear", systemImage: "trash.fill")
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(log.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    @ViewBuilder
    func statusCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack {
                StatusBadge(title: "Server", value: wsManager.isConnected ? "✓" : "–", color: wsManager.isConnected ? .green : .red)
                StatusBadge(title: "Transaction", value: txId != nil ? "✓" : "–", color: txId != nil ? .green : .gray)
            }
            HStack {
                StatusBadge(title: "Bearer", value: bearer != nil ? "✓" : "–", color: bearer != nil ? .green : .gray)
                StatusBadge(title: "Mode", value: "Remote", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    func serverSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    showServerSettings.toggle()
                }
            }) {
                HStack {
                    Label("Server Settings", systemImage: "server.rack")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showServerSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if showServerSettings {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server IP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Server IP", text: $serverIP)
                                .textFieldStyle(ModernTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .serverIP)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Port")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Port", text: $serverPort)
                                .textFieldStyle(ModernTextFieldStyle())
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .serverPort)
                                .frame(width: 90)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            focusedField = nil
                            UserDefaults.standard.set(serverIP, forKey: "serverIP")
                            UserDefaults.standard.set(serverPort, forKey: "serverPort")
                            wsManager.disconnect()
                            connectToServer()
                            debugPrintLog("Reconnecting to ws://\(serverIP):\(serverPort)")
                        }) {
                            Label("Connect", systemImage: "link")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            focusedField = nil
                            wsManager.disconnect()
                            debugPrintLog("Disconnected from server")
                        }) {
                            Label("Disconnect", systemImage: "link.slash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("ws://\(serverIP):\(serverPort)/ws/ios-app")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    func authenticationSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    authSectionExpanded.toggle()
                }
            }) {
                HStack {
                    Label("Authentication", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Spacer()
                    Image(systemName: authSectionExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.purple)
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if authSectionExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Country", text: $country)
                            .textFieldStyle(ModernTextFieldStyle())
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .country)
                            .frame(width: 70)
                        
                        TextField("Phone Number", text: $phone)
                            .textFieldStyle(ModernTextFieldStyle())
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .phone)
                    }
                    
                    Button(action: {
                        focusedField = nil
                        debugPrintLog("→ Sending OTP...")
                        Task {
                            do {
                                txId = try await client.sendOTP(phone: phone, country: country, logger: debugPrintLog)
                                debugPrintLog("Transaction: \(txId ?? "nil")")
                            } catch {
                                debugPrintLog("Send OTP error: \(error)")
                            }
                        }
                    }) {
                        Label("Send OTP", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    TextField("Enter OTP Code", text: $otp)
                        .textFieldStyle(ModernTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .otp)
                    
                    Button(action: {
                        focusedField = nil
                        guard let tx = txId else { debugPrintLog("No transaction id"); return }
                        Task {
                            do {
                                bearer = try await client.verifyOTP(transactionId: tx, code: otp, logger: debugPrintLog)
                                debugPrintLog("Bearer: \(bearer ?? "nil")")
                                withAnimation {
                                    authSectionExpanded = false
                                    apiSectionExpanded = true
                                }
                            } catch {
                                debugPrintLog("Verify OTP error: \(error)")
                            }
                        }
                    }) {
                        Label("Verify OTP", systemImage: "checkmark.shield.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bearer == nil ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(txId == nil)
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    func apiActionsSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    apiSectionExpanded.toggle()
                }
            }) {
                HStack {
                    Label("API Actions", systemImage: "network")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Spacer()
                    Image(systemName: apiSectionExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.orange)
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if apiSectionExpanded {
                VStack(spacing: 12) {
                    APIButton(title: "Get Profile", icon: "person.circle.fill", color: .purple) {
                        focusedField = nil
                        guard let b = bearer else { debugPrintLog("No bearer"); return }
                        Task {
                            do {
                                let user = try await client.getUserProfile(bearer: b, logger: debugPrintLog)
                                debugPrintLog("User JSON: \(user)")
                            } catch {
                                debugPrintLog("Profile error: \(error)")
                            }
                        }
                    }
                    .disabled(bearer == nil)
                    
                    APIButton(title: "Get Circles", icon: "person.3.fill", color: .blue) {
                        focusedField = nil
                        guard let b = bearer else { debugPrintLog("No bearer"); return }
                        Task {
                            do {
                                let circlesJSON = try await client.getCircles(bearer: b, logger: debugPrintLog)
                                debugPrintLog("Circles JSON: \(circlesJSON)")
                                
                                if let data = circlesJSON.data(using: .utf8) {
                                    let response = try JSONDecoder().decode(CirclesResponse.self, from: data)
                                    circles = response.circles
                                    debugPrintLog("✓ Parsed \(circles.count) circles")
                                }
                            } catch {
                                debugPrintLog("Circles error: \(error)")
                            }
                        }
                    }
                    .disabled(bearer == nil)
                    
                    circlesList()
                    
                    APIButton(title: "Get Device Locations", icon: "location.circle.fill", color: .teal) {
                        focusedField = nil
                        guard let b = bearer else { debugPrintLog("No bearer"); return }
                        Task {
                            for circleId in selectedCircleIds.isEmpty ? circles.map(\.id) : Array(selectedCircleIds) {
                                let circleName = circles.first(where: { $0.id == circleId })?.name ?? circleId
                                debugPrintLog("→ Fetching device locations for: \(circleName)")
                                do {
                                    let locations = try await client.getCircleDeviceLocations(circleId: circleId, bearer: b, logger: debugPrintLog)
                                    debugPrintLog("Device locations for \(circleName): \(locations)")
                                } catch {
                                    debugPrintLog("Locations error for \(circleName): \(error)")
                                }
                            }
                        }
                    }
                    .disabled(bearer == nil)
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    func circlesList() -> some View {
        if !circles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Circles:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(circles) { circle in
                    Button(action: {
                        if selectedCircleIds.contains(circle.id) {
                            selectedCircleIds.remove(circle.id)
                        } else {
                            selectedCircleIds.insert(circle.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedCircleIds.contains(circle.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedCircleIds.contains(circle.id) ? .blue : .gray)
                            Text(circle.name)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selectedCircleIds.contains(circle.id) ? Color.blue.opacity(0.1) : Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
                
                if !selectedCircleIds.isEmpty {
                    APIButton(title: "Get Members for \(selectedCircleIds.count) Circle(s)", icon: "person.2.fill", color: .green) {
                        focusedField = nil
                        guard let b = bearer else { debugPrintLog("No bearer"); return }
                        Task {
                            for circleId in selectedCircleIds {
                                let circleName = circles.first(where: { $0.id == circleId })?.name ?? circleId
                                debugPrintLog("→ Fetching members for: \(circleName)")
                                do {
                                    let members = try await client.getCircleMembers(circleId: circleId, bearer: b, logger: debugPrintLog)
                                    debugPrintLog("Members for \(circleName): \(members)")
                                } catch {
                                    debugPrintLog("Members error for \(circleName): \(error)")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

extension Notification.Name {
    static let appendLogNotification = Notification.Name("appendLogNotification")
}
