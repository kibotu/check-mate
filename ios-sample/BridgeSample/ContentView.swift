//
//  ContentView.swift
//  BridgeSample
//
//  Main view containing the WebView with bridge
//

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var bridgeController = BridgeViewController()
    
    var body: some View {
        TabView {
            NavigationView {
                VStack(spacing: 0) {
                    // WebView (local assets with bridge)
                    BridgeWebViewRepresentable(controller: bridgeController)
                    
                    // Status bar
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(bridgeController.isReady ? .green : .orange)
                        Text(bridgeController.isReady ? "Bridge Ready" : "Initializing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let lastAction = bridgeController.lastAction {
                            Text("Last: \(lastAction)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                }
                .navigationTitle("Bridge Sample")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Reload WebView") {
                                bridgeController.reload()
                            }
                            
                            Button("Send Test Event") {
                                bridgeController.sendTestEvent()
                            }
                            
                            Button("Call Web Function") {
                                Task {
                                    await bridgeController.testCallWeb()
                                }
                            }
                            
                            Divider()
                            
                            Button("Toggle Debug") {
                                bridgeController.toggleDebug()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "house.fill")
                Text("Assets")
            }
            
            NavigationView {
                SimpleWebView(url: URL(string: "https://portfolio.kibotu.net/")!)
                    .navigationTitle("Portfolio")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "globe")
                Text("Portfolio")
            }
        }
    }
}

// SwiftUI wrapper for WKWebView
struct BridgeWebViewRepresentable: UIViewControllerRepresentable {
    let controller: BridgeViewController
    
    func makeUIViewController(context: Context) -> BridgeViewController {
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BridgeViewController, context: Context) {
        // Updates handled by the controller itself
    }
}

// Simple WKWebView wrapper for external URLs (no bridge)
struct SimpleWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No dynamic updates needed
    }
}

#Preview {
    ContentView()
}

