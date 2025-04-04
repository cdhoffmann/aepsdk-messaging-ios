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
public class JSONTemplate: BaseTemplate, ContentCardTemplate {
    
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
    
    /// Renders a view component with its children
    @ViewBuilder
    private func renderViewComponent(_ json: [String: Any]) -> some View {
        let style = json["style"] as? [String: Any] ?? [:]
        let children = json["child"] as? [[String: Any]] ?? []
        
        // Extract style properties
        let flexDirection = style["flexDirection"] as? String ?? "column"
        let padding = CGFloat(style["padding"] as? Int ?? 0)
        
        // Create container based on flex direction
        Group {
            if flexDirection == "row" {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<children.count, id: \.self) { index in
                        let childJson = children[index]
                        let childStyle = childJson["style"] as? [String: Any] ?? [:]
                        let childWeight = childStyle["weight"] as? Int ?? 0
                        
                        if childWeight > 0 {
                            // If weight is specified, use flexible frame with weight as layout priority
                            self.renderJSON(json: childJson)
                                .frame(maxWidth: .infinity)
                                .layoutPriority(Double(childWeight))
                        } else {
                            // Otherwise render normally
                            self.renderJSON(json: childJson)
                        }
                    }
                }
                .padding(padding)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<children.count, id: \.self) { index in
                        let childJson = children[index]
                        let childStyle = childJson["style"] as? [String: Any] ?? [:]
                        let childWeight = childStyle["weight"] as? Int ?? 0
                        
                        if childWeight > 0 {
                            // If weight is specified, use flexible frame with weight as layout priority
                            self.renderJSON(json: childJson)
                                .frame(maxHeight: .infinity)
                                .layoutPriority(Double(childWeight))
                        } else {
                            // Otherwise render normally
                            self.renderJSON(json: childJson)
                        }
                    }
                }
                .padding(padding)
            }
        }
        .modifier(ViewStyleModifier(style: style))
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
        let width = styleWithFallback["width"] as? Int ?? 0
        
        // Handle special case for width: -1 (match parent)
        let frameWidth: CGFloat? = width == -1 ? .infinity : (width > 0 ? CGFloat(width) : nil)
        
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
            .modifier(ImageStyleModifier(style: styleWithFallback, frameWidth: frameWidth))
        } else {
            Image(systemName: "photo")
                .foregroundColor(.gray)
                .modifier(ImageStyleModifier(style: styleWithFallback, frameWidth: frameWidth))
        }
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
            
            let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let blue = Double(rgbValue & 0x0000FF) / 255.0
            
            return Color(red: red, green: green, blue: blue)
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

/// Style modifier for image components
@available(iOS 15.0, *)
struct ImageStyleModifier: ViewModifier {
    let style: [String: Any]
    let frameWidth: CGFloat?
    
    func body(content: Content) -> some View {
        content
            .frame(
                width: frameWidth,
                height: style["height"] as? CGFloat ?? nil
            )
            .cornerRadius(CGFloat(style["borderRadius"] as? Int ?? 0))
            .padding(.leading, CGFloat(style["marginLeft"] as? Int ?? 0))
            .padding(.trailing, CGFloat(style["marginRight"] as? Int ?? 0))
            .padding(.top, CGFloat(style["marginTop"] as? Int ?? 0))
            .padding(.bottom, CGFloat(style["marginBottom"] as? Int ?? 0))
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
