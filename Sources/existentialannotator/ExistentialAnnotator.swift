import ArgumentParser
import Foundation
import SwiftSyntax
import SwiftParser

@main
struct RootDirectory: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(abstract: "existentialannotator marks all Swift existential types with `any` keyword.")
    }

    @Argument(help: "Top-level directory where Swift files are located", transform: {
        let string = $0 == "." ? FileManager.default.currentDirectoryPath : $0
        return URL(string: string)!
    })
    var rootDirectory: URL

    @Option(
        name: .shortAndLong,
        parsing: .upToNextOption,
        help: "Additional protocols that existentialannotator isn't able to find by itself because they might be defined in some closed source dependency"
    )
    var additionalProtocols: Array<String> = Array()

    private var commonlyUsedSystemProtocols: Set<String> {
        [
            "Codable",
            "Encodable",
            "Decodable",
            "NSFetchRequestResult",
            "NSCoding",
            "Error",
            "Decoder",
            "Encoder"
        ]
    }

    func run() throws {
        let processor = Processor()

        try processor.processFiles(
            startingAt: rootDirectory,
            inaccessibleProtocolDeclarations: commonlyUsedSystemProtocols.union(additionalProtocols)
        )
    }
}
