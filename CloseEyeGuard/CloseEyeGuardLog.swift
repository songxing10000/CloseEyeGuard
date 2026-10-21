//
//  CloseEyeGuardLog.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

import Foundation
import os

/// 结构化日志：Console.app / Xcode 按 subsystem `com.xing.CloseEyeGuard` 过滤查看
enum CloseEyeGuardLog {
    static let subsystem = "com.xing.CloseEyeGuard"
    
    static let camera = Logger(subsystem: subsystem, category: "Camera")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let config = Logger(subsystem: subsystem, category: "Config")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
