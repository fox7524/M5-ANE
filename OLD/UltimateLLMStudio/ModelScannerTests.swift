import XCTest
@testable import UltimateLLMStudio

final class ModelScannerTests: XCTestCase {
    func testScanningModels() {
        let scanner = ModelScanner()
        // We assume there's at least one model in the local LM Studio cache or we mock the path
        let models = scanner.scanForGGUFModels(in: "~/.cache/lm-studio/models")
        XCTAssertNotNil(models)
    }
}
