//
//  PDGNodeType.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 05.06.2025.
//

enum PDGNodeType: String, Codable, CaseIterable {

    case literalAssignment

    case increment

    case decrement

    case functionCall

    case functionCallAssignment

    case methodInvocation

    case propertyAccess

    case propertyAssignment

    case optionalBinding

    case optionalChaining

    case throwStatement

    case returnStatement

    case conditionalCheck

    case loopEntry

    case loopExit

    case switchCase

    case typeCast

    case closureDefinition

    case deferStatement

    case enumCasePattern
}
