//
//  BackgroundCameraManager.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/20.
//

import Foundation
import AVFoundation
import Vision
import UIKit
import Combine
import os

/// 核心监测管理器：前置摄像头 + Vision 人脸检测，距离过近时语音提醒。
///
/// 状态订阅（Combine）：
/// - `$isTooClose`：当前是否距离过近
/// - `$currentDistanceCM`：估算距离（cm，仅供参考）
/// - `$isCameraAuthorized`：摄像头权限状态
public class BackgroundCameraManager: NSObject, ObservableObject {
    public static let shared = BackgroundCameraManager()
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Vision 请求
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    
    // MARK: - 对外状态（Combine 订阅）
    
    /// 当前是否距离过近
    @Published public var isTooClose = false
    /// 估算距离（cm）。基于人像宽度粗略换算，仅供参考；报警判断使用阈值
    @Published public var currentDistanceCM: Double = 50.0
    /// 摄像头权限是否已授权
    @Published public var isCameraAuthorized = false
    
    // MARK: - 可配置项（实时读取 CloseEyeGuardConfig，修改即时生效）
    
    private var checkInterval: TimeInterval {
        CloseEyeGuardConfig.shared.checkInterval
    }
    private var faceWidthThreshold: CGFloat {
        CGFloat(CloseEyeGuardConfig.shared.faceWidthThreshold)
    }
    
    // 粗略距离换算常数（假设人脸实际宽度 15cm + 前置镜头 FOV 估算），
    // 仅用于 UI 参考显示，报警判断使用 faceWidthThreshold 阈值
    private static let distanceEstimateConstant = 0.04
    
    // session 是否已完成配置（避免重复 addInput/addOutput，仅 sessionQueue 读写）
    private var isSessionConfigured = false
    
    // 防止自启钩子与宿主手动调用重复触发（仅主线程读写）
    private var hasRequestedStart = false
    
    // 中断/错误通知监听 token（单例常驻，无需移除）
    private var interruptionObservers: [NSObjectProtocol] = []
    
