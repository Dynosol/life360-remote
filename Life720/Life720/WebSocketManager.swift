//
//  WebSocketManager.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    private var webSocketTask: URLSessionWebSocketTask?
    private var serverURL: String
    private let clientId: String
    private var life360Client: Life360Client
    private var txId: String?
    private var bearer: String?
    
    init(serverURL: String = "ws://localhost:8000", clientId: String = "ios-app") {
        self.serverURL = serverURL
        self.clientId = clientId
        self.life360Client = Life360Client()
    }
    
    func updateServerURL(_ newURL: String) {
        self.serverURL = newURL
    }
    
    func connect() {
        guard let url = URL(string: "\(serverURL)/ws/\(clientId)") else {
            debugPrintLog("Invalid WebSocket URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        debugPrintLog("Connecting to server: \(url.absoluteString)")
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        debugPrintLog("Disconnected from server")
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                debugPrintLog("WebSocket error: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.connect() // Auto-reconnect
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        debugPrintLog("Received: \(text)")
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commandId = json["command_id"] as? String,
              let type = json["type"] as? String else {
            debugPrintLog("Invalid command format")
            return
        }
        
        let params = json["params"] as? [String: Any]
        
        Task {
            await handleCommand(commandId: commandId, type: type, params: params)
        }
    }
    
    private func handleCommand(commandId: String, type: String, params: [String: Any]?) async {
        debugPrintLog("Processing command: \(type)")
        
        switch type {
        case "ping":
            await sendResponse(commandId: commandId, status: "success", data: ["pong": true])
            
        case "get_status":
            let statusData: [String: Any] = [
                "has_transaction": txId != nil,
                "has_bearer": bearer != nil,
                "is_authenticated": bearer != nil
            ]
            await sendResponse(commandId: commandId, status: "success", data: statusData)
            
        case "send_otp":
            guard let phone = params?["phone"] as? String,
                  let country = params?["country"] as? String else {
                await sendResponse(commandId: commandId, status: "error", error: "Missing phone or country")
                return
            }
            
            do {
                txId = try await life360Client.sendOTP(phone: phone, country: country, logger: debugPrintLog)
                await sendResponse(commandId: commandId, status: "success", data: ["transaction_id": txId ?? ""])
            } catch {
                await sendResponse(commandId: commandId, status: "error", error: "Send OTP failed: \(error.localizedDescription)")
            }
            
        case "verify_otp":
            guard let transactionId = params?["transaction_id"] as? String,
                  let code = params?["code"] as? String else {
                await sendResponse(commandId: commandId, status: "error", error: "Missing transaction_id or code")
                return
            }
            
            do {
                bearer = try await life360Client.verifyOTP(transactionId: transactionId, code: code, logger: debugPrintLog)
                await sendResponse(commandId: commandId, status: "success", data: ["bearer_token": bearer ?? ""])
            } catch {
                await sendResponse(commandId: commandId, status: "error", error: "Verify OTP failed: \(error.localizedDescription)")
            }
            
        case "get_profile":
            guard let b = bearer else {
                await sendResponse(commandId: commandId, status: "error", error: "Not authenticated")
                return
            }
            
            do {
                let profile = try await life360Client.getUserProfile(bearer: b, logger: debugPrintLog)
                if let profileData = profile.data(using: .utf8),
                   let profileJson = try? JSONSerialization.jsonObject(with: profileData) {
                    await sendResponse(commandId: commandId, status: "success", data: profileJson)
                } else {
                    await sendResponse(commandId: commandId, status: "success", data: ["raw": profile])
                }
            } catch {
                await sendResponse(commandId: commandId, status: "error", error: "Get profile failed: \(error.localizedDescription)")
            }
            
        case "get_circles":
            guard let b = bearer else {
                await sendResponse(commandId: commandId, status: "error", error: "Not authenticated")
                return
            }
            
            do {
                let circlesStr = try await life360Client.getCircles(bearer: b, logger: debugPrintLog)
                if let circlesData = circlesStr.data(using: .utf8),
                   let circlesJson = try? JSONSerialization.jsonObject(with: circlesData) {
                    await sendResponse(commandId: commandId, status: "success", data: circlesJson)
                } else {
                    await sendResponse(commandId: commandId, status: "success", data: ["raw": circlesStr])
                }
            } catch {
                await sendResponse(commandId: commandId, status: "error", error: "Get circles failed: \(error.localizedDescription)")
            }
            
        case "get_circle_members":
            guard let b = bearer,
                  let circleId = params?["circle_id"] as? String else {
                await sendResponse(commandId: commandId, status: "error", error: "Not authenticated or missing circle_id")
                return
            }
            
            do {
                let membersStr = try await life360Client.getCircleMembers(circleId: circleId, bearer: b, logger: debugPrintLog)
                if let membersData = membersStr.data(using: .utf8),
                   let membersJson = try? JSONSerialization.jsonObject(with: membersData) {
                    await sendResponse(commandId: commandId, status: "success", data: membersJson)
                } else {
                    await sendResponse(commandId: commandId, status: "success", data: ["raw": membersStr])
                }
            } catch {
                await sendResponse(commandId: commandId, status: "error", error: "Get members failed: \(error.localizedDescription)")
            }
            
        case "get_device_locations":
            guard let b = bearer,
                  let circleIds = params?["circle_ids"] as? [String] else {
                await sendResponse(commandId: commandId, status: "error", error: "Not authenticated or missing circle_ids")
                return
            }
            
            var allLocations: [String: Any] = [:]
            
            for circleId in circleIds {
                do {
                    let locationsStr = try await life360Client.getCircleDeviceLocations(circleId: circleId, bearer: b, logger: debugPrintLog)
                    if let locationsData = locationsStr.data(using: .utf8),
                       let locationsJson = try? JSONSerialization.jsonObject(with: locationsData) {
                        allLocations[circleId] = locationsJson
                    } else {
                        allLocations[circleId] = ["raw": locationsStr]
                    }
                } catch {
                    allLocations[circleId] = ["error": error.localizedDescription]
                }
            }
            
            await sendResponse(commandId: commandId, status: "success", data: allLocations)
            
        default:
            await sendResponse(commandId: commandId, status: "error", error: "Unknown command type: \(type)")
        }
    }
    
    private func sendResponse(commandId: String, status: String, data: Any? = nil, error: String? = nil) async {
        var response: [String: Any] = [
            "command_id": commandId,
            "status": status
        ]
        
        if let data = data {
            response["data"] = data
        }
        
        if let error = error {
            response["error"] = error
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: response),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            debugPrintLog("Failed to serialize response")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                debugPrintLog("Send error: \(error.localizedDescription)")
            } else {
                debugPrintLog("Sent response: \(status)")
            }
        }
    }
}

