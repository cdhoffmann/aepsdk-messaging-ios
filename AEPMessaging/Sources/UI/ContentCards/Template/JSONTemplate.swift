/*
 Copyright 2024 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

#if canImport(SwiftUI)
    import Combine
    import SwiftUI
#endif

import AEPServices
import Foundation

/// A template that renders content cards based on a flexible JSON format
@available(iOS 15.0, *)
public class JSONTemplate: BaseTemplate, ContentCardTemplate, Identifiable {
    
    // MARK: - Properties
    public var templateType: ContentCardTemplateType = .jsonTemplate
    
    /// The JSON data to render
    private let jsonData: [String: Any]
    
    // MARK: - ContentCardTemplate
    
    public var view: some View {
        buildCardView {
            renderJSON(json: jsonData)
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Initialization
    // TODO: - Public for iteration, change to internal 
    public override init?(_ schemaData: ContentCardSchemaData) {
        guard schemaData.contentType == .applicationJson,
              let content = schemaData.content as? [String: Any] else {
            return nil
        }
        
        self.jsonData = content
        super.init(schemaData)
    }
    
    // MARK: - JSON Rendering
    
    /// Recursively renders a JSON object as a SwiftUI view
    @ViewBuilder
    private func renderJSON(json: [String: Any]) -> some View {
        let type = json["type"] as? String ?? ""
        
        switch type {
        case "view":
            renderViewComponent(json)
        case "text":
            renderTextComponent(json)
        case "image":
            renderImageComponent(json)
        case "button":
            renderButtonComponent(json)
        default:
            Text("Unsupported component type: \(type)")
                .foregroundColor(.red)
        }
    }
    
    /// Renders a child component with appropriate layout properties
    @ViewBuilder
    private func renderChild(childJson: [String: Any], isHorizontal: Bool) -> some View {
        let childStyle = childJson["style"] as? [String: Any] ?? [:]
        
        // Support both "weight" (original) and "flex" (new format)
        let childWeight = childStyle["flex"] as? Int ?? childStyle["weight"] as? Int ?? 0
        
        // Support "widthPercentage" as a string percentage
        let widthPercentage = childStyle["widthPercentage"] as? String
        
        if let percentStr = widthPercentage, percentStr.hasSuffix("%"),
           let percentValue = Double(percentStr.dropLast()) {
            // Set width as a fraction of the container
            renderJSON(json: childJson)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(WidthPercentageModifier(percentage: percentValue))
        } else if childWeight > 0 {
            // If weight/flex is specified, use flexible frame with weight as layout priority
            if isHorizontal {
                renderJSON(json: childJson)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(Double(childWeight))
            } else {
                renderJSON(json: childJson)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(Double(childWeight))
            }
        } else {
            // Otherwise render normally
            renderJSON(json: childJson)
        }
    }
    
    /// Renders a view component with its children
    @ViewBuilder
    private func renderViewComponent(_ json: [String: Any]) -> some View {
        let style = json["style"] as? [String: Any] ?? [:]
        // Support both "child" (original) and "children" (new format)
        let children = (json["children"] as? [Any])?.compactMap { $0 as? [String: Any] } ??
                      (json["child"] as? [[String: Any]] ?? [])
        
        // Extract style properties
        let flexDirection = style["flexDirection"] as? String ?? "column"
        let padding = CGFloat(style["padding"] as? Int ?? 0)
        let justifyContent = style["justifyContent"] as? String ?? "start"
        
        // Map justifyContent value to SwiftUI alignment
        let alignment: HorizontalAlignment = mapJustifyContentToAlignment(justifyContent)
        let verticalAlignment: VerticalAlignment = mapJustifyContentToVerticalAlignment(justifyContent)
        
        // Create container based on flex direction
        Group {
            if flexDirection == "row" {
                HStack(alignment: verticalAlignment, spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.offset) { index, childJson in
                        self.renderChild(childJson: childJson, isHorizontal: true)
                    }
                }
                .padding(padding)
            } else {
                // Handle "box" as a column layout (for compatibility)
                VStack(alignment: alignment, spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.offset) { index, childJson in
                        self.renderChild(childJson: childJson, isHorizontal: false)
                    }
                }
                .padding(padding)
            }
        }
        .modifier(ViewStyleModifier(style: style))
    }
    
    // Maps justifyContent values to SwiftUI horizontal alignment
    private func mapJustifyContentToAlignment(_ justifyContent: String) -> HorizontalAlignment {
        switch justifyContent.lowercased() {
        case "start", "left":
            return .leading
        case "center":
            return .center
        case "end", "right":
            return .trailing
        case "top", "bottom":
            // For vertical justification in horizontal layouts, default to leading
            return .leading
        default:
            return .leading
        }
    }
    
    // Maps justifyContent values to SwiftUI vertical alignment
    private func mapJustifyContentToVerticalAlignment(_ justifyContent: String) -> VerticalAlignment {
        switch justifyContent.lowercased() {
        case "start", "left", "right":
            // For horizontal justification in vertical layouts, default to top
            return .top
        case "center":
            return .center
        case "end":
            return .bottom
        case "top":
            return .top
        case "bottom":
            return .bottom
        default:
            return .top
        }
    }
    
    /// Renders a text component
    @ViewBuilder
    private func renderTextComponent(_ json: [String: Any]) -> some View {
        let content = json["content"] as? String ?? ""
        let style = json["style"] as? [String: Any] ?? [:]
        // Fix for the field name typo in the example JSON
        let styleWithFallback = json["tyle"] as? [String: Any] ?? style
        
        Text(content)
            .modifier(TextStyleModifier(style: styleWithFallback))
    }
    
    /// Renders an image component
    @ViewBuilder
    private func renderImageComponent(_ json: [String: Any]) -> some View {
        let urlString = json["url"] as? String ?? ""
        let style = json["style"] as? [String: Any] ?? [:]
        // Fix for the field name typo in the example JSON
        let styleWithFallback = json["tyle"] as? [String: Any] ?? style
        let contentScale = styleWithFallback["contentScale"] as? String ?? "fit"
        
        // Support multiple width formats:
        // 1. Direct integer width
        // 2. Width as percentage string
        // 3. Special case for width: -1 (match parent)
        var frameWidth: CGFloat? = nil
        
        if let width = styleWithFallback["width"] as? Int {
            frameWidth = width == -1 ? .infinity : (width > 0 ? CGFloat(width) : nil)
        } else if let widthPercentage = styleWithFallback["widthPercentage"] as? String,
                  widthPercentage.hasSuffix("%"),
                  let percentValue = Double(widthPercentage.dropLast()) {
            // We'll handle percentage width with a modifier
            frameWidth = nil
        }
        
        // Get height similarly
        let height = styleWithFallback["height"] as? Int
        let frameHeight: CGFloat? = height != nil ? CGFloat(height!) : nil
        
        let imageView = Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .apply(contentScale: contentScale)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: frameWidth, height: frameHeight)
                .cornerRadius(CGFloat(styleWithFallback["borderRadius"] as? Int ?? 0))
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .frame(width: frameWidth, height: frameHeight)
                    .cornerRadius(CGFloat(styleWithFallback["borderRadius"] as? Int ?? 0))
            }
        }
        
        return imageView
            .padding(.leading, CGFloat(styleWithFallback["marginLeft"] as? Int ?? 0))
            .padding(.trailing, CGFloat(styleWithFallback["marginRight"] as? Int ?? 0))
            .padding(.top, CGFloat(styleWithFallback["marginTop"] as? Int ?? 0))
            .padding(.bottom, CGFloat(styleWithFallback["marginBottom"] as? Int ?? 0))
            .modifier(ImagePercentageModifier(style: styleWithFallback))
    }
    
    /// Renders a button component
    @ViewBuilder
    private func renderButtonComponent(_ json: [String: Any]) -> some View {
        let label = json["label"] as? String ?? "Button"
        let actionUrlString = json["actionUrl"] as? String
        let interactionId = json["interactionId"] as? String ?? "button_tapped"
        let style = json["style"] as? [String: Any] ?? [:]
        // Fix for the field name typo in the example JSON
        let styleWithFallback = json["tyle"] as? [String: Any] ?? style
        
        Button(action: {
            // Handle button tap by creating a track interaction
            if let actionUrl = actionUrlString.flatMap({ URL(string: $0) }) {
                self.eventHandler?.onInteract(interactionId: interactionId, actionURL: actionUrl)
            } else {
                self.eventHandler?.onInteract(interactionId: interactionId, actionURL: nil)
            }
        }) {
            Text(label)
                .modifier(ButtonLabelModifier(style: styleWithFallback))
        }
        .modifier(ButtonStyleModifier(style: styleWithFallback))
    }
}

// MARK: - Style Modifiers

/// Modifier for handling width percentage values
@available(iOS 15.0, *)
struct WidthPercentageModifier: ViewModifier {
    let percentage: Double
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width * percentage / 100.0)
        }
    }
}

/// Style modifier for view components
@available(iOS 15.0, *)
struct ViewStyleModifier: ViewModifier {
    let style: [String: Any]
    
    func body(content: Content) -> some View {
        content
            .background(parseColor(style["backgroundColor"]))
            .cornerRadius(CGFloat(style["borderRadius"] as? Int ?? 0))
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(style["borderRadius"] as? Int ?? 0))
                    .stroke(
                        parseColor(style["borderColor"]) ?? Color.clear,
                        lineWidth: CGFloat(style["borderWidth"] as? Int ?? 0)
                    )
            )
            .padding(.leading, CGFloat(style["marginLeft"] as? Int ?? 0))
            .padding(.trailing, CGFloat(style["marginRight"] as? Int ?? 0))
            .padding(.top, CGFloat(style["marginTop"] as? Int ?? 0))
            .padding(.bottom, CGFloat(style["marginBottom"] as? Int ?? 0))
    }
    
    private func parseColor(_ value: Any?) -> Color? {
        // Handle hex color strings
        if let hexString = value as? String, hexString.hasPrefix("#") {
            let hex = hexString.dropFirst()
            var rgbValue: UInt64 = 0
            Scanner(string: String(hex)).scanHexInt64(&rgbValue)
            
            // Handle different hex formats (#RGB, #RRGGBB, #RRGGBBAA)
            var red: Double = 0
            var green: Double = 0
            var blue: Double = 0
            var alpha: Double = 1.0
            
            switch hex.count {
            case 3: // #RGB
                red = Double(((rgbValue & 0xF00) >> 8) * 17) / 255.0
                green = Double(((rgbValue & 0x0F0) >> 4) * 17) / 255.0
                blue = Double((rgbValue & 0x00F) * 17) / 255.0
            case 6: // #RRGGBB
                red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
                green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
                blue = Double(rgbValue & 0x0000FF) / 255.0
            case 8: // #RRGGBBAA
                red = Double((rgbValue & 0xFF000000) >> 24) / 255.0
                green = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
                blue = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
                alpha = Double(rgbValue & 0x000000FF) / 255.0
            default:
                // Default to black if invalid format
                return .black
            }
            
            return Color(red: red, green: green, blue: blue, opacity: alpha)
        }
        
        // Handle named colors
        guard let colorString = value as? String else {
            return nil
        }
        
        // Simple color parsing - could be extended for more colors or hex values
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
}

/// Style modifier for text components
@available(iOS 15.0, *)
struct TextStyleModifier: ViewModifier {
    let style: [String: Any]
    
    func body(content: Content) -> some View {
        content
            .font(createFont())
            .foregroundColor(parseColor(style["color"]))
            .padding(.leading, CGFloat(style["marginLeft"] as? Int ?? 0))
            .padding(.trailing, CGFloat(style["marginRight"] as? Int ?? 0))
            .padding(.top, CGFloat(style["marginTop"] as? Int ?? 0))
            .padding(.bottom, CGFloat(style["marginBottom"] as? Int ?? 0))
    }
    
    private func createFont() -> Font {
        let size = CGFloat(style["fontSize"] as? Int ?? 14)
        let weight = parseFontWeight(style["fontWeight"])
        
        return Font.system(size: size, weight: weight)
    }
    
    private func parseFontWeight(_ value: Any?) -> Font.Weight {
        guard let weightString = value as? String else {
            return .regular
        }
        
        switch weightString {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        case "thin": return .thin
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    private func parseColor(_ value: Any?) -> Color? {
        guard let colorString = value as? String else {
            return nil
        }
        
        // Simple color parsing - could be extended for more colors or hex values
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
}

/// Style modifier for image components with percentage-based width
@available(iOS 15.0, *)
struct ImagePercentageModifier: ViewModifier {
    let style: [String: Any]
    
    func body(content: Content) -> some View {
        Group {
            if let widthPercentage = style["widthPercentage"] as? String,
               widthPercentage.hasSuffix("%"),
               let percentValue = Double(widthPercentage.dropLast()) {
                GeometryReader { geometry in
                    content
                        .frame(width: geometry.size.width * percentValue / 100.0)
                }
            } else {
                content
            }
        }
    }
}

/// Style modifier for button label
@available(iOS 15.0, *)
struct ButtonLabelModifier: ViewModifier {
    let style: [String: Any]
    
    func body(content: Content) -> some View {
        content
            .font(createFont())
            .foregroundColor(parseColor(style["textColor"]) ?? .white)
            .lineLimit(1)
            .padding(.vertical, CGFloat(style["paddingVertical"] as? Int ?? 8))
            .padding(.horizontal, CGFloat(style["paddingHorizontal"] as? Int ?? 12))
    }
    
    private func createFont() -> Font {
        let size = CGFloat(style["fontSize"] as? Int ?? 14)
        let weight = parseFontWeight(style["fontWeight"])
        
        return Font.system(size: size, weight: weight)
    }
    
    private func parseFontWeight(_ value: Any?) -> Font.Weight {
        guard let weightString = value as? String else {
            return .regular
        }
        
        switch weightString {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        case "thin": return .thin
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    private func parseColor(_ value: Any?) -> Color? {
        guard let colorString = value as? String else {
            return nil
        }
        
        // Simple color parsing - could be extended for more colors or hex values
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
}

/// Style modifier for button components
@available(iOS 15.0, *)
struct ButtonStyleModifier: ViewModifier {
    let style: [String: Any]
    
    func body(content: Content) -> some View {
        content
            .background(parseColor(style["backgroundColor"]) ?? .blue)
            .cornerRadius(CGFloat(style["borderRadius"] as? Int ?? 4))
            .padding(.leading, CGFloat(style["marginLeft"] as? Int ?? 0))
            .padding(.trailing, CGFloat(style["marginRight"] as? Int ?? 0))
            .padding(.top, CGFloat(style["marginTop"] as? Int ?? 0))
            .padding(.bottom, CGFloat(style["marginBottom"] as? Int ?? 8))
    }
    
    private func parseColor(_ value: Any?) -> Color? {
        guard let colorString = value as? String else {
            return nil
        }
        
        // Simple color parsing - could be extended for more colors or hex values
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
}

// MARK: - View Extensions

@available(iOS 15.0, *)
extension View {
    /// Applies the appropriate content scale mode to an image
    @ViewBuilder
    func apply(contentScale: String) -> some View {
        switch contentScale.lowercased() {
        case "fill":
            self.scaledToFill()
        case "fit":
            self.scaledToFit()
        case "crop":
            self.scaledToFill()
                .clipped()
        case "none":
            self
        default:
            self.scaledToFit() // Default to fit
        }
    }
} 
