@preconcurrency import Vision
import UIKit

struct RedactionMark: Identifiable, Sendable {
    let id = UUID()
    let x: Double
    let y: Double
}

enum PrivacyImageProcessor {
    static func automaticallyRedact(data: Data) async -> Data {
        let detectedBoxes = await Task.detached(priority: .userInitiated) {
            detectionBoxes(in: data)
        }.value

        var boxes = detectedBoxes
        boxes.append(CGRect(x: 0, y: 0.89, width: 1, height: 0.11))
        return render(data: data, normalizedBoxes: boxes)
    }

    static func manuallyRedact(data: Data, marks: [RedactionMark]) -> Data {
        let boxes = marks.map { mark in
            CGRect(x: mark.x - 0.12, y: (1 - mark.y) - 0.032, width: 0.24, height: 0.064)
        }
        return render(data: data, normalizedBoxes: boxes)
    }

    nonisolated private static func detectionBoxes(in data: Data) -> [CGRect] {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return [] }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([faceRequest, textRequest])

        let faceBoxes = faceRequest.results?.map(\.boundingBox) ?? []
        let headerTextBoxes = textRequest.results?
            .map(\.boundingBox)
            .filter { $0.maxY > 0.84 } ?? []
        return faceBoxes + headerTextBoxes
    }

    private static func render(data: Data, normalizedBoxes: [CGRect]) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        let output = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            context.cgContext.setFillColor(UIColor.systemGray.cgColor)

            for box in normalizedBoxes {
                let clamped = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
                let rect = CGRect(
                    x: clamped.minX * image.size.width,
                    y: (1 - clamped.maxY) * image.size.height,
                    width: clamped.width * image.size.width,
                    height: clamped.height * image.size.height
                ).insetBy(dx: -6, dy: -4)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: min(14, rect.height / 2))
                path.fill()
            }
        }
        return output.jpegData(compressionQuality: 0.9) ?? data
    }
}
