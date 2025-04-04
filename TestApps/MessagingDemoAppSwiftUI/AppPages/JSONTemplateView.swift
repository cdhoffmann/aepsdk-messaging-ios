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

import AEPCore
import AEPMessaging
import SwiftUI

@available(iOS 15.0, *)
struct JSONTemplateView: View {
    let cardsSurface = Surface(path: Constants.SurfaceName.CONTENT_CARD)
    @State private var showCard = false
    @State private var selectedExample = 0
    
    // Sample JSON for the content card
    private let sampleJSON = """
    {
      "type": "view",
      "style": {
        "flexDirection": "row",
        "padding": 16
      },
      "child": [
        {
          "type": "view",
          "child": [
            {
              "type": "image",
              "tyle": {
                "width": 90,
                "height": 90,
                "marginBottom": 12,
                "borderRadius": 8
              },
              "url": "https://analyticsindiamag.com/wp-content/uploads/2023/03/adobe.jpeg"
            }
          ]
        },
        {
          "type": "view",
          "style": {
            "flexDirection": "column",
            "padding": 14,
            "marginLeft": 12
          },
          "child": [
            {
              "type": "text",
              "tyle": {
                "fontSize": 18,
                "fontWeight": "400",
                "marginBottom": 12,
                "borderRadius": 8
              },
              "content": "Testing Adobe images"
            },
            {
              "type": "text",
              "tyle": {
                "fontSize": 16
              },
              "content": "This image is picked from web"
            }
          ]
        }
      ]
    }
    """
    
    // Another sample with a different layout
    private let alternativeJSON = """
    {
      "type": "view",
      "style": {
        "flexDirection": "column",
        "padding": 16,
        "backgroundColor": "gray"
      },
      "child": [
        {
          "type": "text",
          "tyle": {
            "fontSize": 24,
            "fontWeight": "bold",
            "marginBottom": 12
          },
          "content": "JSON Template Demo"
        },
        {
          "type": "view",
          "style": {
            "flexDirection": "row",
            "padding": 12,
            "backgroundColor": "white",
            "borderRadius": 8
          },
          "child": [
            {
              "type": "image",
              "tyle": {
                "width": 120,
                "height": 120,
                "borderRadius": 8
              },
              "url": "https://www.adobe.com/content/dam/cc/icons/Adobe_Corporate_Horizontal_Red_HEX.svg"
            },
            {
              "type": "view",
              "style": {
                "marginLeft": 16
              },
              "child": [
                {
                  "type": "text",
                  "tyle": {
                    "fontSize": 18,
                    "fontWeight": "semibold",
                    "marginBottom": 8
                  },
                  "content": "Adobe Experience Platform"
                },
                {
                  "type": "text",
                  "tyle": {
                    "fontSize": 14
                  },
                  "content": "Mobile SDK with flexible content card layouts"
                }
              ]
            }
          ]
        },
        {
          "type": "view",
          "style": {
            "flexDirection": "column",
            "marginTop": 16,
            "alignItems": "center"
          },
          "child": [
            {
              "type": "button",
              "label": "Learn More",
              "actionUrl": "https://developer.adobe.com/client-sdks/documentation/",
              "interactionId": "learn_more_button_clicked",
              "tyle": {
                "backgroundColor": "blue",
                "textColor": "white",
                "borderRadius": 8,
                "fontSize": 16,
                "fontWeight": "semibold",
                "paddingVertical": 12,
                "paddingHorizontal": 20,
                "marginTop": 8
              }
            },
            {
              "type": "button",
              "label": "Dismiss",
              "interactionId": "dismiss_button_clicked",
              "tyle": {
                "backgroundColor": "gray",
                "textColor": "white",
                "borderRadius": 8,
                "fontSize": 14,
                "paddingVertical": 8,
                "paddingHorizontal": 16,
                "marginTop": 8
              }
            }
          ]
        }
      ]
    }
    """
    
