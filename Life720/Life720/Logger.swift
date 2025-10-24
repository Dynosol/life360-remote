//
//  Logger.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import Foundation

private var globalAppendLog: ((String) -> Void)?

func debugPrintLog(_ s: String) {
    let text = s.hasSuffix("\n") ? s : s + "\n"
    print(text)
    DispatchQueue.main.async {
        globalAppendLog?(text)
    }
}

func setLogHandler(_ handler: @escaping (String) -> Void) {
    globalAppendLog = handler
}

