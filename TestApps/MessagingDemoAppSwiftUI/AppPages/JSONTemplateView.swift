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
struct JSONTemplateView: View{
    let cardsSurface = Surface(path: Constants.SurfaceName.CONTENT_CARD)
    @State private var showCard = false
    @State private var selectedExample = 0
    @State private var savedCards: [JSONTemplate] = []
    @State private var showLoadingIndicator: Bool = false
    @State private var viewLoaded: Bool = false
    
    // Sample JSON for the content card
    private let largeImageJSON = """
    {
      "type": "view",
      "style": {
        "flexDirection": "column",
        "padding": 16,
        "borderWidth": 2,
        "borderColor": "#FF0000",
        "borderRadius": 8
      },
      "children": [
        {
          "type": "image",
          "style": {
            "fillWidth": true,
            "aspectRatio": "300/100",
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
          "children": [
            {
              "type": "view",
              "style": {
                "flexDirection": "column",
                "flex": 1
              },
              "children": [
                {
                  "type": "text",
                  "style": {
                    "fontSize": 18,
                    "fontWeight": "400",
                    "marginBottom": 12,
                    "borderRadius": 8
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
                "flex": 1
              },
              "children": [
                {
                  "type": "text",
                  "style": {
                    "fontSize": 18,
                    "fontWeight": "400",
                    "borderRadius": 8
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
        }
      ]
    }
    """
    
    // Another sample with a different layout
    private let imageOnlyJSON = """

    {
      "type": "view",
      "style": {
        "flexDirection": "box",
        "alignItems": "center",
        "padding": 16,
        "borderWidth": 2,
        "borderColor": "#FF0000",
        "borderRadius": 8
      },
      "children": [
        {
          "type": "image",
          "style": {
            "fillWidth": true,
            "borderRadius": 8,
            "contentScale": "crop"
          },
          "url": "https://analyticsindiamag.com/wp-content/uploads/2023/03/adobe.jpeg"
        },
        {
          "type": "text",
          "style": {
            "fontSize": 24,
            "fontWeight": "bold",
            "color": "#FFFFFF",
            "padding": 8,
            "borderRadius": 4,
            "justifyContent": "bottom"
          },
          "content": "This is an image only template"
        }
      ]
    }
    """
    
    // Create a mock ContentCardSchemaData instance from a JSON string
    private func createMockSchemaData(jsonString: String) -> ContentCardSchemaData? {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        
        return createSchemaDataFromDictionary(jsonObject)
    }
    
    // Create a mock ContentCardSchemaData instance from a JSON dictionary
    private func createSchemaDataFromDictionary(_ jsonDict: [String: Any]) -> ContentCardSchemaData? {
        // Create a dictionary with the required structure for schema data
        let schemaDict: [String: Any] = [
            "content": jsonDict,
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
            VStack(spacing: 20) {
                Text("JSON Template Demo")
                    .font(.title)
                    .padding()
                    .foregroundColor(.black)
                
                // Toggles and controls
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Content Card", isOn: $showCard)
                    
                    if showCard {
                        Picker("Example", selection: $selectedExample) {
                            Text("Large Image").tag(0)
                            Text("Server Cards").tag(1)
                            Text("Image Only").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.top, 8)
                        
                        if selectedExample == 1 {
                            HStack {
                                Button("Download Cards") {
                                    downloadCards()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Preview area
                ZStack {
                    if showCard {
                        ScrollView {
                            VStack(spacing: 20) {
                                switch selectedExample {
                                case 0:
                                    // First example card (static)
                                    if let schemaData = createMockSchemaData(jsonString: largeImageJSON),
                                       let template = JSONTemplate(schemaData) {
                                        template.view
                                            .background(Color.white)
                                            .padding(.horizontal)
                                    } else {
                                        Text("Error creating template")
                                            .foregroundColor(.red)
                                    }
                                case 1:
                                    // Server propositions (dynamic)
                                    if savedCards.isEmpty {
                                        Text("No cards available. Tap 'Download Cards' to get content cards from the server.")
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                    } else {
                                        ForEach(savedCards) { card in
                                            card.view
                                                .background(Color.white)
//                                                .cornerRadius(12)
//                                                .shadow(radius: 5)
                                                .padding(.horizontal)
                                        }
                                    }
                                case 2:
                                    // Weight and borders example (static)
                                    if let schemaData = createMockSchemaData(jsonString: imageOnlyJSON),
                                       let template = JSONTemplate(schemaData) {
                                        template.view
                                            .background(Color.white)
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
                    
                    if showLoadingIndicator {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }
                }
                
                Spacer()
                
                // Instructions
                Text("This tab demonstrates the new JSONTemplate which allows for flexible content card layouts defined in JSON format.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.gray)
            }
        }
        .onAppear() {
            if !viewLoaded {
                viewLoaded = true
                if selectedExample == 1 {
                    downloadCards()
                }
            }
        }
    }
    
    // MARK: - Card Management
    
    
    func downloadCards() {
        showLoadingIndicator = true
        Messaging.updatePropositionsForSurfaces([cardsSurface]) { success in
            if success {
                print("Successfully updated propositions")
                // Get propositions directly and create JSONTemplate views
                Messaging.getPropositionsForSurfaces([self.cardsSurface]) { retrievedPropositions, _ in
                    
                    // Process the propositions to create JSON templates
                    guard let propositions = retrievedPropositions?[self.cardsSurface] else { return }
                    for prop in propositions {
                        for item in prop.items {
                            guard let jsonDict = item.jsonContentDictionary, let schemaData = self.createSchemaDataFromDictionary(jsonDict) else { break }
                            if let template = JSONTemplate(schemaData) {
                                self.savedCards.append(template)
                            }
                        }
                    }
                    self.showLoadingIndicator = false
                }
            } else {
                print("Failed to update propositions")
                self.showLoadingIndicator = false
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
