import Progress
import Foundation

final class PlainTextReporter: Reporter {
    private var numberOfMutationPoints: Int = 0
    private var progressBar: ProgressBar!

    func launched() {
        print(
            """
            
            \("""
             _____       _
            |     | _ _ | |_  ___  ___
            | | | || | ||  _|| -_||  _|
            |_|_|_||___||_|  |___||_|
            """.green)
            
            Automated mutation testing for Swift
            
            You are running version \("\(version)".bold)
            
            Want help? Have suggestions? Want to get involved?
             ↳ https://github.com/muter-mutation-testing/muter/issues
            +------------------------------------------------+
            
            """
        )
    }
    
    func projectCopyStarted() {
        print("Copying your project to a temporary directory for testing...")
    }
    
    func projectCopyFinished(destinationPath: String) {
        print("Finished copying your project to a temporary directory for mutation testing:\n\(destinationPath.bold)\n")
    }
    
    func projectCoverageDiscoveryStarted() {
        print("Running tests with coverage enabled to determine which files to mutate")
    }
    
    func projectCoverageDiscoveryFinished(success: Bool) {
        guard success == false else { return }
        
        print(
            """
            Gathering coverage failed.
            Proceeding with mutation testing anyway.
            Pass --skip-coverage argument to disable this step
            """
        )
    }
    
    func sourceFileDiscoveryStarted() {
        printMessage("Discovering Swift files which Muter will analyze...")
    }
    
    func sourceFileDiscoveryFinished(sourceFileCandidates: [String]) {
        let fileNames = sourceFileCandidates
            .map(URL.init(fileURLWithPath:))
            .map { $0.lastPathComponent }.joined(separator: "\n").bold

        print("In total, Muter discovered \(sourceFileCandidates.count) Swift files\n\n\(fileNames)")
    }
    
    func mutationPointDiscoveryStarted() {
        printMessage("Analyzing source files to find mutants which can be inserted into your project...")
    }
    
    func mutationPointDiscoveryFinished(mutationPoints: [MutationPoint]) {
        numberOfMutationPoints = mutationPoints.count
        let numberOfFiles = mutationPoints.map { $0.fileName }.deduplicated().count
        
        print("In total, Muter discovered \(mutationPoints.count) mutants in \(numberOfFiles) files\n")
        for (fileName, mutantCount) in mutationPointsByFileName(from: mutationPoints) {
            print("\(fileName) (\(mutantCount) mutants)".bold)
        }
    }
    
    private func mutationPointsByFileName(from mutationPoints: [MutationPoint]) -> [String: Int] {
        var result: [String: Int] = [:]
        
        for mutationPoint in mutationPoints {
            if result[mutationPoint.fileName] == nil {
                result[mutationPoint.fileName] = 1
                continue
            }
            
            result[mutationPoint.fileName]! += 1
        }
        return result
    }
    
    func mutationTestingStarted() {
        printMessage("Mutation testing will now begin\nRunning your test suite to determine a baseline for mutation testing...")
    }
    
    func newMutationTestLogAvailable(mutationTestLog: MutationTestLog) {
        if mutationTestLog.mutationPoint == nil {
            print("""
            Determined baseline for mutation testing
            Muter is now going to apply each mutant one at a time and run your test suite for each mutant
            After this step, Muter will generate a report detailing the efficacy of your test suite
            This step may take a while
            

            """)
            progressBar = ProgressBar(
                count: numberOfMutationPoints,
                configuration: [
                    ProgressString(string: "Inserting mutant"),
                    ProgressOneIndexed(),
                    ProgressString(string: "\nPercentage complete: "),
                    ProgressPercent(),
                    ColoredProgressBarLine(barLength: 50),
                    SimpleTimeEstimate(
                        initialEstimate: Double(mutationTestLog.remainingMutationPointsCount!) * mutationTestLog.timePerBuildTestCycle!),
                ],
                printer: ProgressBarMultilineTerminalPrinter(numberOfLines: 2)
            )

            progressBar.next()
        } else {
            progressBar.next()
        }
    }
    
    func mutationTestingFinished(mutationTestOutcome outcome: MutationTestOutcome) {
        printMessage(
            report(from: MuterTestReport(from: outcome))
        )
    }
    
    func removeTempDirectoryStarted(path: String) {
        print("Removing temporary directory at path: \(path)....\n")
    }
    
    func removeTempDirectoryFinished() {
        print("Finished to remove temporary directory.\n")
    }
    
    func report(from report: MuterTestReport) -> String {
        let finishedRunningMessage = "Muter finished running!\n\nHere's your test report:\n\n"
        let appliedMutationsMessage = """
        --------------------------
        Applied Mutation Operators
        --------------------------
        
        These are all of the ways that Muter introduced changes into your code.
        
        In total, Muter introduced \(report.totalAppliedMutationOperators) mutants in \(report.fileReports.count) files.
        
        \(generateAppliedMutationOperatorsCLITable(from: report.fileReports).description)
        
        
        """
        
        let coloredGlobalScore = coloredMutationScore(for: report.globalMutationScore, appliedTo: "\(report.globalMutationScore)%")
        let projectCoverageMessage = coverageMessage(from: report)
        let mutationScoreMessage = "Mutation Score of Test Suite: ".bold + "\(coloredGlobalScore)"
        let mutationScoresMessage = """
        --------------------
        Mutation Test Scores
        --------------------
        
        These are the mutation scores for your test suite, as well as the files that had mutants introduced into them.
        
        Mutation scores ignore build errors.
        
        Of the \(report.totalAppliedMutationOperators) mutants introduced into your code, your test suite killed \(report.numberOfKilledMutants).
        \(mutationScoreMessage)
        \(projectCoverageMessage)
        
        \(generateMutationScoresCLITable(from: report.fileReports).description)
        """
        
        return finishedRunningMessage + appliedMutationsMessage + mutationScoresMessage
    }
    
    private func printMessage(_ message: String) {
        print("+-----------------+")
        print(message)
    }
    
    private func coverageMessage(from report: MuterTestReport) -> String {
        report.projectCodeCoverage.map { "Code Coverage of your project: \($0)%" }
            ?? "Muter could not gather coverage data from your project"
    }
}
