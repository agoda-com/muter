import Foundation
import SwiftSyntax

func swapFilePaths(for discoveredFiles: [String], using workingDirectoryPath: String) ->  [String: String] {
    var swapFilePathsByOriginalPath: [String: String] = [:]
    for filePath in discoveredFiles {
        let swapFilePath = FileUtilities.swapFilePath(forFileAt: filePath, using: workingDirectoryPath)
        swapFilePathsByOriginalPath[filePath] = swapFilePath
    }
    return swapFilePathsByOriginalPath
}

func mutationScore(from testResults: [TestSuiteResult]) -> Int {
    guard testResults.count >= 1 else {
        return -1
    }
    
    let numberOfFailures = Double(testResults.filter { $0 == .failed }.count)
    return Int((numberOfFailures / Double(testResults.count)) * 100.0)
}

protocol MutationTesterDelegate {
    func backupFile(at path: String)
    func runTestSuite() -> TestSuiteResult
    func restoreFile(at path: String) 
}

enum TestSuiteResult {
    case passed
    case failed
}

func performMutationTesting(using mutations: [SourceCodeMutation], delegate: MutationTesterDelegate) -> Int {
    
    let testSuiteResults: [TestSuiteResult] = mutations.map { mutation in
        delegate.backupFile(at: mutation.filePath)
        
        mutation.mutate()
        
        let result = delegate.runTestSuite()
        delegate.restoreFile(at: mutation.filePath)
        
        return result
    }
    
    return mutationScore(from: testSuiteResults)
}

struct Delegate: MutationTesterDelegate {
    let configuration: MuterConfiguration
    let swapFilePathsByOriginalPath: [String: String]
    
    func runTestSuite() -> TestSuiteResult {
        guard #available(OSX 10.13, *) else {
            print("muter is only supported on macOS 10.13 and higher")
            exit(1)
        }
        
        var testResult: TestSuiteResult!
        
        do {
            let url = URL(fileURLWithPath: configuration.testCommandExecutable)
            
            let process = try Process.run(url, arguments: configuration.testCommandArguments) {
                
                testResult = $0.terminationStatus > 0 ? .failed : .passed
                
                let testStatus = testResult == .failed ?
                    "\t✅ Mutation Test Passed " :
                "\t❌ Mutation Test Failed"
                
                printMessage("Test Suite finished running\n\(testStatus)")
            }
            
            process.waitUntilExit()
            
        } catch {
            printMessage("muter encountered an error running your test suite and can't continue\n\(error)")
            exit(1)
        }
        
        return testResult
    }
    
    func backupFile(at path: String) {
        printMessage("Backing up file at \(path)")
        let swapFilePath = swapFilePathsByOriginalPath[path]!
        FileUtilities.copySourceCode(fromFileAt: path, to: swapFilePath)
    }
    
    func restoreFile(at path: String) {
        printMessage("Restoring file at \(path)")
        let swapFilePath = swapFilePathsByOriginalPath[path]!
        FileUtilities.copySourceCode(fromFileAt: swapFilePath, to: path)
    }
}

