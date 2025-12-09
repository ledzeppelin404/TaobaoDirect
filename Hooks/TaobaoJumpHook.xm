// 淘口令跳转淘宝功能
// 参考 PKCWeChatTools.dylib 实现
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 定义配置键
#define kTaobaoJumpEnabledKey @"TaobaoJump_Enabled"

// 声明 WeChat 内部类
@interface CMessageWrap : NSObject
- (NSString *)m_nsContent;
@end

// MMMenuItem - 微信菜单项类
@interface MMMenuItem : NSObject
+ (instancetype)itemWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@property (nonatomic, copy) NSString *title;
@end

// MMMenuController - 微信菜单控制器
@interface MMMenuController : NSObject
- (void)setMenuItems:(NSArray *)items;
@end

// BaseMsgContentViewController - 消息内容视图控制器
@interface BaseMsgContentViewController : UIViewController
- (void)willShowMenuController:(id)controller inMsgWrap:(CMessageWrap *)msgWrap;
@end

// 全局变量
static NSString *g_currentMessageContent = nil;

// 检查功能是否启用
static BOOL isTaobaoJumpEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kTaobaoJumpEnabledKey];
}

// Hook BaseMsgContentViewController - 在显示菜单前捕获消息
%hook BaseMsgContentViewController

- (void)willShowMenuController:(id)controller inMsgWrap:(CMessageWrap *)msgWrap {
    NSLog(@"[TaobaoJump] 🎯 willShowMenuController 被调用");
    
    %orig;
    
    if (!isTaobaoJumpEnabled()) {
        NSLog(@"[TaobaoJump] ⏸️ 功能未启用");
        return;
    }
    
    // 从 msgWrap 中获取消息内容
    if (msgWrap) {
        NSString *content = [msgWrap m_nsContent];
        if (content && content.length > 0) {
            g_currentMessageContent = content;
            NSLog(@"[TaobaoJump] 📝 成功捕获消息内容: %@", content);
        } else {
            NSLog(@"[TaobaoJump] ⚠️ 消息内容为空");
        }
    } else {
        NSLog(@"[TaobaoJump] ⚠️ msgWrap 为空");
    }
}

%end

// Hook MMMenuController - 这是关键！
%hook MMMenuController

- (void)setMenuItems:(NSArray *)items {
    NSLog(@"[TaobaoJump] 🎯 MMMenuController setMenuItems 被调用，原始菜单项数: %lu", (unsigned long)items.count);
    
    // 检查功能是否启用
    if (!isTaobaoJumpEnabled()) {
        NSLog(@"[TaobaoJump] ⏸️ 功能未启用");
        %orig;
        return;
    }
    
    // 检查是否有消息内容
    if (!g_currentMessageContent || g_currentMessageContent.length == 0) {
        NSLog(@"[TaobaoJump] ⚠️ 没有消息内容，跳过添加菜单");
        %orig;
        return;
    }
    
    // 创建新的菜单项数组
    NSMutableArray *newItems = [items mutableCopy];
    
    // 创建"跳转淘宝"菜单项
    MMMenuItem *taobaoItem = [%c(MMMenuItem) itemWithTitle:@"跳转淘宝" 
                                                    target:self 
                                                    action:@selector(jumpToTaobao)];
    
    if (taobaoItem) {
        // 在第一个位置插入菜单项
        [newItems insertObject:taobaoItem atIndex:0];
        NSLog(@"[TaobaoJump] ✅ 成功添加淘宝跳转菜单项，新菜单项数: %lu", (unsigned long)newItems.count);
    } else {
        NSLog(@"[TaobaoJump] ❌ 创建菜单项失败");
    }
    
    // 调用原始方法，传入新的菜单项数组
    %orig(newItems);
}

// 添加新方法：跳转到淘宝
%new
- (void)jumpToTaobao {
    NSLog(@"[TaobaoJump] 🚀 跳转淘宝被点击");
    
    if (!g_currentMessageContent || g_currentMessageContent.length == 0) {
        NSLog(@"[TaobaoJump] ❌ 没有消息内容");
        return;
    }
    
    NSLog(@"[TaobaoJump] 📋 准备复制内容: %@", g_currentMessageContent);
    
    // 复制到剪贴板
    [[UIPasteboard generalPasteboard] setString:g_currentMessageContent];
    
    // 打开淘宝
    NSURL *taobaoURL = [NSURL URLWithString:@"taobao://"];
    
    if ([[UIApplication sharedApplication] canOpenURL:taobaoURL]) {
        [[UIApplication sharedApplication] openURL:taobaoURL 
                                           options:@{} 
                                 completionHandler:^(BOOL success) {
            if (success) {
                NSLog(@"[TaobaoJump] ✅ 成功打开淘宝");
            } else {
                NSLog(@"[TaobaoJump] ❌ 打开淘宝失败");
            }
        }];
    } else {
        NSLog(@"[TaobaoJump] ❌ 无法打开淘宝 URL，请确认已安装淘宝");
    }
    
    // 清空消息内容
    g_currentMessageContent = nil;
}

%end

%ctor {
    %init;
    NSLog(@"[TaobaoJump] 🎉 淘口令跳转功能已加载");
    NSLog(@"[TaobaoJump] 📊 功能状态: %@", isTaobaoJumpEnabled() ? @"已启用" : @"未启用");
}