    // New sample with weights, borders, and content scale
    private let weightBorderJSON = """
    {
      "type": "view",
      "style": {
        "flexDirection": "column",
        "padding": 16,
        "borderWidth": 2,
        "borderColor": "#FF0000",
        "borderRadius": 8
      },
      "child": [
        {
          "type": "image",
          "style": {
            "width": -1,
            "height": 200,
            "borderRadius": 8,
            "contentScale": "crop"
          },
          "url": "https://analyticsindiamag.com/wp-content/uploads/2023/03/adobe.jpeg"
        },
        {
          "type": "view",
          "style": {
            "flexDirection": "row",
            "marginLeft": 12,
            "marginRight": 12,
            "marginTop": 12,
            "marginBottom": 12
          },
          "child": [
            {
              "type": "view",
              "style": {
                "flexDirection": "column",
                "weight": 1,
                "borderWidth": 1,
                "borderColor": "#0000FF",
                "borderRadius": 4,
                "padding": 8
              },
              "child": [
                {
                  "type": "text",
                  "style": {
                    "fontSize": 18,
                    "fontWeight": "400",
                    "marginBottom": 12
                  },
                  "content": "Title 1"
                },
                {
                  "type": "text",
                  "style": {
                    "fontSize": 16
                  },
                  "content": "Subtitle 1"
                }
              ]
            },
            {
              "type": "view",
              "style": {
                "flexDirection": "column",
                "weight": 1,
                "borderWidth": 1,
                "borderColor": "#00FF00",
                "borderRadius": 4,
                "marginLeft": 8,
                "padding": 8
              },
              "child": [
                {
                  "type": "text",
                  "style": {
                    "fontSize": 18,
                    "fontWeight": "400",
                    "marginBottom": 12
                  },
                  "content": "Title 2"
                },
                {
                  "type": "text",
                  "style": {
                    "fontSize": 16
                  },
                  "content": "Subtitle 2"
                }
              ]
            }
          ]
        },
        {
          "type": "button",
          "label": "Cross-Platform Design",
          "interactionId": "cross_platform_clicked",
          "style": {
            "backgroundColor": "#FF0000",
            "textColor": "white",
            "borderRadius": 8,
            "fontSize": 16,
            "fontWeight": "bold",
            "paddingVertical": 10,
            "paddingHorizontal": 16,
            "marginTop": 8
          }
        }
      ]
    }
    """
    
    // Create a mock ContentCardSchemaData instance for demo purposes
    private func createMockSchemaData(jsonString: String) -> ContentCardSchemaData? {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        
        // Create a dictionary with the required structure for schema data
        let schemaDict: [String: Any] = [
            "content": jsonObject,
            "contentType": "application/json",
            "meta": [
                "adobe": [
                    "template": "json-template" // Using the raw value for jsonTemplate case
                ]
            ]
        ]
        
        // Convert to Data and decode to ContentCardSchemaData
        guard let schemaJsonData = try? JSONSerialization.data(withJSONObject: schemaDict, options: []),
              let schemaData = try? JSONDecoder().decode(ContentCardSchemaData.self, from: schemaJsonData) else {
            return nil
        }
        
        return schemaData
    }
    
    var body: some View {
        ZStack {
            // Background
//            (isDarkMode ? Color.black : Color.white)
//                .edgesIgnoringSafeArea(.all)
//            
            VStack(spacing: 20) {
                Text("JSON Template Demo")
                    .font(.title)
                    .padding()
                    .foregroundColor(.black)
                
                // Toggles
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Content Card", isOn: $showCard)
                    
                    if showCard {
                        Picker("Example", selection: $selectedExample) {
                            Text("Basic Layout").tag(0)
                            Text("Button Example").tag(1)
                            Text("Weight & Borders").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Preview area
                if showCard {
                    ScrollView {
                        VStack(spacing: 20) {
                            switch selectedExample {
                            case 0:
                                // First example card
                                if let schemaData = createMockSchemaData(jsonString: sampleJSON),
                                   let template = JSONTemplate(schemaData) {
                                    template.view
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(radius: 5)
                                        .padding(.horizontal)
                                } else {
                                    Text("Error creating template")
                                        .foregroundColor(.red)
                                }
                            case 1:
                                // Second example card
                                if let schemaData = createMockSchemaData(jsonString: alternativeJSON),
                                   let template = JSONTemplate(schemaData) {
                                    template.view
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(radius: 5)
                                        .padding(.horizontal)
                                } else {
                                    Text("Error creating template")
                                        .foregroundColor(.red)
                                }
                            case 2:
                                // Third example card
                                if let schemaData = createMockSchemaData(jsonString: weightBorderJSON),
                                   let template = JSONTemplate(schemaData) {
                                    template.view
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(radius: 5)
                                        .padding(.horizontal)
                                } else {
                                    Text("Error creating template")
                                        .foregroundColor(.red)
                                }
                            default:
                                Text("Select an example")
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    Spacer()
                    Text("Toggle 'Show Content Card' to preview the JSON templates")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
    }
}

// Preview provider
@available(iOS 15.0, *)
struct JSONTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        JSONTemplateView()
    }
} 