    // 节流时间戳（仅在 video.output.queue 上读写）
    private var lastCheckTime: CFAbsoluteTime = 0
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange),
            name: .closeEyeGuardConfigDidChange,
            object: nil)
    }
    
    /// 配置变化热更新：监测开关切换时启停
    @objc private func handleConfigChange() {
        if CloseEyeGuardConfig.shared.monitorEnabled {
            start()
        } else {
            stop()
        }
    }
    
    // MARK: - 权限请求与生命周期控制
    
    /// 请求摄像头权限，授权后自动开始监测。应在 App 启动、UI 就绪后调用。
    public func start() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.start() }
            return
        }
        guard !hasRequestedStart else { return }
        
        guard CloseEyeGuardConfig.shared.monitorEnabled else {
            CloseEyeGuardLog.camera.info("配置里监测处于关闭状态，不启动（可在设置面板中开启）")
            return
        }
        hasRequestedStart = true
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        CloseEyeGuardLog.camera.info("start() 调用，当前摄像头权限状态: \(status.rawValue)")
        
        switch status {
        case .authorized:
            DispatchQueue.main.async { self.isCameraAuthorized = true }
            configureSessionIfNeeded()
            startMonitoring()
        case .notDetermined:
            CloseEyeGuardLog.camera.info("摄像头权限未决定，弹出系统授权弹窗")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isCameraAuthorized = granted
                    if granted {
                        self.configureSessionIfNeeded()
                        self.startMonitoring()
                    } else {
                        CloseEyeGuardLog.camera.warning("摄像头权限被拒绝，可调用 openSystemSettings() 引导用户开启")
                    }
                }
            }
        default:
            // .denied / .restricted
            DispatchQueue.main.async { self.isCameraAuthorized = false }
            CloseEyeGuardLog.camera.warning("摄像头权限不可用，请前往 设置 > 隐私与安全性 > 摄像头 开启")
        }
    }
    
    /// 停止监测（之后可再次调用 start 恢复）
    public func stop() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.stop() }
            return
        }
        hasRequestedStart = false
        stopMonitoring()
    }
    
    /// 摄像头权限被拒时，调用此方法跳转到系统设置页
    public func openSystemSettings() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.openSystemSettings() }
            return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - 会话配置
    
    private func configureSessionIfNeeded() {
        sessionQueue.async {
            guard !self.isSessionConfigured else { return }
            
            self.captureSession.sessionPreset = .low // 使用低分辨率，极大降低功耗
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: frontCamera) else {
                CloseEyeGuardLog.camera.error("无法获取前置摄像头，监测未启动（模拟器？或其他 App 占用摄像头？）")
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            // 关键：摄像头传感器原始输出是横屏的。竖屏持机时人脸在原始帧里是
            // 旋转 90° 的，而下面 Vision 用 .up 方向检测，侧躺的人脸基本检测不到，
            // 导致永远不报警。这里把输出帧旋转为竖屏方向，与 Vision 的 .up 对齐。
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                        CloseEyeGuardLog.camera.info("已设置视频旋转角度 = 90 (portrait)")
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                    CloseEyeGuardLog.camera.info("已设置视频方向 = portrait (iOS17 之前)")
                }
            }
            
            self.isSessionConfigured = true
            self.setupInterruptionObservers()
            CloseEyeGuardLog.camera.info("相机会话配置完成 (preset=low)")
        }
    }
    
    /// 监听来电/其他 App 抢占等中断与运行时错误，恢复后自动重启监测
    private func setupInterruptionObservers() {
        guard interruptionObservers.isEmpty else { return }
        let center = NotificationCenter.default
        
        interruptionObservers.append(center.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: captureSession,
            queue: nil
        ) { [weak self] note in
            let reason = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason
            CloseEyeGuardLog.camera.warning("相机会话被中断（来电/其他 App 抢占等），恢复后会自动重启。reason: \(reason?.rawValue ?? -1)")
        })
        
        interruptionObservers.append(center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: captureSession,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.sessionQueue.async {
                CloseEyeGuardLog.camera.info("相机会话中断结束，尝试自动恢复监测")
                if self.isSessionConfigured,
                   !self.captureSession.isRunning,
                   CloseEyeGuardConfig.shared.monitorEnabled {
                    self.captureSession.startRunning()
                    CloseEyeGuardLog.camera.info("相机会话已自动恢复，isRunning: \(self.captureSession.isRunning)")
                }
            }
        })
        
        interruptionObservers.append(center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: captureSession,
            queue: nil
        ) { [weak self] note in
            guard let self = self else { return }
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            CloseEyeGuardLog.camera.error("相机会话运行时错误: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            self.sessionQueue.async {
                if self.isSessionConfigured,
                   !self.captureSession.isRunning,
                   CloseEyeGuardConfig.shared.monitorEnabled {
                    self.captureSession.startRunning()
                }
            }
        })
    }
    
    private func startMonitoring() {
        sessionQueue.async {
            CloseEyeGuardLog.camera.info("正在启动 captureSession...")
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            CloseEyeGuardLog.camera.info("captureSession.isRunning: \(self.captureSession.isRunning)")
        }
    }
    
    private func stopMonitoring() {
        sessionQueue.async {
            self.lastCheckTime = 0 // 重置节流，下次启动立即检测
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isTooClose = false
            }
        }
    }
    
    private func processDistance(faceWidth: CGFloat) {
        // 简单的线性估算模型 (仅供UI显示参考，核心判断靠阈值)
        let estimatedCM = max(15.0, (Self.distanceEstimateConstant / Double(faceWidth)) * 100.0)
        
        DispatchQueue.main.async {
            self.currentDistanceCM = estimatedCM
            let tooClose = faceWidth > self.faceWidthThreshold
            
            self.isTooClose = tooClose
            if tooClose {
                CloseEyeGuardLog.camera.warning("🚨 距离过近 (faceWidth: \(Double(faceWidth), format: .fixed(precision: 3)) > 阈值 \(Double(self.faceWidthThreshold), format: .fixed(precision: 2)))，触发语音提醒")
                AudioManager.shared.speakWarning()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension BackgroundCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // 节流控制
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastCheckTime >= checkInterval else { return }
        lastCheckTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([faceDetectionRequest])
            guard let results = faceDetectionRequest.results, let face = results.first else {
                // 没检测到人脸
                CloseEyeGuardLog.camera.debug("本轮未检测到人脸（注意光线/角度/距离）")
                DispatchQueue.main.async { self.isTooClose = false }
                return
            }
            
            // 获取人脸边界框的宽度 (Vision 返回的是 0.0 到 1.0 的比例值)
            let faceWidth = face.boundingBox.width
            CloseEyeGuardLog.camera.debug("检测到人脸，宽度比例: \(Double(faceWidth), format: .fixed(precision: 3))（报警阈值: \(Double(self.faceWidthThreshold), format: .fixed(precision: 2))）")
            self.processDistance(faceWidth: faceWidth)
            
        } catch {
            CloseEyeGuardLog.camera.error("Vision 检测失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}
