import Foundation

public class ModelScanner {
    public init() {}
    
    public func scanForGGUFModels(in path: String) -> [String] {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default
        var ggufFiles: [String] = []
        
        guard let enumerator = fileManager.enumerator(atPath: expandedPath) else {
            return []
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".gguf") {
                ggufFiles.append(file)
            }
        }
        
        return ggufFiles
    }
}
