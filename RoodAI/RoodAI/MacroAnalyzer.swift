import Foundation
import UIKit

enum AnalyzerError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case http(status: Int, message: String)
    case refused
    case truncated
    case emptyResponse
    case notFood(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Anthropic API key in Settings first."
        case .imageEncodingFailed:
            return "Couldn't process that photo. Try another one."
        case let .http(status, message):
            return "Request failed (\(status)): \(message)"
        case .refused:
            return "The request was declined. Try a different photo."
        case .truncated:
            return "The response was cut off. Please try again."
        case .emptyResponse:
            return "Got an empty response. Please try again."
        case let .notFood(reason):
            return reason.isEmpty ? "No food detected in this photo." : reason
        }
    }
}

/// Sends a meal photo to the Claude Messages API and decodes a structured macro breakdown.
///
/// Swift has no official Anthropic SDK, so this talks to the REST API directly.
struct MacroAnalyzer {
    var apiKey: String
    var model = "claude-opus-5-5"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let systemPrompt = """
    You are a registered dietitian estimating nutrition from food photos. \
    Identify every distinct food and drink item visible, estimate each portion size \
    using visual cues (plate size, utensils, packaging, hands), and estimate its \
    calories and macronutrients in grams. Use standard nutrition database values \
    (e.g. USDA) for the estimated portion. If a packaged product's label is legible, \
    use it. Account for visible cooking oils, sauces and dressings. Give a short, \
    human-friendly meal_name. Use notes for key assumptions in one or two sentences. \
    If the photo contains no food or drink, set is_food to false, return an empty \
    items list, and explain briefly in notes.
    """

    private static let numberField: [String: Any] = ["type": "number"]

    private static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["is_food", "meal_name", "items", "confidence", "notes"],
        "properties": [
            "is_food": ["type": "boolean"],
            "meal_name": ["type": "string"],
            "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
            "notes": ["type": "string"],
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["name", "portion", "calories", "protein_g", "carbs_g", "fat_g", "fiber_g", "sugar_g"],
                    "properties": [
                        "name": ["type": "string"],
                        "portion": ["type": "string"],
                        "calories": numberField,
                        "protein_g": numberField,
                        "carbs_g": numberField,
                        "fat_g": numberField,
                        "fiber_g": numberField,
                        "sugar_g": numberField,
                    ],
                ],
            ],
        ],
    ]

    func analyze(image: UIImage, note: String) async throws -> MealAnalysis {
        guard !apiKey.isEmpty else { throw AnalyzerError.missingAPIKey }
        guard let jpeg = image.resized(maxDimension: 1568).jpegData(compressionQuality: 0.8) else {
            throw AnalyzerError.imageEncodingFailed
        }

        var prompt = "Break down the calories and macros for this meal."
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            prompt += "\n\nExtra context from the user: \(trimmed)"
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            // Re-run on a recommended fallback model if a safety classifier declines.
            "fallbacks": "default",
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": Self.schema],
            ],
            "system": Self.systemPrompt,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": jpeg.base64EncodedString(),
                        ],
                    ],
                    ["type": "text", "text": prompt],
                ],
            ]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw AnalyzerError.http(
                status: status,
                message: apiError?.error.message ?? String(decoding: data, as: UTF8.self)
            )
        }

        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        switch message.stopReason {
        case "refusal": throw AnalyzerError.refused
        case "max_tokens": throw AnalyzerError.truncated
        default: break
        }

        // Thinking blocks may precede the answer; the JSON lives in the text block.
        guard let json = message.content.first(where: { $0.type == "text" })?.text,
              let jsonData = json.data(using: .utf8) else {
            throw AnalyzerError.emptyResponse
        }

        let analysis = try JSONDecoder().decode(MealAnalysis.self, from: jsonData)
        guard analysis.isFood else { throw AnalyzerError.notFood(analysis.notes) }
        return analysis
    }
}

private struct MessageResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    let content: [Block]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

extension UIImage {
    /// Downscales so the longest side is at most `maxDimension` points; Claude doesn't benefit from larger images.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
