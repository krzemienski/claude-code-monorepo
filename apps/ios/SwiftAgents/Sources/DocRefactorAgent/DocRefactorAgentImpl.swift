import Foundation
import SwiftSyntax
import SwiftParser
import Markdown
import SwiftAgentsCore

/// Implementation of the Documentation Refactoring Agent
public actor DocRefactorAgentImpl: DocRefactorAgent {
    public let name = "DocRefactorAgent"
    public let version = "1.0.0"
    
    private let markdownProcessor: MarkdownProcessor
    private let swiftValidator: SwiftCodeValidator
    private let apiUpdater: APIDeprecationUpdater
    private var isInitialized = false
    
    public init() {
        self.markdownProcessor = MarkdownProcessor()
        self.swiftValidator = SwiftCodeValidator()
        self.apiUpdater = APIDeprecationUpdater()
    }
    
    // MARK: - Agent Protocol
    
    public func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize components
        try await swiftValidator.initialize()
        try await apiUpdater.loadDeprecationDatabase()
        
        isInitialized = true
        print("[\(name)] Initialized successfully")
    }
    
    public func shutdown() async throws {
        isInitialized = false
        print("[\(name)] Shutdown complete")
    }
    
    public func healthCheck() async -> Bool {
        return isInitialized && await swiftValidator.isHealthy()
    }
    
    // MARK: - DocRefactorAgent Protocol
    
    public func scanDocumentation(at path: URL) async throws -> [DocumentationFile] {
        guard isInitialized else {
            throw AgentError.notInitialized
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path.path) else {
            throw AgentError.pathNotFound(path.path)
        }
        
        var documentationFiles: [DocumentationFile] = []
        
        if path.hasDirectoryPath {
            // Scan directory recursively
            let enumerator = fileManager.enumerator(at: path, 
                                                   includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                                                   options: [.skipsHiddenFiles])
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "md" || fileURL.pathExtension == "markdown" {
                    if let docFile = try await processDocumentationFile(at: fileURL) {
                        documentationFiles.append(docFile)
                    }
                }
            }
        } else {
            // Process single file
            if let docFile = try await processDocumentationFile(at: path) {
                documentationFiles.append(docFile)
            }
        }
        
        return documentationFiles
    }
    
    public func extractCodeBlocks(from doc: DocumentationFile) -> [SwiftCodeBlock] {
        return markdownProcessor.extractCodeBlocks(from: doc.content, fileName: doc.path.lastPathComponent)
    }
    
    public func validateCodeBlock(_ block: SwiftCodeBlock) async throws -> ValidationResult {
        guard isInitialized else {
            throw AgentError.notInitialized
        }
        
        return try await swiftValidator.validate(block)
    }
    
    public func updateDeprecatedAPIs(in block: SwiftCodeBlock) -> SwiftCodeBlock {
        return apiUpdater.updateDeprecatedAPIs(in: block)
    }
    
    public func synchronizeWithImplementation() async throws {
        // This would compare documentation with actual Swift implementation
        // For now, we'll implement a basic version
        print("[\(name)] Synchronizing documentation with implementation...")
        
        // TODO: Implement full synchronization logic
        // 1. Parse Swift source files
        // 2. Extract documentation comments
        // 3. Compare with markdown documentation
        // 4. Generate sync report
    }
    
    public func generateMissingDocumentation(for path: URL) async throws -> [DocumentationFile] {
        guard isInitialized else {
            throw AgentError.notInitialized
        }
        
        // Parse Swift files and generate documentation
        let swiftFiles = try await findSwiftFiles(at: path)
        var generatedDocs: [DocumentationFile] = []
        
        for swiftFile in swiftFiles {
            if let documentation = try await generateDocumentation(for: swiftFile) {
                generatedDocs.append(documentation)
            }
        }
        
        return generatedDocs
    }
    
    // MARK: - Private Methods
    
    private func processDocumentationFile(at url: URL) async throws -> DocumentationFile? {
        let content = try String(contentsOf: url, encoding: .utf8)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let modificationDate = attributes[.modificationDate] as? Date ?? Date()
        
        let codeBlocks = markdownProcessor.extractCodeBlocks(from: content, fileName: url.lastPathComponent)
        
        return DocumentationFile(
            path: url,
            content: content,
            lastModified: modificationDate,
            codeBlocks: codeBlocks
        )
    }
    
    private func findSwiftFiles(at path: URL) async throws -> [URL] {
        var swiftFiles: [URL] = []
        let fileManager = FileManager.default
        
        if path.hasDirectoryPath {
            let enumerator = fileManager.enumerator(at: path,
                                                   includingPropertiesForKeys: [.isRegularFileKey],
                                                   options: [.skipsHiddenFiles])
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
        } else if path.pathExtension == "swift" {
            swiftFiles.append(path)
        }
        
        return swiftFiles
    }
    
    private func generateDocumentation(for swiftFile: URL) async throws -> DocumentationFile? {
        let sourceCode = try String(contentsOf: swiftFile, encoding: .utf8)
        let syntax = Parser.parse(source: sourceCode)
        
        // Extract documentation-worthy elements
        let visitor = DocumentationExtractor()
        visitor.walk(syntax)
        
        // Generate markdown documentation
        let markdown = visitor.generateMarkdown(for: swiftFile.lastPathComponent)
        
        if !markdown.isEmpty {
            let docPath = swiftFile.deletingPathExtension().appendingPathExtension("md")
            return DocumentationFile(
                path: docPath,
                content: markdown,
                lastModified: Date(),
                codeBlocks: []
            )
        }
        
        return nil
    }
}

