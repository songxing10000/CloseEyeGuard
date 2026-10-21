//
//  CloseEyeGuardConfig.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

import Foundation
import os

public extension Notification.Name {
    /// 任意配置项变化后广播，各模块监听后热更新
    static let closeEyeGuardConfigDidChange = Notification.Name("CloseEyeGuard.configDidChange")
}

/// 所有可配置项。修改任意属性会立即持久化（独立 UserDefaults suite，
/// 不污染宿主 App 的存储）并广播通知，各模块热更新，无需重启 App。
public final class CloseEyeGuardConfig {
    public static let shared = CloseEyeGuardConfig()
    public static let suiteName = "com.xing.CloseEyeGuard.config"
    
    private let defaults: UserDefaults
    private var isLoading = false
    
    private enum Key {
        static let monitorEnabled = "monitorEnabled"
        static let checkInterval = "checkInterval"
        static let faceWidthThreshold = "faceWidthThreshold"
        static let voiceEnabled = "voiceEnabled"
        static let volume = "volume"
        static let speechRate = "speechRate"
        static let warningText = "warningText"
        static let settingsGestureEnabled = "settingsGestureEnabled"
    }
    
    // MARK: - 可配置项（=出厂默认值）
    
    /// 是否启用监测
    public var monitorEnabled = true { didSet { commit() } }
    /// 检测间隔（秒）
    public var checkInterval: TimeInterval = 2.0 { didSet { commit() } }
    /// 人脸宽度占画面宽度的比例阈值，超过判定为过近
    public var faceWidthThreshold: Double = 0.25 { didSet { commit() } }
    /// 是否启用语音提醒
    public var voiceEnabled = true { didSet { commit() } }
    /// 播报音量 0~1
    public var volume: Float = 1.0 { didSet { commit() } }
    /// 播报语速 0~1（映射到系统语速范围）
    public var speechRate: Float = 0.5 { didSet { commit() } }
    /// 提醒文案
    public var warningText = "距离太近了，请坐直一点" { didSet { commit() } }
    /// 是否启用四指双击呼出设置面板手势
    public var settingsGestureEnabled = true { didSet { commit() } }
    
    private init() {
        self.defaults = UserDefaults(suiteName: CloseEyeGuardConfig.suiteName) ?? .standard
        load()
    }
    
    // MARK: - 持久化
    
    private func load() {
        isLoading = true
        if let v = defaults.object(forKey: Key.monitorEnabled) as? Bool { monitorEnabled = v }
        if let v = defaults.object(forKey: Key.checkInterval) as? Double { checkInterval = v }
        if let v = defaults.object(forKey: Key.faceWidthThreshold) as? Double { faceWidthThreshold = v }
        if let v = defaults.object(forKey: Key.voiceEnabled) as? Bool { voiceEnabled = v }
        if let v = defaults.object(forKey: Key.volume) as? Float { volume = v }
        if let v = defaults.object(forKey: Key.speechRate) as? Float { speechRate = v }
        if let v = defaults.string(forKey: Key.warningText), !v.isEmpty { warningText = v }
        if let v = defaults.object(forKey: Key.settingsGestureEnabled) as? Bool { settingsGestureEnabled = v }
        isLoading = false
    }
    
    private func commit() {
        guard !isLoading else { return }
        defaults.set(monitorEnabled, forKey: Key.monitorEnabled)
        defaults.set(checkInterval, forKey: Key.checkInterval)
        defaults.set(faceWidthThreshold, forKey: Key.faceWidthThreshold)
        defaults.set(voiceEnabled, forKey: Key.voiceEnabled)
        defaults.set(volume, forKey: Key.volume)
        defaults.set(speechRate, forKey: Key.speechRate)
        defaults.set(warningText, forKey: Key.warningText)
        defaults.set(settingsGestureEnabled, forKey: Key.settingsGestureEnabled)
        NotificationCenter.default.post(name: .closeEyeGuardConfigDidChange, object: nil)
        CloseEyeGuardLog.config.info("配置已更新并保存")
    }
    
    /// 恢复出厂默认值
    public func resetToDefaults() {
        isLoading = true
        monitorEnabled = true
        checkInterval = 2.0
        faceWidthThreshold = 0.25
        voiceEnabled = true
        volume = 1.0
        speechRate = 0.5
        warningText = "距离太近了，请坐直一点"
        settingsGestureEnabled = true
        isLoading = false
        commit()
    }
}
