/*
 Copyright 2023 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
import WebKit
@testable import AEPMessaging
@testable import AEPServices
import AEPCore
import AEPTestUtils

class MessagingBridgeTests: XCTestCase {
    
    var mockMessaging: MockMessaging!
    var mockFullscreenMessage: MockFullscreenMessage!
    var mockMessage: MockMessage!
    var mockWebView: WKWebView!
    var mockEvent: Event!
    
    override func setUp() {
        mockMessaging = MockMessaging(runtime: TestableExtensionRuntime())
        mockEvent = Event(name: "name", type: "type", source: "source", data: nil)
        mockMessage = MockMessage(parent: mockMessaging, triggeringEvent: mockEvent)
        mockFullscreenMessage = MockFullscreenMessage(parent: mockMessage)
        mockMessage.fullscreenMessage = mockFullscreenMessage
        mockWebView = WKWebView()
        mockFullscreenMessage.webView = mockWebView
    }
    
    override func tearDown() {
        mockMessaging = nil
        mockFullscreenMessage = nil
        mockMessage = nil
        mockWebView = nil
        mockEvent = nil
    }
    
    func testSharedInstanceExists() {
        // Test that the shared instance exists and is a MessagingBridge
        XCTAssertNotNil(MessagingBridge.shared)
        XCTAssertTrue(MessagingBridge.shared is MessagingBridge)
    }
    
    func testRegisterWebView() {
        // Test that registerWebView adds JavaScript handlers
        let javascriptHandlerExpectation = expectation(description: "JavaScript handler expectation")
        
        // Mock the evaluateJavaScript method to verify it's called
        let originalMethod = mockWebView.evaluateJavaScript(_:completionHandler:)
        mockWebView.evaluateJavaScript = { script, completion in
            // Verify the script contains our simplified bridge definition
            XCTAssertTrue(script.contains("window.aepBridge"))
            XCTAssertTrue(script.contains("closeMessage"))
            XCTAssertTrue(script.contains("logClick"))
            XCTAssertTrue(script.contains("requestPushPermission"))
            XCTAssertTrue(script.contains("logCustomEvent"))
            XCTAssertTrue(script.contains("getVersion"))
            XCTAssertTrue(script.contains("isReady"))
            XCTAssertTrue(script.contains("aep.BridgeReady"))
            
            // Verify simplified bridge features
            XCTAssertTrue(script.contains("safeCall"))
            XCTAssertTrue(script.contains("queueCall"))
            XCTAssertTrue(script.contains("executeQueuedCalls"))
            XCTAssertTrue(script.contains("markBridgeReady"))
            
            // Call the original implementation
            originalMethod(script, completion)
            javascriptHandlerExpectation.fulfill()
        }
        
        // Register the webview
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        wait(for: [javascriptHandlerExpectation], timeout: 1.0)
        
        // Reset the mocked method
        mockWebView.evaluateJavaScript = originalMethod
    }
    
    func testAddHandler() {
        // Test that addHandler properly registers a JavaScript handler
        let handlerExpectation = expectation(description: "Handler expectation")
        
        // Register a custom handler
        MessagingBridge.shared.addHandler("testHandler", handler: { data, message in
            // Verify the data and message are correct
            XCTAssertEqual(data as? String, "test data")
            XCTAssertEqual(message.id, self.mockMessage.id)
            handlerExpectation.fulfill()
        }, forMessage: mockMessage)
        
        // Verify handleJavascriptMessage was called on the message
        XCTAssertTrue(mockFullscreenMessage.handleJavascriptMessageCalled)
        XCTAssertEqual(mockFullscreenMessage.paramJavascriptMessage, "testHandler")
        
        // Simulate the JavaScript message being received
        mockFullscreenMessage.paramJavascriptHandlerReturnValue = "test data"
        // Call the handler that was registered
        if let handler = mockFullscreenMessage.javascriptHandlers["testHandler"] {
            handler(mockFullscreenMessage.paramJavascriptHandlerReturnValue)
        }
        
        wait(for: [handlerExpectation], timeout: 1.0)
    }
    
    func testAddHandlerWithEmptyName() {
        // Test that addHandler handles empty names gracefully
        MessagingBridge.shared.addHandler("", handler: { _, _ in
            XCTFail("Handler should not be called for empty name")
        }, forMessage: mockMessage)
        
        // Verify handleJavascriptMessage was not called
        XCTAssertFalse(mockFullscreenMessage.handleJavascriptMessageCalled)
    }
    
    func testEvaluateJavaScript() {
        // Test that evaluateJavaScript correctly calls the WebView's evaluateJavaScript
        let javascriptExpectation = expectation(description: "JavaScript evaluation expectation")
        
        // Mock the evaluateJavaScript method
        let originalMethod = mockWebView.evaluateJavaScript(_:completionHandler:)
        mockWebView.evaluateJavaScript = { script, completion in
            // Verify the script is correct
            XCTAssertEqual(script, "console.log('test');")
            javascriptExpectation.fulfill()
            
            // Call the completion handler
            if let completion = completion {
                completion("result", nil)
            }
        }
        
        // Evaluate JavaScript
        MessagingBridge.shared.evaluateJavaScript("console.log('test');", in: mockWebView) { result, error in
            XCTAssertEqual(result as? String, "result")
            XCTAssertNil(error)
        }
        
        wait(for: [javascriptExpectation], timeout: 1.0)
        
        // Reset the mocked method
        mockWebView.evaluateJavaScript = originalMethod
    }
    
    func testEvaluateJavaScriptWithEmptyString() {
        // Test that evaluateJavaScript handles empty strings gracefully
        let expectation = self.expectation(description: "Completion called")
        
        MessagingBridge.shared.evaluateJavaScript("", in: mockWebView) { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual((error as NSError?)?.domain, "AEPMessagingBridge")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCloseMessageHandler() {
        // Test that the closeMessage handler correctly dismisses the message
        let dismissExpectation = expectation(description: "Dismiss expectation")
        
        // Mock the dismiss method
        mockMessage.dismissImpl = {
            dismissExpectation.fulfill()
        }
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the closeMessage handler
        if let handler = mockFullscreenMessage.javascriptHandlers["closeMessage"] {
            handler(nil)
        }
        
        wait(for: [dismissExpectation], timeout: 1.0)
    }
    
    func testLogClickHandler() {
        // Test that the logClick handler correctly tracks clicks
        let trackExpectation = expectation(description: "Track expectation")
        
        // Mock the track method
        mockMessage.trackImpl = { interaction, eventType in
            XCTAssertEqual(interaction, "testButton")
            XCTAssertEqual(eventType, .interact)
            trackExpectation.fulfill()
        }
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the logClick handler with a button ID
        if let handler = mockFullscreenMessage.javascriptHandlers["logClick"] {
            handler("testButton")
        }
        
        wait(for: [trackExpectation], timeout: 1.0)
    }
    
    func testLogClickHandlerEmpty() {
        // Test that the logClick handler with empty data works correctly
        let trackExpectation = expectation(description: "Track expectation")
        
        // Mock the track method
        mockMessage.trackImpl = { interaction, eventType in
            XCTAssertNil(interaction)
            XCTAssertEqual(eventType, .interact)
            trackExpectation.fulfill()
        }
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the logClick handler with empty data
        if let handler = mockFullscreenMessage.javascriptHandlers["logClick"] {
            handler("")
        }
        
        wait(for: [trackExpectation], timeout: 1.0)
    }
    
    func testRequestPushPermissionHandler() {
        // Test that the requestPushPermission handler correctly tracks the request
        let trackExpectation = expectation(description: "Track expectation")
        
        // Mock the track method
        mockMessage.trackImpl = { interaction, eventType in
            XCTAssertEqual(interaction, "push_permission_requested")
            XCTAssertEqual(eventType, .interact)
            trackExpectation.fulfill()
        }
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the requestPushPermission handler
        if let handler = mockFullscreenMessage.javascriptHandlers["requestPushPermission"] {
            handler(nil)
        }
        
        wait(for: [trackExpectation], timeout: 1.0)
    }
    
    func testLogCustomEventHandler() {
        // Test that the logCustomEvent handler correctly tracks custom events
        let trackExpectation = expectation(description: "Track expectation")
        
        // Mock the track method
        mockMessage.trackImpl = { interaction, eventType in
            XCTAssertEqual(interaction, "custom_event_test")
            XCTAssertEqual(eventType, .interact)
            trackExpectation.fulfill()
        }
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the logCustomEvent handler with valid data
        let eventData = ["name": "custom_event_test", "data": ["key": "value"]] as [String: Any]
        if let handler = mockFullscreenMessage.javascriptHandlers["logCustomEvent"] {
            handler(eventData)
        }
        
        wait(for: [trackExpectation], timeout: 1.0)
    }
    
    func testLogCustomEventHandlerInvalidData() {
        // Test that the logCustomEvent handler handles invalid data gracefully
        
        // Register the webview to add the standard handlers
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        // Simulate calling the logCustomEvent handler with invalid data
        if let handler = mockFullscreenMessage.javascriptHandlers["logCustomEvent"] {
            handler("invalid_data")
        }
        
        // Verify track was not called
        XCTAssertFalse(mockMessage.trackCalled)
    }
    
    func testCleanupHandlers() {
        // Test that cleanupHandlers can be called without errors
        MessagingBridge.shared.cleanupHandlers(for: mockMessage)
        
        // This test mainly ensures the method exists and doesn't crash
        // In a real implementation, this might clean up specific handlers
    }
    
    func testSimplifiedBridgeScriptInjection() {
        // Test that the simplified bridge script is properly formatted and contains all necessary components
        let javascriptExpectation = expectation(description: "JavaScript injection expectation")
        
        let originalMethod = mockWebView.evaluateJavaScript(_:completionHandler:)
        mockWebView.evaluateJavaScript = { script, completion in
            // Verify the script is wrapped in an IIFE
            XCTAssertTrue(script.contains("(function()"))
            
            // Verify simplified bridge features
            XCTAssertTrue(script.contains("let bridgeReady = false"))
            XCTAssertTrue(script.contains("let pendingCalls = []"))
            XCTAssertTrue(script.contains("function queueCall"))
            XCTAssertTrue(script.contains("function executeQueuedCalls"))
            XCTAssertTrue(script.contains("function safeCall"))
            XCTAssertTrue(script.contains("function markBridgeReady"))
            
            // Verify isReady method
            XCTAssertTrue(script.contains("isReady: function()"))
            XCTAssertTrue(script.contains("return bridgeReady"))
            
            // Verify version method
            XCTAssertTrue(script.contains("getVersion"))
            XCTAssertTrue(script.contains("return '1.0.0'"))
            
            // Verify bridge ready event
            XCTAssertTrue(script.contains("aep.BridgeReady"))
            
            // Verify immediate initialization
            XCTAssertTrue(script.contains("markBridgeReady()"))
            
            completion?(nil, nil)
            javascriptExpectation.fulfill()
        }
        
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        wait(for: [javascriptExpectation], timeout: 1.0)
        
        // Reset the mocked method
        mockWebView.evaluateJavaScript = originalMethod
    }
    
    func testBridgeMethodsUseSimplifiedAPI() {
        // Test that the bridge methods use the simplified safeCall API
        let javascriptExpectation = expectation(description: "JavaScript injection expectation")
        
        let originalMethod = mockWebView.evaluateJavaScript(_:completionHandler:)
        mockWebView.evaluateJavaScript = { script, completion in
            // Verify all bridge methods use safeCall
            XCTAssertTrue(script.contains("safeCall('closeMessage', 'closeMessage', null)"))
            XCTAssertTrue(script.contains("safeCall('logClick', 'logClick', buttonId || \"\")"))
            XCTAssertTrue(script.contains("safeCall('requestPushPermission', 'requestPushPermission', null)"))
            XCTAssertTrue(script.contains("safeCall('logCustomEvent', 'logCustomEvent', payload)"))
            
            // Verify no direct webkit.messageHandlers calls in bridge methods
            let bridgeMethodsSection = script.components(separatedBy: "window.aepBridge = {")[1].components(separatedBy: "};")[0]
            XCTAssertFalse(bridgeMethodsSection.contains("window.webkit.messageHandlers"))
            
            completion?(nil, nil)
            javascriptExpectation.fulfill()
        }
        
        MessagingBridge.shared.registerWebView(mockWebView, withMessage: mockMessage)
        
        wait(for: [javascriptExpectation], timeout: 1.0)
        
        // Reset the mocked method
        mockWebView.evaluateJavaScript = originalMethod
    }
}

// MARK: - Mock WKWebView extension
extension WKWebView {
    // Swizzle evaluateJavaScript for testing
    @objc dynamic var evaluateJavaScript: (@convention(block) (String, ((Any?, Error?) -> Void)?) -> Void) {
        get {
            return { script, completion in
                completion?(nil, nil)
            }
        }
        set {
            // Setter for mocking
        }
    }
}

// MARK: - MockMessage
class MockMessage: Message {
    var trackCalled = false
    var paramTrackInteraction: String?
    var paramTrackEventType: MessagingEdgeEventType?
    var dismissCalled = false
    var trackImpl: ((String?, MessagingEdgeEventType) -> Void)?
    var dismissImpl: (() -> Void)?
    
    override func track(_ interaction: String? = nil, withEdgeEventType eventType: MessagingEdgeEventType) {
        trackCalled = true
        paramTrackInteraction = interaction
        paramTrackEventType = eventType
        trackImpl?(interaction, eventType)
    }
    
    override func dismiss(suppressAutoTrack: Bool = false) {
        dismissCalled = true
        dismissImpl?()
    }
}

// MARK: - MockFullscreenMessage with JavaScript handlers
class MockFullscreenMessage: FullscreenMessage {
    var javascriptHandlers: [String: (Any?) -> Void] = [:]
    var handleJavascriptMessageCalled = false
    var paramJavascriptMessage: String?
    var paramJavascriptHandlerReturnValue: Any?
    
    public init(parent: Message? = nil) {
        let messageSettings = MessageSettings(parent: parent)
        super.init(payload: "", listener: nil, isLocalImageUsed: false, messageMonitor: MessageMonitor(), settings: messageSettings)
        webView = WKWebView()
    }
    
    override func handleJavascriptMessage(_ name: String, withHandler handler: @escaping (Any?) -> Void) {
        handleJavascriptMessageCalled = true
        paramJavascriptMessage = name
        javascriptHandlers[name] = handler
    }
} 