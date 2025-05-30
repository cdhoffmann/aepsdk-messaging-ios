import Foundation
import WebKit
import AEPCore
import AEPServices

/// MessagingBridge provides a simple JavaScript-to-Native communication interface for in-app messages
/// This abstracts away the complexity shown in the Adobe documentation where customers manually register handlers
@objc(AEPMessagingBridge)
public class MessagingBridge: NSObject {
    /// Singleton instance of the MessagingBridge
    @objc public static let shared = MessagingBridge()
    
    /// Private initializer to enforce singleton pattern
    private override init() {
        super.init()
    }
    
    /// Registers a WKWebView with the JavaScript bridge
    /// - Parameters:
    ///   - webView: The WKWebView to register with the bridge
    ///   - message: The parent Message object associated with the webview
    @objc public func registerWebView(_ webView: WKWebView, withMessage message: Message) {
        Log.debug(label: MessagingConstants.LOG_TAG, "Starting JavaScript bridge registration for message: \(message.id)")
        
        // Register the native message handlers first (this is what customers would do manually)
        registerNativeHandlers(for: message)
        
        // Add the bridge user script BEFORE loading HTML
        MessagingBridge.shared.addBridgeUserScript(to: webView)
        
        Log.debug(label: MessagingConstants.LOG_TAG, "JavaScript bridge registration completed for message: \(message.id)")
    }
    
    // MARK: - Private Methods
    
    /// Registers the native message handlers (like customers do manually in MessagingDelegate)
    /// This is what the Adobe documentation shows customers doing in shouldShowMessage
    /// - Parameter message: The Message object to register the handlers for
    private func registerNativeHandlers(for message: Message) {
        Log.debug(label: MessagingConstants.LOG_TAG, "Registering native handlers...")
        
        // Register "aepCloseMessage" handler - this creates webkit.messageHandlers.aepCloseMessage
        message.handleJavascriptMessage("aepCloseMessage") { _ in
            Log.debug(label: MessagingConstants.LOG_TAG, "JavaScript bridge: aepCloseMessage called")
            message.dismiss()
        }
        
        // Register "aepLogClick" handler - this creates webkit.messageHandlers.aepLogClick  
        message.handleJavascriptMessage("aepLogClick") { data in
            let buttonId = data as? String
            Log.debug(label: MessagingConstants.LOG_TAG, "JavaScript bridge: aepLogClick called with buttonId: \(buttonId ?? "nil")")
            message.track(buttonId, withEdgeEventType: .interact)
        }
        
        Log.debug(label: MessagingConstants.LOG_TAG, "Native handlers registered successfully")
    }
    
    /// Adds the AEP JS bridge as a WKUserScript to the WKWebView configuration.
    /// Call this BEFORE loading any HTML content.
    public func addBridgeUserScript(to webView: WKWebView) {
        let bridgeScript = """
        window.aepBridge = {};
        window.aepBridge.closeMessage = function() {
            webkit.messageHandlers.aepCloseMessage.postMessage(null);
        };
        window.aepBridge.logClick = function(buttonId) {
            webkit.messageHandlers.aepLogClick.postMessage(buttonId || "");
        };
        """
        let userScript = WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(userScript)
    }
} 
