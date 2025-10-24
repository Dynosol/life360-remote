//
//  Models.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import Foundation

struct Circle: Identifiable, Codable {
    let id: String
    let name: String
    let createdAt: String
}

struct CirclesResponse: Codable {
    let circles: [Circle]
}

