//
//  ConfigLoader.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import Foundation

struct ConfigLoader {
    static let defaultPhoneNumber: String = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let phone = dict["DefaultPhoneNumber"] as? String {
            return phone
        }
        return "" // Fallback to empty string if Config.plist not found
    }()
    
    static let defaultCountryCode: String = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let code = dict["DefaultCountryCode"] as? String {
            return code
        }
        return "1" // Fallback to US country code
    }()
    
    static let life360BasicAuth: String = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let auth = dict["Life360BasicAuth"] as? String {
            return auth
        }
        fatalError("Config.plist not found or Life360BasicAuth missing. Please create Config.plist from Config.example.plist")
    }()
}

