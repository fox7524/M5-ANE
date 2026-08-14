import XCTest
@testable import UltimateLLMStudio

class BackendManagerTests: XCTestCase {
    func testServerStartAndStop() {
        let manager = BackendManager.shared
        XCTAssertFalse(manager.isServerRunning)
        
        manager.startLLMServer(modelPath: "TestModel.gguf")
        
        // Wait a bit for the async task to kick off
        let exp = expectation(description: "Server starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(manager.isServerRunning)
            XCTAssertTrue(manager.serverLogs.contains("TestModel.gguf"))
            
            manager.stopLLMServer()
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2.0)
        XCTAssertFalse(manager.isServerRunning)
    }
}
