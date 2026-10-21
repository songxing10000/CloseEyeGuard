//
//  CloseEyeGuardAutoStart.m
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Swift 侧导出的 C 入口符号（见 CloseEyeGuardBootstrap.swift）
extern void CloseEyeGuardAutoStartEntry(void);

// 零代码接入的自启钩子：宿主链接本静态库并开启 -ObjC 后，
// dyld 加载阶段执行 +load；此处延迟到 App 启动完成后再触发，
// 避免在 pre-main 阶段弹摄像头权限弹窗。
// （注意：本 target 实际是动态 framework，宿主需 Embed & Sign；
//   动态 framework 被 dyld 加载时 +load 同样会执行。）
@interface CloseEyeGuardAutoStart : NSObject
@end

@implementation CloseEyeGuardAutoStart

+ (void)load {
    NSLog(@"[CloseEyeGuard] ✅ framework 已被 dyld 加载（+load 执行）");
    __block id observer =
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        [[NSNotificationCenter defaultCenter] removeObserver:observer];
                        NSLog(@"[CloseEyeGuard] ✅ App 启动完成，触发自动启动监测");
                        CloseEyeGuardAutoStartEntry();
                    }];
}

@end
