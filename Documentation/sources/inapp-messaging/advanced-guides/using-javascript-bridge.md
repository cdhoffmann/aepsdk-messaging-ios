# Using the JavaScript Bridge in In-App Messages

The AEP Messaging SDK provides a simple and robust JavaScript bridge that enables seamless communication between your HTML in-app messages and native code. The bridge automatically handles error cases, queuing, and availability checks, so you can focus on your message content without worrying about complex integration code.

## 5-Minute Quick Start

Want to get started immediately? Here's a complete, working in-app message:

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: system-ui; text-align: center; padding: 40px 20px; }
        .card { background: white; border-radius: 12px; padding: 30px; max-width: 300px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        button { background: #007AFF; color: white; border: none; padding: 12px 24px; border-radius: 8px; width: 100%; margin: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🎉 Special Offer!</h1>
        <p>Get 20% off your next purchase!</p>
        
        <!-- Just use aepBridge directly - no setup needed! -->
        <button onclick="aepBridge.logClick('offer_accepted'); aepBridge.closeMessage();">
            Claim Offer
        </button>
        
        <button onclick="aepBridge.closeMessage();">
            Maybe Later
        </button>
    </div>
</body>
</html>
```

**That's it!** No JavaScript setup, no error handling, no availability checks. The bridge handles everything automatically.

## Quick Start

Simply use the `window.aepBridge` object in your HTML - it's automatically available and ready to use:

```html
<!-- Close the message -->
<button onclick="aepBridge.closeMessage()">Close</button>

<!-- Track button clicks -->
<button onclick="aepBridge.logClick('primary_action')">Get Started</button>

<!-- Log custom events -->
<button onclick="aepBridge.logCustomEvent('newsletter_signup', {source: 'popup'})">
    Subscribe
</button>
```

That's it! No error handling, no availability checks, no complex setup required.

## JavaScript Bridge Methods

The bridge provides these simple methods:

| Method | Description | Example |
|--------|-------------|---------|
| `aepBridge.closeMessage()` | Dismisses the current message | `aepBridge.closeMessage()` |
| `aepBridge.logClick(buttonId)` | Tracks a button click or interaction | `aepBridge.logClick('accept_offer')` |
| `aepBridge.requestPushPermission()` | Requests push notification permission | `aepBridge.requestPushPermission()` |
| `aepBridge.logCustomEvent(name, data)` | Logs a custom event with optional data | `aepBridge.logCustomEvent('engagement', {value: 1})` |
| `aepBridge.getVersion()` | Returns the bridge version | `aepBridge.getVersion()` |
| `aepBridge.isReady()` | Checks if bridge is ready (always true when called) | `aepBridge.isReady()` |

## Simple Examples

### Basic Message with Tracking

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: system-ui; text-align: center; padding: 20px; }
        .button { 
            background: #007AFF; color: white; padding: 15px 30px; 
            border: none; border-radius: 8px; margin: 10px; cursor: pointer; 
        }
    </style>
</head>
<body>
    <h1>Special Offer!</h1>
    <p>Get 25% off your next purchase</p>
    
    <button class="button" onclick="aepBridge.logClick('offer_accepted'); aepBridge.closeMessage();">
        Accept Offer
    </button>
    
    <button class="button" onclick="aepBridge.logClick('offer_declined'); aepBridge.closeMessage();">
        No Thanks
    </button>
</body>
</html>
```

### Newsletter Signup with Custom Events

```html
<form onsubmit="handleSignup(event)">
    <input type="email" id="email" placeholder="Enter your email" required>
    <button type="submit">Subscribe</button>
</form>

<script>
function handleSignup(event) {
    event.preventDefault();
    const email = document.getElementById('email').value;
    
    // Log the signup event
    aepBridge.logCustomEvent('newsletter_signup', {
        source: 'in_app_message',
        timestamp: new Date().toISOString()
    });
    
    // Close the message
    aepBridge.closeMessage();
}
</script>
```

### Multi-step Flow

```html
<div id="step1">
    <h2>Welcome!</h2>
    <button onclick="nextStep()">Get Started</button>
</div>

<div id="step2" style="display: none;">
    <h2>Enable Notifications?</h2>
    <button onclick="aepBridge.requestPushPermission(); nextStep()">Yes</button>
    <button onclick="nextStep()">Skip</button>
</div>

<div id="step3" style="display: none;">
    <h2>You're all set!</h2>
    <button onclick="aepBridge.logClick('onboarding_complete'); aepBridge.closeMessage()">
        Continue
    </button>
</div>

<script>
let currentStep = 1;

function nextStep() {
    document.getElementById('step' + currentStep).style.display = 'none';
    currentStep++;
    document.getElementById('step' + currentStep).style.display = 'block';
    
    aepBridge.logCustomEvent('step_completed', {step: currentStep - 1});
}
</script>
```

## Advanced Features

### Automatic Event Tracking

The bridge can automatically track when your message is displayed:

```javascript
// Optional: Listen for when the bridge is ready
window.addEventListener('aep.BridgeReady', function() {
    // Track that the message was displayed
    aepBridge.logCustomEvent('message_displayed', {
        timestamp: new Date().toISOString(),
        message_type: 'promotional'
    });
});
```

### Combining Actions

You can easily combine multiple bridge calls:

```html
<!-- Accept offer and close -->
<button onclick="
    aepBridge.logClick('offer_accepted');
    aepBridge.logCustomEvent('conversion', {value: 25.99});
    aepBridge.closeMessage();
">
    Buy Now - $25.99
</button>
```

## Standard Button ID Conventions

For consistency with other messaging platforms, use these standard button IDs:

- `"0"` - Primary button
- `"1"` - Secondary button  
- `"close"` - Close/dismiss button
- Custom strings for specific actions (e.g., `"newsletter_signup"`, `"learn_more"`)

```html
<button onclick="aepBridge.logClick('0')">Primary Action</button>
<button onclick="aepBridge.logClick('1')">Secondary Action</button>
<button onclick="aepBridge.logClick('learn_more')">Learn More</button>
```

## Custom Event Data

When logging custom events, you can include any JSON-serializable data:

```javascript
// Simple event
aepBridge.logCustomEvent('button_clicked');

// Event with data
aepBridge.logCustomEvent('product_viewed', {
    product_id: 'ABC123',
    category: 'electronics',
    price: 299.99
});

// Event with complex data
aepBridge.logCustomEvent('user_interaction', {
    action: 'scroll',
    position: window.scrollY,
    timestamp: Date.now(),
    metadata: {
        user_agent: navigator.userAgent,
        viewport: {
            width: window.innerWidth,
            height: window.innerHeight
        }
    }
});
```

## Migration from Legacy Code

If you're currently using direct WebKit message handlers, migration is simple:

**Old way:**
```javascript
if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.buttonClicked) {
    window.webkit.messageHandlers.buttonClicked.postMessage('action');
}
```

**New way:**
```javascript
aepBridge.logClick('action');
```

The bridge automatically handles all the availability checks and error cases for you.

## Adding Custom Bridge Methods (Advanced)

For advanced use cases, you can extend the bridge with custom methods in your native code:

```swift
import AEPMessaging

// In your message delegate
func shouldShowMessage(message: Showable) -> Bool {
    let fullscreenMessage = message as? FullscreenMessage
    let parentMessage = fullscreenMessage?.parent
    
    // Add a custom bridge method
    MessagingBridge.shared.addHandler("purchaseProduct", handler: { data, message in
        if let productData = data as? [String: Any],
           let productId = productData["productId"] as? String {
            // Handle the purchase
            processPurchase(productId: productId)
            message.track("purchase_initiated", withEdgeEventType: .interact)
        }
    }, forMessage: parentMessage!)
    
    return true
}
```

Then call it from JavaScript:
```javascript
// This will call your custom handler
window.webkit.messageHandlers.purchaseProduct.postMessage({
    productId: 'ABC123',
    quantity: 1
});
```

## Why This Approach is Better

The AEP JavaScript bridge eliminates common pain points:

- ❌ **No more** complex error handling in your HTML
- ❌ **No more** checking if handlers are available  
- ❌ **No more** worrying about timing issues
- ❌ **No more** try-catch blocks everywhere
- ✅ **Automatic** queuing of calls before bridge is ready
- ✅ **Automatic** error handling and logging
- ✅ **Simple** one-line method calls
- ✅ **Consistent** API across all messages

This means you can focus on creating great message experiences instead of dealing with integration complexity.

## Technical Notes

### Thread Safety and Timing

The JavaScript bridge automatically handles thread safety and timing concerns:

- **Main Thread Optimization**: JavaScript injection is automatically dispatched to the main thread only when necessary, avoiding double-dispatching for better performance.
- **WebView Initialization**: The bridge waits for the WebView to be fully initialized before injecting JavaScript, preventing timing-related issues.
- **Call Queuing**: If bridge methods are called before the bridge is ready, they're automatically queued and executed once initialization is complete.

This robust handling means you don't need to worry about these technical details in your HTML code. 