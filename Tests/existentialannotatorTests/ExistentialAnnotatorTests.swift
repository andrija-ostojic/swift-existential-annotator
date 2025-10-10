@testable import existentialannotator
import SwiftParser
import XCTest

final class ExistentialAnnotatorTests: XCTestCase {
    func testThatExistentialIsAnnotated() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private var article: Article!

          init(repository: ArticleRepository) {
            self.repository = repository
          }
        }
        """#
        let sut = Annotator(protocols: ["ArticleRepository"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: any ArticleRepository
          private var article: Article!

          init(repository: any ArticleRepository) {
            self.repository = repository
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatMultipleExistentialsAreAnnotated() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#
        let sut = Annotator(protocols: ["ArticleRepository", "FeatureFlagsProvider"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: any ArticleRepository
          private let featureFlags: any FeatureFlagsProvider
          private var article: Article!

          init(repository: any ArticleRepository, featureFlags: any FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatSourceIsUntouchedWhenThereAreNoDetectedExistentials() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#
        let sut = Annotator(protocols: [])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsParameterInPresenceOfDefaultArgument() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private var survey: Survey
            private let useCase: SurveyUseCase
            @Published var isLoading = false

            init(survey: Survey,
                 useCase: SurveyUseCase = DefaultSurveyUseCase()) {
                self.survey = survey
                self.useCase = useCase
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private var survey: Survey
            private let useCase: any SurveyUseCase
            @Published var isLoading = false

            init(survey: Survey,
                 useCase: any SurveyUseCase = DefaultSurveyUseCase()) {
                self.survey = survey
                self.useCase = useCase
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedWithLazyProperty() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsOptional() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: SurveyDelegate?
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: (any SurveyDelegate)?
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsImplicitlyUnwrappedOptional() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsOptionalInFunctionParameter() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            func setDelegate(delegate: SurveyDelegate?) {
                print(delegate)
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            func setDelegate(delegate: (any SurveyDelegate)?) {
                print(delegate)
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsImplicitlyUnwrappedOptionalInFunctionParameter() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            func setDelegate(delegate: SurveyDelegate!) {
                print(delegate)
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            func setDelegate(delegate: (any SurveyDelegate)!) {
                print(delegate)
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenCastingOnAssignment() throws {
        let exampleFile = #"""
        struct MyType {
            var isSent: Bool {
                get {
                    return true
                }
                set {
                    let newValue = newValue as NSCoding
                    print(newValue)
                }
            }
        }
        """#

        let sut = Annotator(protocols: ["NSCoding"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            var isSent: Bool {
                get {
                    return true
                }
                set {
                    let newValue = newValue as any NSCoding
                    print(newValue)
                }
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenCastingArgumentInMethodCall() throws {
        let exampleFile = #"""
        struct MyType {
            init() {
                let string = ""
                open(string as! Survey)
            }

            func open(_ survey: Survey) {}
        }
        """#

        let sut = Annotator(protocols: ["Survey"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            init() {
                let string = ""
                open(string as! any Survey)
            }

            func open(_ survey: any Survey) {}
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatSourceIsUntouchedWhenThereIsEnumCaseNamedAsDetectedProtocol() throws {
        let exampleFile = #"""
                    static func announce(_ message: String, sender: String) {
                        let content = NotificationContent(title: nil,
                                                          message: message as String,
                                                          category: Messages.Category.FastChat,
                                                          sender: sender)
                    }
        """#

        let sut = Annotator(protocols: ["FastChat"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
                    static func announce(_ message: String, sender: String) {
                        let content = NotificationContent(title: nil,
                                                          message: message as String,
                                                          category: Messages.Category.FastChat,
                                                          sender: sender)
                    }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatSourceIsUntouchedWhenMethodNameContainsProtocolName() throws {
        let exampleFile = #"""
            static var expirationDate: Date? {
                set {
                    guard let expirationDate = newValue else { return }
                    setNSCoding(value: expirationDate as NSCoding, forKey: "expirationDate")
                }
                get {
                    getNSCoding("expirationDate") as? Date
                }
            }
        """#

        let sut = Annotator(protocols: ["NSCoding"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
            static var expirationDate: Date? {
                set {
                    guard let expirationDate = newValue else { return }
                    setNSCoding(value: expirationDate as any NSCoding, forKey: "expirationDate")
                }
                get {
                    getNSCoding("expirationDate") as? Date
                }
            }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedForGenericSpecialization() throws {
        let exampleFile = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
            //
        }
        """#
        let sut = Annotator(protocols: ["NSFetchRequestResult"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<any NSFetchRequestResult>) {
            //
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialsAreAnnotatedWhenUsedForGenericSpecialization() throws {
        let exampleFile = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>, _: NSFetchedResultsController<NSFetchRequestResults>) {
            //
        }
        """#
        let sut = Annotator(protocols: ["NSFetchRequestResult", "NSFetchRequestResults"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<any NSFetchRequestResult>, _: NSFetchedResultsController<any NSFetchRequestResults>) {
            //
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedInProtocolCompositionAsReturnType() throws {
        let exampleFile = #"""
        protocol NavigatorProtocol {}
        protocol OnDataModified {}

        func makeSomething(navigator: NavigatorProtocol, data: Data) -> NavigatorProtocol & OnDataModified {
            return ""
        }

        extension String: NavigatorProtocol, OnDataModified {}
        """#

        let sut = Annotator(protocols: ["OnDataModified", "NavigatorProtocol"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        protocol NavigatorProtocol {}
        protocol OnDataModified {}

        func makeSomething(navigator: any NavigatorProtocol, data: Data) -> any NavigatorProtocol & OnDataModified {
            return ""
        }

        extension String: NavigatorProtocol, OnDataModified {}
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsReturnType() throws {
        let exampleFile = #"""
        func doSomething() -> Codable {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> any Codable {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsReturnTypeWithModuleName() throws {
        let exampleFile = #"""
        func doSomething() -> Swift.Codable {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> any Swift.Codable {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsFunctionArgumentWithModuleName() throws {
        let exampleFile = #"""
        func doSomething(_ error: Swift.Error) {
            let e = error as Swift.Error
        }
        """#

        let sut = Annotator(protocols: ["Error"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ error: any Swift.Error) {
            let e = error as any Swift.Error
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsFunctionReturnTypeInsideAnArray() throws {
        let exampleFile = #"""
        func doSomething() -> [Codable] {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> [any Codable] {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedInsideGenericTypeDeclarationAndWrappedInArray() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        let gen: Gen<[Codable]>
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        let gen: Gen<[any Codable]>
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedInsideGenericTypeDeclarationAndWrappedInOptionalArray() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        var items: Gen<[Codable]?> {}
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        var items: Gen<[any Codable]?> {}
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedInOptionalFunctionParameterOfSomeGenericTypeWrappedInArray() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        func doSomething(param: Gen<[Codable]>?) {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        func doSomething(param: Gen<[any Codable]>?) {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgain() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        func doSomething() -> Gen<[any Codable]> {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        func doSomething() -> Gen<[any Codable]> {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsMethodParameterInArrayType() throws {
        let exampleFile = #"""
        func doSomething(_ param: [Codable]) -> String {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ param: [any Codable]) -> String {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsMethodParameterInOptionalArrayType() throws {
        let exampleFile = #"""
        func doSomething(_ param: [Codable?]) -> String {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ param: [(any Codable)?]) -> String {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedIfUsedInTypeCompositionAsMethodParameter() throws {
        let exampleFile = #"""
        typealias MyType = ArticleRepository & ArticleProviding
        
        final class SimpleUseCase {
          private let repository: MyType
          private var article: Article!

          init(repository: ArticleRepository & ArticleProviding) {
            self.repository = repository
          }
        }
        """#
        let sut = Annotator(protocols: ["ArticleRepository", "ArticleProviding", "MyType"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        typealias MyType = ArticleRepository & ArticleProviding

        final class SimpleUseCase {
          private let repository: any MyType
          private var article: Article!

          init(repository: any ArticleRepository & ArticleProviding) {
            self.repository = repository
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsMethodParameterInWholeOptionalArrayType() throws {
        let exampleFile = #"""
        func doSomething(_ param: [Codable]?) -> String {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ param: [any Codable]?) -> String {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsMethodParameterInUnwrappedOptionalArrayType() throws {
        let exampleFile = #"""
        func doSomething(_ param: [Codable!]) -> String {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ param: [(any Codable)!]) -> String {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsMethodParameterInInoutArrayType() throws {
        let exampleFile = #"""
        func doSomething(_ param: inout [Codable]) -> String {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ param: inout [any Codable]) -> String {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsOptionalReturnType() throws {
        let exampleFile = #"""
            private func getValue(forKey key: String) -> NSCoding? {
                return "some key"
            }
        """#

        let sut = Annotator(protocols: ["NSCoding"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
            private func getValue(forKey key: String) -> (any NSCoding)? {
                return "some key"
            }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedInArray() throws {
        let exampleFile = #"""
        struct MyType {
            let responses: [Decodable]
        }
        """#

        let sut = Annotator(protocols: ["Decodable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            let responses: [any Decodable]
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainIfUsedAsFunctionReturnType() throws {
        let exampleFile = #"""
        func doSomething() -> any Codable {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> any Codable {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainIfUsedAsFunctionReturnTypeWithModuleName() throws {
        let exampleFile = #"""
        func doSomething() -> any Swift.Codable {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> any Swift.Codable {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainIfUsedAsFunctionParameterWithModuleName() throws {
        let exampleFile = #"""
        func doSomething(_ error: any Swift.Error) {
            let e = error as any Swift.Error
        }
        """#

        let sut = Annotator(protocols: ["Error"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething(_ error: any Swift.Error) {
            let e = error as any Swift.Error
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainWhenUsedAsReturnTypeInsideAnArray() throws {
        let exampleFile = #"""
        func doSomething() -> [any Codable] {
            return ""
        }
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func doSomething() -> [any Codable] {
            return ""
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainWhenUsedInGeneriClauseInsideAnArray() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        let gen: Gen<[any Codable]>
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        let gen: Gen<[any Codable]>
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsNotAnnotatedAgainWhenUsedInGeneriClauseInsideAnOptionalArray() throws {
        let exampleFile = #"""
        struct Gen<T> {}
        
        var items: Gen<[any Codable]?> {}
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct Gen<T> {}
        
        var items: Gen<[any Codable]?> {}
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatProtocolsNotTreatedAsExistentialWhenUsedAsTypeConstraint() throws {
        let exampleFile = #"""
        struct MyType: Swift.Codable {}        
        """#

        let sut = Annotator(protocols: ["Codable"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType: Swift.Codable {}        
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatNestedTypesWithSameNameAsProtocolAreNotAnnotated() throws {
        let exampleFile = #"""
        struct MyType {
            enum Error {
                case basic
                case network
            }
        }        
        
        let error: MyType.Error
        """#

        let sut = Annotator(protocols: ["Error"])
        let parsedSource = Parser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            enum Error {
                case basic
                case network
            }
        }        
        
        let error: MyType.Error
        """#

        XCTAssertEqual(annotated.description, expected)
    }
}
