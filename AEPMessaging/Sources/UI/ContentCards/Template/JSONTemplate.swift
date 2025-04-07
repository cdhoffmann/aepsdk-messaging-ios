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
            renderJSONComponent(json: jsonData)
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
    
    /// Recursively renders a JSON component
    @ViewBuilder
    private func renderJSONComponent(json: [String: Any], modifier: Modifier = Modifier()) -> some View {
        let type = json["type"] as? String ?? ""
        let style = json["style"] as? [String: Any] ?? [:]
        
        // Apply style modifiers to the base modifier
        let combinedModifier = modifier.apply(style: style)
        
        switch type.lowercased() {
        case "view":
            renderViewComponent(json: json, modifier: combinedModifier)
        case "text":
            renderTextComponent(json: json, modifier: combinedModifier)
        case "image":
            renderImageComponent(json: json, modifier: combinedModifier)
        case "button":
            renderButtonComponent(json: json, modifier: combinedModifier)
        default:
            Text("Unsupported component type: \(type)")
                .foregroundColor(.red)
                .applyModifier(combinedModifier)
        }
    }
    
    /// Renders a view component with its children
    @ViewBuilder
    private func renderViewComponent(json: [String: Any], modifier: Modifier) -> some View {
        let style = json["style"] as? [String: Any] ?? [:]
        let children = (json["children"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
        let flexDirection = style["flexDirection"] as? String ?? "column"
        
        switch flexDirection {
        case "row":
            HStack(alignment: getVerticalAlignment(style), spacing: 8) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, childJson in
                    let childStyle = childJson["style"] as? [String: Any] ?? [:]
                    let childModifier = self.createChildModifier(style: childStyle, isHorizontal: true)
                    let childType = childJson["type"] as? String ?? ""
                    
                    // For text components, allow them to take their natural space
                    if childType.lowercased() == "text" {
                        self.renderJSONComponent(json: childJson, modifier: childModifier)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    // For image components with explicit dimensions, ensure they stay fixed
                    else if childType.lowercased() == "image" && childStyle["width"] != nil {
                        self.renderJSONComponent(json: childJson, modifier: childModifier)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    // For other components, render normally
                    else {
                        self.renderJSONComponent(json: childJson, modifier: childModifier)
                    }
                }
            }
            .applyModifier(modifier)
            
        case "column":
            VStack(alignment: getHorizontalAlignment(style), spacing: 4) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, childJson in
                    let childStyle = childJson["style"] as? [String: Any] ?? [:]
                    let childModifier = self.createChildModifier(style: childStyle, isHorizontal: false)
                    self.renderJSONComponent(json: childJson, modifier: childModifier)
                }
            }
            .applyModifier(modifier)
            
        default:
            // Default to a Box-like layout using ZStack
            ZStack(alignment: getAlignment(style)) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, childJson in
                    let childStyle = childJson["style"] as? [String: Any] ?? [:]
                    let childModifier = self.createChildModifier(style: childStyle, isHorizontal: false)
                    self.renderJSONComponent(json: childJson, modifier: childModifier)
                }
            }
            .applyModifier(modifier)
        }
    }
    
    /// Renders a text component
    @ViewBuilder
    private func renderTextComponent(json: [String: Any], modifier: Modifier) -> some View {
        let content = json["content"] as? String ?? ""
        let style = json["style"] as? [String: Any] ?? [:]
        
        Text(content)
            .font(createFont(style: style))
            .foregroundColor(JSONTemplate.parseColor(style["color"]) ?? Color.primary)
            .multilineTextAlignment(getTextAlignment(style))
            .applyModifier(modifier)
    }
    
    /// Renders an image component
    @ViewBuilder
    private func renderImageComponent(json: [String: Any], modifier: Modifier) -> some View {
        let urlString = json["url"] as? String ?? ""
        let style = json["style"] as? [String: Any] ?? [:]
        
        // Extract explicit dimensions from style
        let widthValue = style["width"] as? Int
        let heightValue = style["height"] as? Int
        let fillWidth = style["fillWidth"] as? Bool ?? false
        
        // Calculate frame sizes for direct application
        let frameWidth: CGFloat? = widthValue != nil ? CGFloat(widthValue!) : (fillWidth ? .infinity : nil)
        let frameHeight: CGFloat? = heightValue != nil ? CGFloat(heightValue!) : nil
        
        let hasExplicitDimensions = widthValue != nil && heightValue != nil
        
        Group {
            if let url = URL(string: urlString) {
                renderImageWithURL(url, style: style, frameWidth: frameWidth, frameHeight: frameHeight, modifier: modifier)
            } else {
                renderPlaceholderImage(frameWidth: frameWidth, frameHeight: frameHeight, modifier: modifier)
            }
        }
        .if(hasExplicitDimensions) { $0.fixedSize(horizontal: true, vertical: true) }
    }
    
    /// Helper method to render an image from a URL
    @ViewBuilder
    private func renderImageWithURL(_ url: URL, style: [String: Any], frameWidth: CGFloat?, frameHeight: CGFloat?, modifier: Modifier) -> some View {
        let hasExplicitDimensions = frameWidth != nil && frameHeight != nil && frameWidth != .infinity && frameHeight != .infinity
        
        // Create a container to properly constrain the image
        VStack(spacing: 0) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    if hasExplicitDimensions {
                        // When exact dimensions are provided, fill the space completely
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: frameWidth, height: frameHeight)
                            .clipped()
                    } else {
                        // Otherwise use standard content scale and aspect ratio
                        image
                            .resizable()
                            .applyContentScale(style: style)
                            .applyAspectRatio(style: style)
                            .frame(width: frameWidth, height: frameHeight)
                    }
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .frame(width: frameWidth, height: frameHeight)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(width: frameWidth, height: frameHeight, alignment: .center)
        .background(modifier.background?.color)
        .applyBorderStyle(modifier.border)
        .applyPaddingAndMargin(padding: modifier.padding, margin: modifier.margin)
    }
    
    /// Helper method to render a placeholder image
    @ViewBuilder
    private func renderPlaceholderImage(frameWidth: CGFloat?, frameHeight: CGFloat?, modifier: Modifier) -> some View {
        let hasExplicitDimensions = frameWidth != nil && frameHeight != nil && frameWidth != .infinity && frameHeight != .infinity
        
        // Create a container to properly constrain the placeholder
        VStack(spacing: 0) {
            if hasExplicitDimensions {
                // When exact dimensions are provided, fill the space
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(.gray)
                    .frame(width: frameWidth, height: frameHeight)
                    .clipped()
            } else {
                // Standard placeholder
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .frame(width: frameWidth, height: frameHeight)
            }
        }
        .frame(width: frameWidth, height: frameHeight, alignment: .center)
        .background(modifier.background?.color)
        .applyBorderStyle(modifier.border)
        .applyPaddingAndMargin(padding: modifier.padding, margin: modifier.margin)
    }
    
    /// Renders a button component
    @ViewBuilder
    private func renderButtonComponent(json: [String: Any], modifier: Modifier) -> some View {
        let label = json["label"] as? String ?? "Button"
        let actionUrlString = json["actionUrl"] as? String
        let interactionId = json["interactionId"] as? String ?? "button_tapped"
        let style = json["style"] as? [String: Any] ?? [:]
        
        Button(action: {
            // Handle button tap by creating a track interaction
            if let actionUrl = actionUrlString.flatMap({ URL(string: $0) }) {
                self.eventHandler?.onInteract(interactionId: interactionId, actionURL: actionUrl)
            } else {
                self.eventHandler?.onInteract(interactionId: interactionId, actionURL: nil)
            }
        }) {
            Text(label)
                .font(createFont(style: style))
                .foregroundColor(JSONTemplate.parseColor(style["textColor"]) ?? .white)
                .lineLimit(1)
                .padding(.vertical, CGFloat(style["paddingVertical"] as? Int ?? 8))
                .padding(.horizontal, CGFloat(style["paddingHorizontal"] as? Int ?? 12))
        }
        .background(JSONTemplate.parseColor(style["backgroundColor"]) ?? .blue)
        .cornerRadius(CGFloat(style["borderRadius"] as? Int ?? 4))
        .applyModifier(modifier)
    }
    
    // MARK: - Helper Methods for Layout
    
    /// Gets the SwiftUI horizontal alignment from style
    private func getHorizontalAlignment(_ style: [String: Any]) -> HorizontalAlignment {
        let alignItems = style["alignItems"] as? String ?? ""
        switch alignItems.lowercased() {
        case "center":
            return .center
        case "flex-start", "start", "left":
            return .leading
        case "flex-end", "end", "right":
            return .trailing
        default:
            return .leading
        }
    }
    
    /// Gets the SwiftUI vertical alignment from style
    private func getVerticalAlignment(_ style: [String: Any]) -> VerticalAlignment {
        let alignItems = style["alignItems"] as? String ?? ""
        switch alignItems.lowercased() {
        case "center":
            return .center
        case "flex-start", "start", "top":
            return .top
        case "flex-end", "end", "bottom":
            return .bottom
        default:
            return .center
        }
    }
    
    /// Gets the alignment for ZStack
    private func getAlignment(_ style: [String: Any]) -> Alignment {
        let alignItems = style["alignItems"] as? String ?? ""
        switch alignItems.lowercased() {
        case "center":
            return .center
        case "topstart", "topleft":
            return .topLeading
        case "top":
            return .top
        case "topend", "topright":
            return .topTrailing
        case "start", "left":
            return .leading
        case "end", "right":
            return .trailing
        case "bottomstart", "bottomleft":
            return .bottomLeading
        case "bottom":
            return .bottom
        case "bottomend", "bottomright":
            return .bottomTrailing
        default:
            return .center
        }
    }
    
    /// Gets the text alignment from style
    private func getTextAlignment(_ style: [String: Any]) -> TextAlignment {
        let textAlign = style["textAlign"] as? String ?? ""
        switch textAlign.lowercased() {
        case "center":
            return .center
        case "right", "end":
            return .trailing
        case "left", "start":
            return .leading
        default:
            return .leading
        }
    }
    
    /// Creates a child modifier with appropriate layout constraints
    private func createChildModifier(style: [String: Any], isHorizontal: Bool) -> Modifier {
        var modifier = Modifier()
        
        // Apply flex/weight if specified
        if let flex = style["flex"] as? Int, flex > 0 {
            let flexValue = Double(flex)
            if isHorizontal {
                modifier = modifier.weight(flexValue)
            } else {
                modifier = modifier.weight(flexValue)
            }
        }
        
        // Apply alignment if specified
        if let justifyContent = style["justifyContent"] as? String {
            if isHorizontal {
                switch justifyContent.lowercased() {
                case "center":
                    modifier = modifier.alignVertically(.center)
                case "flex-start", "top", "start":
                    modifier = modifier.alignVertically(.top)
                case "flex-end", "bottom", "end":
                    modifier = modifier.alignVertically(.bottom)
                default:
                    break
                }
            } else {
                switch justifyContent.lowercased() {
                case "center":
                    modifier = modifier.alignHorizontally(.center)
                case "flex-start", "left", "start":
                    modifier = modifier.alignHorizontally(.leading)
                case "flex-end", "right", "end":
                    modifier = modifier.alignHorizontally(.trailing)
                default:
                    break
                }
            }
        }
        
        return modifier
    }
    
    // MARK: - Helper Methods for Styling
    
    /// Creates a font from style properties
    private func createFont(style: [String: Any]) -> Font {
        let size = CGFloat(style["fontSize"] as? Int ?? 14)
        let weightString = style["fontWeight"] as? String ?? ""
        
        let weight: Font.Weight
        switch weightString {
        case "bold", "700":
            weight = .bold
        case "semibold", "600":
            weight = .semibold
        case "medium", "500":
            weight = .medium
        case "regular", "400":
            weight = .regular
        case "light", "300":
            weight = .light
        case "thin", "100":
            weight = .thin
        case "heavy", "800":
            weight = .heavy
        case "black", "900":
            weight = .black
        default:
            weight = .regular
        }
        
        return Font.system(size: size, weight: weight)
    }
    
    /// Parses a color string to SwiftUI Color
    static func parseColor(_ value: Any?) -> Color? {
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
    
    // Parse aspectRatio from string format like "100/300"
    private func parseAspectRatio(_ aspectRatioStr: String) -> CGFloat? {
        let components = aspectRatioStr.components(separatedBy: "/")
        if components.count == 2,
           let width = Double(components[0]),
           let height = Double(components[1]),
           width > 0, height > 0 {
            return CGFloat(width / height)
        }
        return nil
    }
}