// MARK: - Supporting Components

/// Processes markdown documents and extracts code blocks
class MarkdownProcessor {
    func extractCodeBlocks(from content: String, fileName: String) -> [SwiftCodeBlock] {
        let document = Document(parsing: content)
        var codeBlocks: [SwiftCodeBlock] = []
        var lineNumber = 1
        
        document.children.forEach { block in
            if let codeBlock = block as? CodeBlock,
               codeBlock.language?.lowercased() == "swift" {
                let block = SwiftCodeBlock(
                    code: codeBlock.code ?? "",
                    language: "swift",
                    lineNumber: lineNumber,
                    fileName: fileName,
                    metadata: extractMetadata(from: codeBlock)
                )
                codeBlocks.append(block)
            }
            lineNumber += countLines(in: block.debugDescription())
        }
        
        return codeBlocks
    }
    
    private func extractMetadata(from codeBlock: CodeBlock) -> CodeBlockMetadata {
        // Extract metadata from code block info string or preceding comments
        return CodeBlockMetadata()
    }
    
    private func countLines(in text: String) -> Int {
        return text.components(separatedBy: .newlines).count
    }
}

/// Validates Swift code blocks
class SwiftCodeValidator {
    private var isHealthy = true
    
    func initialize() async throws {
        // Initialize Swift compiler interface if needed
        isHealthy = true
    }
    
    func isHealthy() async -> Bool {
        return isHealthy
    }
    
    func validate(_ block: SwiftCodeBlock) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        var suggestions: [String] = []
        
        // Parse the code
        let syntax = Parser.parse(source: block.code)
        
        // Check for syntax errors
        if syntax.hasError {
            errors.append(ValidationError(
                message: "Syntax error in code block",
                severity: .critical
            ))
        }
        
        // Check for deprecated APIs
        let deprecationChecker = DeprecationChecker()
        deprecationChecker.walk(syntax)
        warnings.append(contentsOf: deprecationChecker.warnings)
        
        // Check for best practices
        let bestPracticeChecker = BestPracticeChecker()
        bestPracticeChecker.walk(syntax)
        suggestions.append(contentsOf: bestPracticeChecker.suggestions)
        
        let status: ValidationStatus = errors.isEmpty ? 
            (warnings.isEmpty ? .success : .warning) : .error
        
        return ValidationResult(
            codeBlock: block,
            status: status,
            errors: errors,
            warnings: warnings,
            suggestions: suggestions
        )
    }
}

/// Updates deprecated APIs in code blocks
class APIDeprecationUpdater {
    private var deprecationDatabase: [String: String] = [:]
    
    func loadDeprecationDatabase() async throws {
        // Load iOS API deprecation mappings
        deprecationDatabase = [
            "UIAlertView": "UIAlertController",
            "UIActionSheet": "UIAlertController",
            "UIWebView": "WKWebView",
            "NSURLConnection": "URLSession",
            // Add more deprecation mappings
        ]
    }
    
    func updateDeprecatedAPIs(in block: SwiftCodeBlock) -> SwiftCodeBlock {
        var updatedCode = block.code
        
        for (deprecated, replacement) in deprecationDatabase {
            updatedCode = updatedCode.replacingOccurrences(of: deprecated, with: replacement)
        }
        
        return SwiftCodeBlock(
            id: block.id,
            code: updatedCode,
            language: block.language,
            lineNumber: block.lineNumber,
            fileName: block.fileName,
            metadata: block.metadata
        )
    }
}

// MARK: - Syntax Visitors

class DocumentationExtractor: SyntaxVisitor {
    var declarations: [String] = []
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let className = node.name.text
        let modifiers = node.modifiers.map { $0.name.text }.joined(separator: " ")
        declarations.append("## Class: \(className)\n\nModifiers: \(modifiers)\n")
        return .visitChildren
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let functionName = node.name.text
        let parameters = node.signature.parameterClause.parameters.map { $0.firstName.text }.joined(separator: ", ")
        declarations.append("### Function: \(functionName)(\(parameters))\n")
        return .visitChildren
    }
    
    func generateMarkdown(for fileName: String) -> String {
        guard !declarations.isEmpty else { return "" }
        
        var markdown = "# Documentation for \(fileName)\n\n"
        markdown += "Auto-generated on \(Date())\n\n"
        markdown += declarations.joined(separator: "\n")
        return markdown
    }
}

class DeprecationChecker: SyntaxVisitor {
    var warnings: [ValidationWarning] = []
    
    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let typeName = node.name.text
        
        // Check for deprecated types
        let deprecatedTypes = ["UIAlertView", "UIActionSheet", "UIWebView"]
        if deprecatedTypes.contains(typeName) {
            warnings.append(ValidationWarning(
                message: "\(typeName) is deprecated",
                type: .deprecated
            ))
        }
        
        return .visitChildren
    }
}

class BestPracticeChecker: SyntaxVisitor {
    var suggestions: [String] = []
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for async/await usage
        if !node.signature.effectSpecifiers?.asyncSpecifier.isMissing ?? false {
            suggestions.append("Consider using async/await for asynchronous operations")
        }
        
        // Check for proper error handling
        if !node.signature.effectSpecifiers?.throwsSpecifier.isMissing ?? false {
            suggestions.append("Ensure proper error handling with do-catch blocks")
        }
        
        return .visitChildren
    }
}

// MARK: - Errors

enum AgentError: LocalizedError {
    case notInitialized
    case pathNotFound(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Agent not initialized"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }
}