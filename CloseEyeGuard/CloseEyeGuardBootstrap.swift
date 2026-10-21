//
//  CloseEyeGuardBootstrap.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

import Foundation

/// 宿主 App 手动启动入口（宿主希望自己控制启动时机时调用）
@objc public final class CloseEyeGuardBootstrap: NSObject {
    @objc public static func activate() {
        BackgroundCameraManager.shared.start()
        CloseEyeGuardSettingsPresenter.shared.installSettingsGesture()
    }
}

/// C 符号入口：供本库内 Objective-C `+load` 自启逻辑调用，
/// 无需导入 Swift 生成头文件。
@_cdecl("CloseEyeGuardAutoStartEntry")
public func closeEyeGuardAutoStartEntry() {
    BackgroundCameraManager.shared.start()
    CloseEyeGuardSettingsPresenter.shared.installSettingsGesture()
}