// MARK: - View Modifiers and Extensions

@available(iOS 15.0, *)
struct Modifier {
    var frame: FrameModifier?
    var padding: PaddingModifier?
    var margin: MarginModifier?
    var background: BackgroundModifier?
    var border: BorderModifier?
    var alignment: AlignmentModifier?
    var weight: WeightModifier?
    
    init() {}
    
    func apply(style: [String: Any]) -> Modifier {
        var newModifier = self
        
        // Preserve existing explicit dimensions if the current modifier already has them
        let existingWidth = self.frame?.width
        let existingHeight = self.frame?.height
        
        // Apply frame modifiers - use existing dimensions if they're not null and not in the new style
        let styleWidth = style["width"] as? Int
        let styleHeight = style["height"] as? Int
        
        newModifier.frame = FrameModifier(
            width: styleWidth ?? existingWidth,
            height: styleHeight ?? existingHeight,
            fillWidth: style["fillWidth"] as? Bool ?? (self.frame?.fillWidth ?? false),
            fillHeight: style["fillHeight"] as? Bool ?? (self.frame?.fillHeight ?? false)
        )
        
        // Apply padding modifiers
        newModifier.padding = PaddingModifier(
            all: style["padding"] as? Int,
            vertical: style["paddingVertical"] as? Int,
            horizontal: style["paddingHorizontal"] as? Int
        )
        
        // Apply margin modifiers
        newModifier.margin = MarginModifier(
            left: style["marginLeft"] as? Int,
            right: style["marginRight"] as? Int,
            top: style["marginTop"] as? Int,
            bottom: style["marginBottom"] as? Int
        )
        
        // Apply background modifiers
        if let backgroundColorStr = style["backgroundColor"] as? String {
            if let backgroundColor = JSONTemplate.parseColor(backgroundColorStr) {
                newModifier.background = BackgroundModifier(color: backgroundColor)
            }
        }
        
        // Apply border modifiers
        let borderWidth = style["borderWidth"] as? Int ?? 0
        if borderWidth > 0 {
            let borderColor = style["borderColor"].flatMap { JSONTemplate.parseColor($0) } ?? Color.black
            let borderRadius = CGFloat(style["borderRadius"] as? Int ?? 0)
            
            newModifier.border = BorderModifier(
                width: CGFloat(borderWidth),
                color: borderColor,
                radius: borderRadius
            )
        } else if let borderRadius = style["borderRadius"] as? Int, borderRadius > 0 {
            newModifier.border = BorderModifier(
                width: 0,
                color: .clear,
                radius: CGFloat(borderRadius)
            )
        }
        
        return newModifier
    }
    
