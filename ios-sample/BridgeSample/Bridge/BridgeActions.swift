//
//  BridgeActions.swift
//  BridgeSample
//
//  Native action handlers implementing the bridge specification
//

import Foundation
import UIKit
import AVFoundation
import CoreLocation

/// Handler for all bridge actions from the web side
class BridgeActionHandler {
    
    weak var viewController: UIViewController?
    private let locationManager = CLLocationManager()
    
    init(viewController: UIViewController? = nil) {
        self.viewController = viewController
    }
    
    /// Main dispatcher for incoming bridge actions
    func handleAction(_ action: String, content: [String: Any]?) async throws -> Any? {
        print("[Bridge] Handling action: \(action)")
        
        switch action {
        // Device & System
        case "getDeviceInfo":
            return try await getDeviceInfo()
            
        case "requestPermission":
            guard let type = content?["permission"] as? String else {
                throw BridgeError.invalidParameters
            }
            return try await requestPermission(type: type)
            
        case "openSettings":
            return try await openSettings()
            
        case "copyToClipboard":
            guard let text = content?["text"] as? String else {
                throw BridgeError.invalidParameters
            }
            return try await copyToClipboard(text: text)
            
        case "openUrl":
            guard let urlString = content?["url"] as? String else {
                throw BridgeError.invalidParameters
            }
            let external = content?["external"] as? Bool ?? false
            return try await openUrl(urlString: urlString, external: external)
            
        // UI & Alerts
        case "showToast":
            guard let message = content?["message"] as? String else {
                throw BridgeError.invalidParameters
            }
            let duration = content?["duration"] as? String ?? "short"
            return try await showToast(message: message, duration: duration)
            
        case "showAlert":
            guard let title = content?["title"] as? String,
                  let message = content?["message"] as? String else {
                throw BridgeError.invalidParameters
            }
            let buttons = content?["buttons"] as? [[String: String]] ?? []
            return try await showAlert(title: title, message: message, buttons: buttons)
            
        case "setTitle":
            guard let title = content?["title"] as? String else {
                throw BridgeError.invalidParameters
            }
            return try await setTitle(title: title)
            
        // Storage
        case "getSecureData":
            guard let key = content?["key"] as? String else {
                throw BridgeError.invalidParameters
            }
            return try await getSecureData(key: key)
            
        case "setSecureData":
            guard let key = content?["key"] as? String,
                  let value = content?["value"] else {
                throw BridgeError.invalidParameters
            }
            return try await setSecureData(key: key, value: value)
            
        case "removeSecureData":
            guard let key = content?["key"] as? String else {
                throw BridgeError.invalidParameters
            }
            return try await removeSecureData(key: key)
            
        // Analytics (fire-and-forget)
        case "trackEvent":
            let name = content?["event"] as? String ?? "unknown"
            let properties = content?["properties"] as? [String: Any]
            trackEvent(name: name, properties: properties)
            return nil
            
        case "trackScreen":
            let name = content?["screen"] as? String ?? "unknown"
            let properties = content?["properties"] as? [String: Any]
            trackScreen(name: name, properties: properties)
            return nil
            
        case "setUserId":
            guard let userId = content?["userId"] as? String else {
                throw BridgeError.invalidParameters
            }
            setUserId(userId: userId)
            return nil
            
        // Network
        case "getNetworkStatus":
            return try await getNetworkStatus()
            
        default:
            throw BridgeError.actionNotFound(action)
        }
    }
    
    // MARK: - Device & System Actions
    
    private func getDeviceInfo() async throws -> [String: Any] {
        return await MainActor.run {
            let device = UIDevice.current
            
            #if targetEnvironment(simulator)
            let isSimulator = true
            #else
            let isSimulator = false
            #endif
            
            return [
                "platform": "iOS",
                "osVersion": device.systemVersion,
                "model": device.model,
                "name": device.name,
                "identifierForVendor": device.identifierForVendor?.uuidString ?? "",
                "systemName": device.systemName,
                "isSimulator": isSimulator,
                "screenScale": UIScreen.main.scale,
                "screenSize": [
                    "width": UIScreen.main.bounds.width,
                    "height": UIScreen.main.bounds.height
                ]
            ]
        }
    }
    
