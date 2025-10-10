import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

final class Annotator: SyntaxRewriter {
    private let protocols: Set<String>

    init(protocols: Set<String>) {
        self.protocols = protocols
    }

    // This method is implemented in order to avoid adding `any` token when there is one already.
    // If a node already has `any` annotation, we just return it and don't go any deeper
    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        TypeSyntax(node)
    }

    override func visit(_ node: ReturnClauseSyntax) -> ReturnClauseSyntax {
        var modifiedNode = node
        modifiedNode.type = addAnyKeywordTo(type: node.type)
        return modifiedNode
    }

    override func visit(_ node: TypeAnnotationSyntax) -> TypeAnnotationSyntax {
        var modifiedNode = node
        modifiedNode.type = addAnyKeywordTo(type: node.type)
        return modifiedNode
    }

    override func visit(_ node: ExprListSyntax) -> ExprListSyntax {
        var modifiedNode = node
        node.enumerated().forEach {
            if let exprType = $0.element.as(TypeExprSyntax.self) {
                var newExprType = exprType
                newExprType.type = addAnyKeywordTo(type: exprType.type)
                if let newType = ExprSyntax(newExprType) {
                    modifiedNode = modifiedNode.replacing(childAt: $0.offset, with: newType)
                }
            }
        }
        return modifiedNode
    }

    override func visit(_ node: ArrayTypeSyntax) -> TypeSyntax {
        var modifiedNode = node
        let arrayElement = node.element.description.trimmingCharacters(in: .whitespaces)

        if let _ = node.element.as(IdentifierTypeSyntax.self), protocols.contains(arrayElement) {
            modifiedNode.unexpectedBetweenLeftSquareAndElement = anyToken
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        } else {
            modifiedNode.element = visit(node.element)
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        }
    }

    override func visit(_ node: OptionalTypeSyntax) -> TypeSyntax {
        var modifiedNode = node
        let wrappedType = node.wrappedType.description.trimmingCharacters(in: .whitespaces)

        if let _ = node.wrappedType.as(IdentifierTypeSyntax.self), protocols.contains(wrappedType) {
            modifiedNode.unexpectedBeforeWrappedType = openingParenAndAnyToken
            modifiedNode.unexpectedBetweenWrappedTypeAndQuestionMark = closingParenToken
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        } else {
            modifiedNode.wrappedType = visit(node.wrappedType)
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        }
    }

    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> TypeSyntax {
        var modifiedNode = node
        let wrappedType = node.wrappedType.description.trimmingCharacters(in: .whitespaces)

        if let _ = node.wrappedType.as(IdentifierTypeSyntax.self), protocols.contains(wrappedType) {
            modifiedNode.unexpectedBeforeWrappedType = openingParenAndAnyToken
            modifiedNode.unexpectedBetweenWrappedTypeAndExclamationMark = closingParenToken
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        } else {
            modifiedNode.wrappedType = visit(node.wrappedType)
            return TypeSyntax(modifiedNode) ?? super.visit(node)
        }
    }

    override func visit(_ node: FunctionParameterClauseSyntax) -> FunctionParameterClauseSyntax {
        var modifiedNode = node

        let parameters = node.parameters.map { parameter in
            var modifiedParam = parameter
            modifiedParam.type = addAnyKeywordTo(type: parameter.type)
            return modifiedParam
        }
        let modifiedParameterList = FunctionParameterListSyntax(parameters)

        modifiedNode.parameters = modifiedParameterList
        return modifiedNode
    }

    override func visit(_ node: GenericArgumentSyntax) -> GenericArgumentSyntax {
        guard protocols.contains(node.argument.description.trimmingCharacters(in: .whitespaces)) else { return super.visit(node) }
        var modifiedNode = node

        if case let .type(typeSyntax) = node.argument, let type = IdentifierTypeSyntax(typeSyntax) {
            var modifiedNestedType = type
            modifiedNestedType.unexpectedBeforeName = anyToken
            modifiedNode.argument = .type(TypeSyntax(modifiedNestedType))
            return modifiedNode
        } else {
            return super.visit(node)
        }
    }
}

// MARK: - Annotation helpers

private extension Annotator {

    func visitAndAnnotateWithAny(_ node: CompositionTypeSyntax) -> TypeSyntax {
        var theyAreAllProtocolsInThere = true
        for child in node.elements {
            let desc = child.type.description.trimmingCharacters(in: .whitespaces)
            if !protocols.contains(desc) {
                theyAreAllProtocolsInThere = false
            }
        }
        if theyAreAllProtocolsInThere {
            var newNode = node
            newNode.unexpectedBeforeElements = anyToken
            return TypeSyntax(newNode) ?? super.visit(node)
        } else {
            return super.visit(node)
        }
    }

    func visitAndAnnotateWithAny(_ node: MemberTypeSyntax) -> TypeSyntax {
        // This method gets called for nested types and we want to avoid false positives in those cases. But there is no way to
        // know if `baseType` is a module or just a type so it's safer to constraint this to only work with "Swift" and avoid false positives
        guard node.baseType.description == "Swift" else { return super.visit(node)}
        guard protocols.contains(node.name.description.trimmingCharacters(in: .whitespaces)) else { return super.visit(node) }

        var modifiedNode = node
        modifiedNode.unexpectedBeforeBaseType = anyToken
        return TypeSyntax(modifiedNode) ?? super.visit(node)
    }

    func addAnyKeywordTo(type: TypeSyntax) -> TypeSyntax {
        if let compositionType = type.as(CompositionTypeSyntax.self) {
            return visitAndAnnotateWithAny(compositionType)
        } else if let memberType = type.as(MemberTypeSyntax.self) {
            return visitAndAnnotateWithAny(memberType)
        } else if let simpleType = type.as(IdentifierTypeSyntax.self) {
            if let argumentClause = simpleType.genericArgumentClause {
                var modifiedType = simpleType
                modifiedType.genericArgumentClause = visit(argumentClause)
                return TypeSyntax(modifiedType) ?? type
            } else {
                guard protocols.contains(type.description.trimmingCharacters(in: .whitespaces)) else { return type }
                var modifiedType = simpleType
                modifiedType.unexpectedBeforeName = anyToken
                return TypeSyntax(modifiedType) ?? type
            }
        }
        return visit(type)
    }
}

// MARK: - Helper tokens

private extension Annotator {

    @UnexpectedNodesBuilder
    private var anyToken: UnexpectedNodesSyntax {
        TokenSyntax(.unknown("any"), trailingTrivia: [.spaces(1)], presence: .present)
    }

    @UnexpectedNodesBuilder
    private var openingParenToken: UnexpectedNodesSyntax {
        TokenSyntax(.leftParen, presence: .present)
    }

    @UnexpectedNodesBuilder
    private var closingParenToken: UnexpectedNodesSyntax {
        TokenSyntax(.rightParen, presence: .present)
    }

    @UnexpectedNodesBuilder
    private var openingParenAndAnyToken: UnexpectedNodesSyntax {
        UnexpectedNodesSyntax([
            openingParenToken,
            anyToken
        ])
    }
}