    func weight(_ value: Double) -> Modifier {
        var newModifier = self
        newModifier.weight = WeightModifier(value: value)
        return newModifier
    }
    
    func alignHorizontally(_ alignment: HorizontalAlignment) -> Modifier {
        var newModifier = self
        if newModifier.alignment == nil {
            newModifier.alignment = AlignmentModifier()
        }
        newModifier.alignment?.horizontal = alignment
        return newModifier
    }
    
    func alignVertically(_ alignment: VerticalAlignment) -> Modifier {
        var newModifier = self
        if newModifier.alignment == nil {
            newModifier.alignment = AlignmentModifier()
        }
        newModifier.alignment?.vertical = alignment
        return newModifier
    }
}

@available(iOS 15.0, *)
struct FrameModifier {
    let width: Int?
    let height: Int?
    let fillWidth: Bool
    let fillHeight: Bool
}

@available(iOS 15.0, *)
struct PaddingModifier {
    let all: Int?
    let vertical: Int?
    let horizontal: Int?
}

@available(iOS 15.0, *)
struct MarginModifier {
    let left: Int?
    let right: Int?
    let top: Int?
    let bottom: Int?
}

@available(iOS 15.0, *)
struct BackgroundModifier {
    let color: Color
}

@available(iOS 15.0, *)
struct BorderModifier {
    let width: CGFloat
    let color: Color
    let radius: CGFloat
}

