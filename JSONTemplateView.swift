// Sample JSON for the content card
private let sampleJSON = """
{
  "type": "view",
  "style": {
    "flexDirection": "row",
    "borderWidth": 2,
    "borderColor": "#FF0000",
    "borderRadius": 8,
    "backgroundColor": "#FFFFFF",
    "padding": 0
  },
  "children": [
    {
      "type": "view",
      "style": {
        "flexDirection": "column",
        "widthPercentage": "35%",
        "padding": 0
      },
      "children": [
        {
          "type": "image",
          "style": {
            "borderRadius": 6,
            "contentScale": "fill",
            "height": 80
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
        "marginLeft": 12,
        "flex": 1,
        "justifyContent": "center"
      },
      "children": [
        {
          "type": "text",
          "style": {
            "fontSize": 18,
            "fontWeight": "400",
            "marginBottom": 8
          },
          "content": "Testing Adobe images"
        },
        {
          "type": "text",
          "style": {
            "fontSize": 16
          },
          "content": "This image is picked from web"
        }
      ]
    }
  ]
}
""" 