    private func requestPermission(type: String) async throws -> [String: Any] {
        switch type.lowercased() {
        case "camera":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch status {
            case .authorized:
                return ["granted": true, "status": "authorized"]
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                return ["granted": granted, "status": granted ? "authorized" : "denied"]
            case .denied, .restricted:
                return ["granted": false, "status": "denied"]
            @unknown default:
                return ["granted": false, "status": "unknown"]
            }
            
        case "location":
            let status = locationManager.authorizationStatus
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                return ["granted": true, "status": "authorized"]
            case .notDetermined:
                // Note: Actual request would need proper delegate setup
                return ["granted": false, "status": "notDetermined", "message": "Call requestWhenInUseAuthorization"]
            case .denied, .restricted:
                return ["granted": false, "status": "denied"]
            @unknown default:
                return ["granted": false, "status": "unknown"]
            }
            
        default:
            throw BridgeError.invalidParameters
        }
    }
    
    private func openSettings() async throws -> [String: Bool] {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            throw BridgeError.unknown("Cannot open settings")
        }
        
        let opened = await UIApplication.shared.open(url)
        return ["success": opened]
    }
    
    private func copyToClipboard(text: String) async throws -> [String: Bool] {
        UIPasteboard.general.string = text
        return ["success": true]
    }
    
    private func openUrl(urlString: String, external: Bool) async throws -> [String: Bool] {
        guard let url = URL(string: urlString) else {
            throw BridgeError.invalidParameters
        }
        
        if external || !url.absoluteString.hasPrefix("http") {
            let opened = await UIApplication.shared.open(url)
            return ["success": opened]
        } else {
            // Could open in SFSafariViewController or custom in-app browser
            let opened = await UIApplication.shared.open(url)
            return ["success": opened]
        }
    }
    
    // MARK: - UI Actions
    
    @MainActor
    private func showToast(message: String, duration: String) async throws -> [String: Bool] {
        guard let vc = viewController else {
            throw BridgeError.unknown("No view controller available")
        }
        
        // Simple toast implementation using UIAlertController
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        vc.present(alert, animated: true)
        
        let seconds: TimeInterval = duration == "long" ? 3.0 : 1.5
        
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        alert.dismiss(animated: true)
        
        return ["success": true]
    }
    
    @MainActor
    private func showAlert(title: String, message: String, buttons: [[String: String]]) async throws -> [String: Any] {
        guard let vc = viewController else {
            throw BridgeError.unknown("No view controller available")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            if buttons.isEmpty {
                // Default OK button
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    continuation.resume(returning: ["button": "OK", "index": 0])
                })
            } else {
                for (index, button) in buttons.enumerated() {
                    let title = button["title"] ?? "Button \(index)"
                    let styleStr = button["style"] ?? "default"
                    let style: UIAlertAction.Style = styleStr == "cancel" ? .cancel : (styleStr == "destructive" ? .destructive : .default)
                    
                    alert.addAction(UIAlertAction(title: title, style: style) { _ in
                        continuation.resume(returning: ["button": title, "index": index])
                    })
                }
            }
            
            vc.present(alert, animated: true)
        }
    }
    
    @MainActor
    private func setTitle(title: String) async throws -> [String: Bool] {
        guard let vc = viewController else {
            throw BridgeError.unknown("No view controller available")
        }
        
        vc.navigationItem.title = title
        return ["success": true]
    }
    
    // MARK: - Storage Actions
    
    private func getSecureData(key: String) async throws -> [String: Any?] {
        // Simple UserDefaults implementation (for production, use Keychain)
        let value = UserDefaults.standard.object(forKey: "bridge_\(key)")
        return ["value": value]
    }
    
    private func setSecureData(key: String, value: Any) async throws -> [String: Bool] {
        UserDefaults.standard.set(value, forKey: "bridge_\(key)")
        return ["success": true]
    }
    
    private func removeSecureData(key: String) async throws -> [String: Bool] {
        UserDefaults.standard.removeObject(forKey: "bridge_\(key)")
        return ["success": true]
    }
    
    // MARK: - Analytics Actions (Fire-and-forget)
    
    private func trackEvent(name: String, properties: [String: Any]?) {
        print("[Analytics] Track Event: \(name)", properties ?? [:])
        // Integrate with your analytics service here
    }
    
    private func trackScreen(name: String, properties: [String: Any]?) {
        print("[Analytics] Track Screen: \(name)", properties ?? [:])
        // Integrate with your analytics service here
    }
    
    private func setUserId(userId: String) {
        print("[Analytics] Set User ID: \(userId)")
        // Integrate with your analytics service here
    }
    
    // MARK: - Network Actions
    
    private func getNetworkStatus() async throws -> [String: Any] {
        // Simple implementation - for production use Network framework
        return [
            "online": true,
            "type": "wifi", // Could be "cellular", "wifi", "unknown"
            "effectiveType": "4g"
        ]
    }
}