@available(iOS 15.0, *)
struct AlignmentModifier {
    var horizontal: HorizontalAlignment?
    var vertical: VerticalAlignment?
}

@available(iOS 15.0, *)
struct WeightModifier {
    let value: Double
}

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func applyModifier(_ modifier: Modifier) -> some View {
        self
            // Apply frame
            .then { view in
                if let frame = modifier.frame {
                    // If explicit width and height are provided, they take precedence
                    if let width = frame.width, let height = frame.height {
                        return AnyView(view.frame(width: CGFloat(width), height: CGFloat(height)))
                    } else if let width = frame.width {
                        if frame.fillHeight {
                            return AnyView(view.frame(minWidth: CGFloat(width), maxHeight: .infinity))
                        } else {
                            return AnyView(view.frame(width: CGFloat(width)))
                        }
                    } else if let height = frame.height {
                        if frame.fillWidth {
                            return AnyView(view.frame(maxWidth: .infinity, minHeight: CGFloat(height)))
                        } else {
                            return AnyView(view.frame(height: CGFloat(height)))
                        }
                    } else if frame.fillWidth && frame.fillHeight {
                        return AnyView(view.frame(maxWidth: .infinity, maxHeight: .infinity))
                    } else if frame.fillWidth {
                        return AnyView(view.frame(maxWidth: .infinity))
                    } else if frame.fillHeight {
                        return AnyView(view.frame(maxHeight: .infinity))
                    }
                }
                return AnyView(view)
            }
            // Apply padding
            .then { view in
                if let padding = modifier.padding {
                    if let all = padding.all {
                        return AnyView(view.padding(EdgeInsets(top: CGFloat(all), leading: CGFloat(all), bottom: CGFloat(all), trailing: CGFloat(all))))
                    }
                    
                    var edgeInsets = EdgeInsets()
                    if let vertical = padding.vertical {
                        edgeInsets.top = CGFloat(vertical)
                        edgeInsets.bottom = CGFloat(vertical)
                    }
                    if let horizontal = padding.horizontal {
                        edgeInsets.leading = CGFloat(horizontal)
                        edgeInsets.trailing = CGFloat(horizontal)
                    }
                    
                    if edgeInsets != EdgeInsets() {
                        return AnyView(view.padding(edgeInsets))
                    }
                }
                return AnyView(view)
            }
            // Apply margin
            .then { view in
                if let margin = modifier.margin {
                    var edgeInsets = EdgeInsets()
                    if let left = margin.left {
                        edgeInsets.leading = CGFloat(left)
                    }
                    if let right = margin.right {
                        edgeInsets.trailing = CGFloat(right)
                    }
                    if let top = margin.top {
                        edgeInsets.top = CGFloat(top)
                    }
                    if let bottom = margin.bottom {
                        edgeInsets.bottom = CGFloat(bottom)
                    }
                    
                    if edgeInsets != EdgeInsets() {
                        return AnyView(view.padding(edgeInsets))
                    }
                }
                return AnyView(view)
            }
            // Apply background
            .then { view in
                if let background = modifier.background {
                    return AnyView(view.background(background.color))
                }
                return AnyView(view)
            }
            // Apply border
            .then { view in
                if let border = modifier.border {
                    if border.width > 0 {
                        let shape = RoundedRectangle(cornerRadius: border.radius)
                        return AnyView(
                            view.overlay(
                                shape.strokeBorder(border.color, lineWidth: border.width)
                            )
                            .clipShape(shape)
                        )
                    } else if border.radius > 0 {
                        return AnyView(view.clipShape(RoundedRectangle(cornerRadius: border.radius)))
                    }
                }
                return AnyView(view)
            }
            // Apply alignment and weight are handled differently in each container
    }
    
    @ViewBuilder
    func then<Result: View>(_ transform: (Self) -> Result) -> some View {
        transform(self)
    }
    
    /// Applies content scale
    @ViewBuilder
    func applyContentScale(style: [String: Any]) -> some View {
        let contentScale = style["contentScale"] as? String ?? "fit"
        
        switch contentScale.lowercased() {
        case "fill":
            self.scaledToFill()
        case "fit", "none":
            self.scaledToFit()
        case "crop":
            self.scaledToFill().clipped()
        default:
            self.scaledToFit()
        }
    }
    
    /// Applies aspect ratio
    @ViewBuilder
    func applyAspectRatio(style: [String: Any]) -> some View {
        if let aspectRatioStr = style["aspectRatio"] as? String {
            let components = aspectRatioStr.components(separatedBy: "/")
            if components.count == 2,
               let width = Double(components[0]),
               let height = Double(components[1]),
               width > 0, height > 0 {
                let ratio = width / height
                self.aspectRatio(ratio, contentMode: .fit)
            } else {
                self
            }
        } else {
            self
        }
    }
    
    /// Applies border and corner radius styling
    @ViewBuilder
    func applyBorderStyle(_ border: BorderModifier?) -> some View {
        if let border = border {
            if border.width > 0 {
                let shape = RoundedRectangle(cornerRadius: border.radius)
                self.overlay(shape.strokeBorder(border.color, lineWidth: border.width))
                    .clipShape(shape)
            } else if border.radius > 0 {
                self.clipShape(RoundedRectangle(cornerRadius: border.radius))
            } else {
                self
            }
        } else {
            self
        }
    }
    
    /// Applies padding and margin in one go
    @ViewBuilder
    func applyPaddingAndMargin(padding: PaddingModifier?, margin: MarginModifier?) -> some View {
        self.padding(calculateEdgeInsets(from: padding))
            .padding(calculateEdgeInsets(from: margin))
    }
    
    /// Calculates EdgeInsets from a PaddingModifier
    private func calculateEdgeInsets(from padding: PaddingModifier?) -> EdgeInsets {
        guard let padding = padding else { return EdgeInsets() }
        
        if let all = padding.all {
            return EdgeInsets(top: CGFloat(all), leading: CGFloat(all), bottom: CGFloat(all), trailing: CGFloat(all))
        }
        
        var edgeInsets = EdgeInsets()
        if let vertical = padding.vertical {
            edgeInsets.top = CGFloat(vertical)
            edgeInsets.bottom = CGFloat(vertical)
        }
        if let horizontal = padding.horizontal {
            edgeInsets.leading = CGFloat(horizontal)
            edgeInsets.trailing = CGFloat(horizontal)
        }
        
        return edgeInsets
    }
    
    /// Calculates EdgeInsets from a MarginModifier
    private func calculateEdgeInsets(from margin: MarginModifier?) -> EdgeInsets {
        guard let margin = margin else { return EdgeInsets() }
        
        var edgeInsets = EdgeInsets()
        if let left = margin.left {
            edgeInsets.leading = CGFloat(left)
        }
        if let right = margin.right {
            edgeInsets.trailing = CGFloat(right)
        }
        if let top = margin.top {
            edgeInsets.top = CGFloat(top)
        }
        if let bottom = margin.bottom {
            edgeInsets.bottom = CGFloat(bottom)
        }
        
        return edgeInsets
    }
    
    // Helper for conditional modifiers
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 
