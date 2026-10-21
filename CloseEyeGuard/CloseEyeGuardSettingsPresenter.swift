//
//  CloseEyeGuardSettingsPresenter.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

import UIKit
import os

/// 设置面板管理：
/// 1. 自建 UIWindow（windowLevel = .alert + 1）展示设置页，不侵入宿主 view 层级；
/// 2. 在宿主 key window 上挂四指双击手势用于呼出/收起（cancelsTouchesInView=false，
///    不影响宿主正常交互）；
/// 3. scene 激活 / App 进入前台时重挂手势，兼容宿主重建 window。
public final class CloseEyeGuardSettingsPresenter: NSObject {
    public static let shared = CloseEyeGuardSettingsPresenter()
    
    private var settingsWindow: UIWindow?
    private weak var gestureWindow: UIWindow?
    private var settingsTap: UITapGestureRecognizer?
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChange),
            name: .closeEyeGuardConfigDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSceneOrAppActivated),
            name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSceneOrAppActivated),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: - 四指双击手势
    
    /// 在宿主 key window 上安装四指双击手势（幂等）
    public func installSettingsGesture() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.installSettingsGesture() }
            return
        }
        guard CloseEyeGuardConfig.shared.settingsGestureEnabled else { return }
        guard let window = Self.hostKeyWindow() else {
            CloseEyeGuardLog.settings.info("未找到宿主 key window，四指双击手势暂未安装（稍后自动重试）")
            return
        }
        if window === gestureWindow, settingsTap != nil { return }
        removeSettingsGesture()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSettingsTap(_:)))
        tap.numberOfTapsRequired = 2
        tap.numberOfTouchesRequired = 4
        tap.cancelsTouchesInView = false
        window.addGestureRecognizer(tap)
        gestureWindow = window
        settingsTap = tap
        CloseEyeGuardLog.settings.info("四指双击呼出设置手势已安装")
    }
    
    public func removeSettingsGesture() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.removeSettingsGesture() }
            return
        }
        if let tap = settingsTap {
            gestureWindow?.removeGestureRecognizer(tap)
        }
        settingsTap = nil
        gestureWindow = nil
    }
    
    @objc private func handleSettingsTap(_ tap: UITapGestureRecognizer) {
        toggle()
    }
    
    // MARK: - 设置面板（自建 UIWindow）
    
    public func show() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.show() }
            return
        }
        guard settingsWindow == nil else { return }
        guard let scene = Self.hostKeyWindow()?.windowScene else {
            CloseEyeGuardLog.settings.info("未找到宿主 windowScene，设置面板无法展示")
            return
        }
        let nav = UINavigationController(rootViewController: CloseEyeGuardSettingsViewController())
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = nav
        // 面板上也支持四指双击收起
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSettingsTap(_:)))
        tap.numberOfTapsRequired = 2
        tap.numberOfTouchesRequired = 4
        tap.cancelsTouchesInView = false
        window.addGestureRecognizer(tap)
        window.makeKeyAndVisible()
        settingsWindow = window
        CloseEyeGuardLog.settings.info("设置面板已显示")
    }
    
    public func hide() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.hide() }
            return
        }
        settingsWindow?.isHidden = true
        settingsWindow = nil
    }
    
    public func toggle() {
        if settingsWindow == nil { show() } else { hide() }
    }
    
    // MARK: - 变化响应
    
    @objc private func handleConfigChange() {
        if CloseEyeGuardConfig.shared.settingsGestureEnabled {
            installSettingsGesture()
        } else {
            removeSettingsGesture()
        }
    }
    
    @objc private func handleSceneOrAppActivated() {
        // scene 激活 / App 回前台后 key window 可能更换，幂等重挂手势
        installSettingsGesture()
    }
    
    private static func hostKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) { return key }
            if let first = scene.windows.first { return first }
        }
        for scene in scenes {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) { return key }
            if let first = scene.windows.first { return first }
        }
        return nil
    }
}
