//
//  AudioManager.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/20.
//

import Foundation
import AVFoundation
import os

class AudioManager {
    static let shared = AudioManager()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 关键：设置为 playback，允许后台播放音频，且不受静音键影响
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            CloseEyeGuardLog.audio.info("AudioSession 配置成功 (playback)")
        } catch {
            CloseEyeGuardLog.audio.error("AudioSession 设置失败: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func speakWarning() {
        let config = CloseEyeGuardConfig.shared
        
        guard config.voiceEnabled else {
            CloseEyeGuardLog.audio.debug("语音提醒已关闭，跳过")
            return
        }
        // 避免连续疯狂播报
        guard !speechSynthesizer.isSpeaking else {
            CloseEyeGuardLog.audio.debug("语音播报中，跳过本次提醒")
            return
        }
        
        let utterance = AVSpeechUtterance(string: config.warningText)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        // speechRate 0~1 映射到系统语速范围
        let minRate = AVSpeechUtteranceMinimumSpeechRate
        let maxRate = AVSpeechUtteranceMaximumSpeechRate
        utterance.rate = minRate + config.speechRate * (maxRate - minRate)
        utterance.volume = config.volume
        
        CloseEyeGuardLog.audio.info("🔊 开始语音播报：\(config.warningText, privacy: .public)")
        speechSynthesizer.speak(utterance)
    }
}
