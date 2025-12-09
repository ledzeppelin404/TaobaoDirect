// 淘口令自动跳转淘宝功能
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Headers/WCHeaders.h"

// 检查淘口令跳转功能是否启用
static BOOL isTaobaoJumpEnabled() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"TaobaoJump_Enabled"];
    NSLog(@"[TaobaoJump] 功能状态: %@", enabled ? @"已启用" : @"未启用");
    return enabled;
}

// 存储当前长按的消息内容
static NSString *currentLongPressedText = nil;

// 跳转到淘宝
static void jumpToTaobaoWithText(NSString *text) {
    if (!text || text.length == 0) {
        return;
    }
    
    // 复制到剪贴板
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = text;
    
    // 跳转到淘宝
    NSString *taobaoScheme = @"taobao://";
    NSURL *taobaoURL = [NSURL URLWithString:taobaoScheme];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:taobaoURL options:@{} completionHandler:^(BOOL success) {
            if (success) {
                NSLog(@"[TaobaoJump] 成功跳转到淘宝，已复制内容: %@", text);
            } else {
                // 如果跳转失败，提示用户
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                               message:@"无法打开淘宝，请确认已安装淘宝App"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:nil];
                [alert addAction:okAction];
                
                // 获取当前最顶层的视图控制器
                UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
                while (topController.presentedViewController) {
                    topController = topController.presentedViewController;
                }
                if (topController) {
                    [topController presentViewController:alert animated:YES completion:nil];
                }
            }
        }];
    });
}

// Hook BaseMsgContentViewController 来拦截长按消息事件
%hook BaseMsgContentViewController

// 重写 canPerformAction 方法，添加自定义菜单项
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // 先调用原始方法
    BOOL originalResult = %orig;
    
    // 如果功能未启用，直接返回原始结果
    if (!isTaobaoJumpEnabled()) {
        return originalResult;
    }
    
    // 如果是我们自定义的"跳转淘宝"动作
    if (action == @selector(jumpToTaobaoAction:)) {
        return YES;
    }
    
    return originalResult;
}

// 自定义的跳转淘宝动作方法
%new
- (void)jumpToTaobaoAction:(id)sender {
    if (currentLongPressedText && currentLongPressedText.length > 0) {
        jumpToTaobaoWithText(currentLongPressedText);
    }
}

// Hook viewDidLoad 来注册自定义菜单项
- (void)viewDidLoad {
    %orig;
    
    if (!isTaobaoJumpEnabled()) {
        return;
    }
    
    // 添加自定义菜单项
    UIMenuItem *taobaoItem = [[UIMenuItem alloc] initWithTitle:@"跳转淘宝" 
                                                        action:@selector(jumpToTaobaoAction:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    NSMutableArray *menuItems = [NSMutableArray arrayWithArray:menuController.menuItems ?: @[]];
    
    // 检查是否已经添加过，避免重复
    BOOL alreadyExists = NO;
    for (UIMenuItem *item in menuItems) {
        if ([item.title isEqualToString:@"跳转淘宝"]) {
            alreadyExists = YES;
            break;
        }
    }
    
    if (!alreadyExists) {
        [menuItems addObject:taobaoItem];
        menuController.menuItems = menuItems;
    }
}

%end

// Hook CommonMessageCellView 来获取长按的消息内容
%hook CommonMessageCellView

- (void)setViewModel:(id)viewModel {
    %orig;
    
    if (!isTaobaoJumpEnabled()) {
        return;
    }
    
    // 当设置 viewModel 时，尝试获取消息内容
    if (viewModel && [viewModel respondsToSelector:@selector(messageWrap)]) {
        id messageWrap = [viewModel performSelector:@selector(messageWrap)];
        if (messageWrap && [messageWrap respondsToSelector:@selector(m_nsContent)]) {
            // 保存消息内容供后续使用
            NSString *content = [messageWrap performSelector:@selector(m_nsContent)];
            if (content && content.length > 0) {
                currentLongPressedText = content;
            }
        }
    }
}

// Hook 长按手势
- (void)onLongTouch:(id)arg {
    %orig;
    
    NSLog(@"[TaobaoJump] 检测到长按消息，当前内容: %@", currentLongPressedText);
    
    if (!isTaobaoJumpEnabled()) {
        NSLog(@"[TaobaoJump] 功能未启用，跳过");
        return;
    }
    
    // 长按时，确保菜单项已注册
    UIMenuItem *taobaoItem = [[UIMenuItem alloc] initWithTitle:@"跳转淘宝" 
                                                        action:@selector(jumpToTaobaoAction:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    NSMutableArray *menuItems = [NSMutableArray arrayWithArray:menuController.menuItems ?: @[]];
    
    // 检查是否已经添加过
    BOOL alreadyExists = NO;
    for (UIMenuItem *item in menuItems) {
        if ([item.title isEqualToString:@"跳转淘宝"]) {
            alreadyExists = YES;
            break;
        }
    }
    
    if (!alreadyExists) {
        [menuItems addObject:taobaoItem];
        menuController.menuItems = menuItems;
        NSLog(@"[TaobaoJump] 已添加\"跳转淘宝\"菜单项，总菜单数: %lu", (unsigned long)menuItems.count);
    } else {
        NSLog(@"[TaobaoJump] \"跳转淘宝\"菜单项已存在");
    }
}

// 实现 canPerformAction 来让菜单项显示
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (isTaobaoJumpEnabled() && action == @selector(jumpToTaobaoAction:)) {
        NSLog(@"[TaobaoJump] canPerformAction 返回 YES");
        return YES;
    }
    return %orig;
}

// 实现跳转淘宝动作
%new
- (void)jumpToTaobaoAction:(id)sender {
    NSLog(@"[TaobaoJump] 跳转淘宝动作被触发，内容: %@", currentLongPressedText);
    if (currentLongPressedText && currentLongPressedText.length > 0) {
        jumpToTaobaoWithText(currentLongPressedText);
    } else {
        NSLog(@"[TaobaoJump] 错误: 没有可用的消息内容");
    }
}

%end

%ctor {
    %init;
    NSLog(@"[TaobaoJump] 淘口令自动跳转功能已加载");
}
