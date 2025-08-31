import Foundation
import ArgumentParser
import SwiftAgentsCore

@main
struct DocRefactorAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doc-refactor",
        abstract: "iOS Documentation Refactoring Agent",
        discussion: "Automated agent for maintaining and updating iOS documentation",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Path to documentation directory or file")
    var path: String = "./docs"
    
    @Option(name: .shortAndLong, help: "Swift version (e.g., 5.10)")
    var swiftVersion: String = "5.10"
    
    @Option(name: .shortAndLong, help: "iOS deployment target (e.g., iOS16.0)")
    var deploymentTarget: String = "iOS16.0"
    
    @Flag(name: .long, help: "Fix deprecated APIs automatically")
    var fixDeprecated = false
    
    @Flag(name: .long, help: "Generate missing documentation")
    var generateMissing = false
    
    @Flag(name: .long, help: "Validate code blocks")
    var validate = true
    
    @Flag(name: .long, help: "Synchronize with implementation")
    var sync = false
    
    @Option(name: .shortAndLong, help: "Output directory for reports")
    var output: String = "./reports"
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose = false
    
    mutating func run() async throws {
        printHeader()
        
        // Initialize agent
        let agent = DocRefactorAgentImpl()
        
        do {
            print("🚀 Initializing Documentation Refactor Agent...")
            try await agent.initialize()
            
            // Check health
            let healthy = await agent.healthCheck()
            print("✅ Agent health check: \(healthy ? "PASSED" : "FAILED")")
            
            guard healthy else {
                throw ValidationError(message: "Agent health check failed")
            }
            
            // Scan documentation
            let docPath = URL(fileURLWithPath: path)
            print("\n📚 Scanning documentation at: \(docPath.path)")
            
            let startTime = Date()
            let documentationFiles = try await agent.scanDocumentation(at: docPath)
            print("✅ Found \(documentationFiles.count) documentation files")
            
            // Process each file
            var totalCodeBlocks = 0
            var validationResults: [ValidationResult] = []
            var updatedBlocks: [SwiftCodeBlock] = []
            
            for docFile in documentationFiles {
                if verbose {
                    print("\n📄 Processing: \(docFile.path.lastPathComponent)")
                }
                
                let codeBlocks = agent.extractCodeBlocks(from: docFile)
                totalCodeBlocks += codeBlocks.count
                
                if verbose {
                    print("  Found \(codeBlocks.count) Swift code blocks")
                }
                
                // Validate code blocks
                if validate {
                    for block in codeBlocks {
                        let result = try await agent.validateCodeBlock(block)
                        validationResults.append(result)
                        
                        if verbose {
                            printValidationResult(result)
                        }
                    }
                }
                
                // Fix deprecated APIs
                if fixDeprecated {
                    for block in codeBlocks {
                        let updated = agent.updateDeprecatedAPIs(in: block)
                        if updated.code != block.code {
                            updatedBlocks.append(updated)
                            if verbose {
                                print("  🔧 Updated deprecated APIs in block at line \(block.lineNumber)")
                            }
                        }
                    }
                }
            }
            
            // Generate missing documentation
            if generateMissing {
                print("\n📝 Generating missing documentation...")
                let generatedDocs = try await agent.generateMissingDocumentation(for: docPath)
                print("✅ Generated \(generatedDocs.count) new documentation files")
                
                // Save generated documentation
                for doc in generatedDocs {
                    try doc.content.write(to: doc.path, atomically: true, encoding: .utf8)
                    if verbose {
                        print("  💾 Saved: \(doc.path.lastPathComponent)")
                    }
                }
            }
            
            // Synchronize with implementation
            if sync {
                print("\n🔄 Synchronizing documentation with implementation...")
                try await agent.synchronizeWithImplementation()
                print("✅ Synchronization complete")
            }
            
            // Generate report
            let report = generateReport(
                documentationFiles: documentationFiles,
                totalCodeBlocks: totalCodeBlocks,
                validationResults: validationResults,
                updatedBlocks: updatedBlocks,
                executionTime: Date().timeIntervalSince(startTime)
            )
            
            // Save report
            let outputDir = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            
            let reportPath = outputDir.appendingPathComponent("doc-refactor-report-\(Date().ISO8601Format()).json")
            let reportData = try JSONEncoder().encode(report)
            try reportData.write(to: reportPath)
            
            print("\n📊 Report saved to: \(reportPath.path)")
            
            // Print summary
            printSummary(report)
            
            // Shutdown agent
            try await agent.shutdown()
            
        } catch {
            print("\n❌ Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func printHeader() {
        print("""
        ╔══════════════════════════════════════════════════╗
        ║     iOS Documentation Refactoring Agent v1.0     ║
        ╚══════════════════════════════════════════════════╝
        """)
    }
    
    private func printValidationResult(_ result: ValidationResult) {
        let statusEmoji: String
        switch result.status {
        case .success:
            statusEmoji = "✅"
        case .warning:
            statusEmoji = "⚠️"
        case .error:
            statusEmoji = "❌"
        case .skipped:
            statusEmoji = "⏭️"
        }
        
        print("    \(statusEmoji) Line \(result.codeBlock.lineNumber): \(result.status)")
        
        for error in result.errors {
            print("      ❌ \(error.message)")
        }
        
        for warning in result.warnings {
            print("      ⚠️  \(warning.message)")
        }
        
        for suggestion in result.suggestions {
            print("      💡 \(suggestion)")
        }
    }
    
    private func generateReport(
        documentationFiles: [DocumentationFile],
        totalCodeBlocks: Int,
        validationResults: [ValidationResult],
        updatedBlocks: [SwiftCodeBlock],
        executionTime: TimeInterval
    ) -> DocRefactorReport {
        let successCount = validationResults.filter { $0.status == .success }.count
        let warningCount = validationResults.filter { $0.status == .warning }.count
        let errorCount = validationResults.filter { $0.status == .error }.count
        
        let summary = ReportSummary(
            totalFiles: documentationFiles.count,
            totalCodeBlocks: totalCodeBlocks,
            successCount: successCount,
            warningCount: warningCount,
            errorCount: errorCount,
            coveragePercentage: Double(successCount) / Double(max(totalCodeBlocks, 1)) * 100
        )
        
        let recommendations = generateRecommendations(from: validationResults)
        
        return DocRefactorReport(
            timestamp: Date(),
            executionTime: executionTime,
            summary: summary,
            validationResults: validationResults,
            updatedBlocks: updatedBlocks,
            recommendations: recommendations
        )
    }
    
    private func generateRecommendations(from results: [ValidationResult]) -> [String] {
        var recommendations: [String] = []
        
        let deprecatedCount = results.flatMap { $0.warnings }.filter { $0.type == .deprecated }.count
        if deprecatedCount > 0 {
            recommendations.append("Update \(deprecatedCount) deprecated API references to iOS 16.0+ equivalents")
        }
        
        let performanceWarnings = results.flatMap { $0.warnings }.filter { $0.type == .performance }.count
        if performanceWarnings > 0 {
            recommendations.append("Address \(performanceWarnings) performance-related warnings in code examples")
        }
        
        let accessibilityWarnings = results.flatMap { $0.warnings }.filter { $0.type == .accessibility }.count
        if accessibilityWarnings > 0 {
            recommendations.append("Improve accessibility in \(accessibilityWarnings) code examples")
        }
        
        return recommendations
    }
    
    private func printSummary(_ report: DocRefactorReport) {
        print("""
        
        ═══════════════════════════════════════════════════
                          SUMMARY
        ═══════════════════════════════════════════════════
        📁 Documentation Files:    \(report.summary.totalFiles)
        📝 Code Blocks:           \(report.summary.totalCodeBlocks)
        ✅ Valid:                 \(report.summary.successCount)
        ⚠️  Warnings:              \(report.summary.warningCount)
        ❌ Errors:                \(report.summary.errorCount)
        📊 Coverage:              \(String(format: "%.1f%%", report.summary.coveragePercentage))
        ⏱️  Execution Time:        \(String(format: "%.2fs", report.executionTime))
        
        Recommendations:
        """)
        
        for (index, recommendation) in report.recommendations.enumerated() {
            print("  \(index + 1). \(recommendation)")
        }
        
        print("\n✨ Documentation refactoring complete!")
    }
}

// MARK: - Report Model

struct DocRefactorReport: Codable {
    let timestamp: Date
    let executionTime: TimeInterval
    let summary: ReportSummary
    let validationResults: [ValidationResult]
    let updatedBlocks: [SwiftCodeBlock]
    let recommendations: [String]
}

// Make existing models Codable for report serialization
extension ValidationResult: Codable {}
extension ValidationStatus: Codable {}
extension ValidationError: Codable {}
extension ValidationWarning: Codable {}
extension ErrorSeverity: Codable {}
extension WarningType: Codable {}
extension SwiftCodeBlock: Codable {}
extension CodeBlockMetadata: Codable {}
extension ReportSummary: Codable {}

// MARK: - Validation Error for CLI

struct ValidationError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}