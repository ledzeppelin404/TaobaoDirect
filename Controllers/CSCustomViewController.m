#import "CSCustomViewController.h"
#import "CSSettingTableViewCell.h"
#import "CSUserInfoHelper.h"
#import "CSBackgroundRunViewController.h"
#import "CSGameCheatsViewController.h"
#import "CSEntrySettingsViewController.h"
#import "CSResetSettingsViewController.h"
#import "CSTaobaoJumpViewController.h"
#import "CSCardKeyValidator.h"

// UI 常量
static CGFloat const kHeaderViewHeight = 150.0f;        // 头部视图高度
static CGFloat const kAvatarSize = 80.0f;              // 头像大小
static CGFloat const kAvatarTopMargin = 0.0f;         // 头像顶部间距
static CGFloat const kNicknameTopMargin = 15.0f;       // 昵称顶部间距
static CGFloat const kNicknameHeight = 25.0f;          // 昵称高度
static CGFloat const kWXIDTopMargin = 5.0f;            // 微信号顶部间距
static CGFloat const kWXIDHeight = 20.0f;              // 微信号高度
static CGFloat const kLabelHorizontalMargin = 20.0f;   // 标签水平间距

// 字体大小
static CGFloat const kNicknameFontSize = 20.0f;        // 昵称字体大小
static CGFloat const kWXIDFontSize = 14.0f;            // 微信号字体大小

// 头像缓存Key
static NSString * const kAvatarCacheKey = @"com.wechat.tweak.avatar.cache";
// 用户协议同意标记
static NSString * const kUserAgreementAcceptedKey = @"com.wechat.tweak.user.agreement.accepted.v3";

@interface CSCustomViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<CSSettingSection *> *sections;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *wxidLabel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSTimer *countdownTimer; // 倒计时计时器
@property (nonatomic, assign) NSInteger countdownSeconds; // 倒计时剩余秒数
@property (nonatomic, strong) UIAlertAction *continueAction; // 继续按钮引用
@end

@implementation CSCustomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置标题
    self.title = @"微信设置";
    
    // 设置UI样式
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    
    // 注册设置单元格
    [CSSettingTableViewCell registerToTableView:self.tableView];
    
    // 设置数据
    [self setupData];
    
    // 隐藏导航栏标题
    self.navigationItem.title = @"";
    [self setupHeaderView];
    [self setupUI];
    
    // 预加载头像，在界面显示前就开始加载
    [self preloadAvatarImage];
}

// 添加viewDidAppear方法，在视图显示后检查用户协议和卡密
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 先检查用户协议，再检查卡密
    [self checkUserAgreement];
}

// 检查用户是否已同意使用声明
- (void)checkUserAgreement {
    BOOL hasAccepted = [[NSUserDefaults standardUserDefaults] boolForKey:kUserAgreementAcceptedKey];
    if (!hasAccepted) {
        // 如果用户尚未同意，显示声明弹窗
        [self showUserAgreementAlert];
    } else {
        // 已同意协议，检查卡密激活
        [self checkCardKeyActivation];
    }
}

// 检查卡密激活状态
- (void)checkCardKeyActivation {
    if (![CSCardKeyValidator isActivated]) {
        // 如果未激活，显示卡密验证弹窗
        [self showCardKeyAlert];
    }
}

// 显示用户协议弹窗
- (void)showUserAgreementAlert {
    // 使用UIAlertController创建弹窗
    UIAlertController *alertController = [UIAlertController 
                                          alertControllerWithTitle:@"用户使用声明" 
                                          message:[self userAgreementText]
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加继续按钮 - 第一步只显示协议内容
    self.continueAction = [UIAlertAction 
                          actionWithTitle:@"请等待8秒" 
                          style:UIAlertActionStyleDefault 
                          handler:^(UIAlertAction * _Nonnull action) {
        // 用户点击继续后，显示第二步确认界面
        [self showAgreementConfirmAlert];
    }];
    
    // 禁用继续按钮，倒计时后启用
    self.continueAction.enabled = NO;
    
    [alertController addAction:self.continueAction];
    
    // 显示弹窗
    [self presentViewController:alertController animated:YES completion:^{
        // 弹窗显示后，开始倒计时
        self.countdownSeconds = 8;
        self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                              target:self
                                                            selector:@selector(updateCountdown)
                                                            userInfo:nil
                                                             repeats:YES];
    }];
}

// 更新倒计时
- (void)updateCountdown {
    self.countdownSeconds--;
    
    if (self.countdownSeconds <= 0) {
        // 倒计时结束，停止计时器
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
        
        // 启用继续按钮
        self.continueAction.enabled = YES;
        
        // 更新按钮标题
        [self.continueAction setValue:@"继续" forKey:@"title"];
    } else {
        // 更新按钮标题，显示剩余时间
        NSString *title = [NSString stringWithFormat:@"请等待%ld秒", (long)self.countdownSeconds];
        [self.continueAction setValue:title forKey:@"title"];
    }
}

// 显示确认输入界面 - 第二步
- (void)showAgreementConfirmAlert {
    UIAlertController *confirmAlert = [UIAlertController 
                                       alertControllerWithTitle:@"确认同意" 
                                       message:@"请输入\"我已阅读并同意\"以确认您已阅读并同意用户协议"
                                       preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加文本框，要求用户输入"我已阅读并同意"
    [confirmAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入\"我已阅读并同意\"";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    
    // 添加同意按钮
    UIAlertAction *agreeAction = [UIAlertAction 
                                  actionWithTitle:@"确认" 
                                  style:UIAlertActionStyleDefault 
                                  handler:^(UIAlertAction * _Nonnull action) {
        // 获取用户输入的文本
        UITextField *textField = confirmAlert.textFields.firstObject;
        NSString *userInput = textField.text;
        
        // 验证用户输入是否为"我已阅读并同意"
        if ([userInput isEqualToString:@"我已阅读并同意"]) {
            // 保存用户同意状态
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kUserAgreementAcceptedKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 同意后检查卡密激活
            [self checkCardKeyActivation];
        } else {
            // 如果输入不正确，重新显示弹窗，并提示用户输入错误
            UIAlertController *errorAlert = [UIAlertController
                                             alertControllerWithTitle:@"输入错误"
                                             message:@"请正确输入\"我已阅读并同意\"才能继续使用"
                                             preferredStyle:UIAlertControllerStyleAlert];
            
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"重试"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                // 重新显示确认界面
                [self showAgreementConfirmAlert];
            }]];
            
            [self presentViewController:errorAlert animated:YES completion:nil];
        }
    }];
    
    // 添加返回按钮，返回到协议阅读界面
    UIAlertAction *backAction = [UIAlertAction 
                                actionWithTitle:@"返回" 
                                style:UIAlertActionStyleDefault 
                                handler:^(UIAlertAction * _Nonnull action) {
        // 返回到协议阅读界面
        [self showUserAgreementAlert];
    }];
    
    [confirmAlert addAction:agreeAction];
    [confirmAlert addAction:backAction];
    
    // 显示弹窗
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

// 用户协议文本
- (NSString *)userAgreementText {
    return @"尊敬的用户：\n\n"
           @"欢迎使用本微信插件功能。使用本插件前，请您仔细阅读以下声明：\n\n"
           @"1. 本插件由愫茶开发，仅在Telegram频道发布。\n\n"
           @"2. 二次发布必须保留原始开发者署名，改名干嘛？自己不会写啊？？\n\n"
           @"3. 本插件仅供个人学习研究使用，不得用于任何商业用途。\n\n"
           @"4. 严禁恶意改名盈利，所有未经授权进行商业用途的行为将被永久拉黑。\n\n"
           @"5. 使用本插件可能违反微信软件的使用条款，可能导致您的微信账号被封禁或限制。\n\n"
           @"6. 您应自行承担使用本插件的全部风险和法律责任，开发者不对因使用本插件导致的任何直接或间接损失负责。\n\n"
           @"7. 严禁利用本插件从事任何违法违规活动，包括但不限于侵犯他人隐私、进行网络诈骗等。\n\n"
           @"8. 开发者保留随时修改、中断或终止本插件的权利，无需事先通知。";
}

// 显示卡密验证弹窗
- (void)showCardKeyAlert {
    UIAlertController *alertController = [UIAlertController 
                                          alertControllerWithTitle:@"激活插件" 
                                          message:@"请输入卡密以激活插件\n\n卡密获取方式：\n联系开发者购买"
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加卡密输入框
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入卡密";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    
    // 添加激活按钮
    UIAlertAction *activateAction = [UIAlertAction 
                                    actionWithTitle:@"激活" 
                                    style:UIAlertActionStyleDefault 
                                    handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alertController.textFields.firstObject;
        NSString *cardKey = textField.text;
        
        if (!cardKey || cardKey.length == 0) {
            [self showErrorAlert:@"请输入卡密" retry:YES];
            return;
        }
        
        // 显示加载提示
        [self showLoadingAlert];
        
        // 验证卡密
        [CSCardKeyValidator validateCardKey:cardKey completion:^(BOOL success, NSString *message, NSDate * _Nullable expireDate) {
            [self dismissViewControllerAnimated:YES completion:^{
                if (success) {
                    // 格式化到期时间
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                    NSString *expireDateString = [formatter stringFromDate:expireDate];
                    
                    NSString *successMessage = [NSString stringWithFormat:@"激活成功！\n\n到期时间：\n%@", expireDateString];
                    [self showSuccessAlert:successMessage];
                } else {
                    [self showErrorAlert:message retry:YES];
                }
            }];
        }];
    }];
    
    // 添加返回按钮
    UIAlertAction *backAction = [UIAlertAction 
                                actionWithTitle:@"返回" 
                                style:UIAlertActionStyleCancel 
                                handler:^(UIAlertAction * _Nonnull action) {
        // 用户选择返回，关闭设置页面回到微信主界面
        [self.navigationController popViewControllerAnimated:YES];
    }];
    
    [alertController addAction:activateAction];
    [alertController addAction:backAction];
    
    // 显示弹窗
    [self presentViewController:alertController animated:YES completion:nil];
}

// 显示加载提示
- (void)showLoadingAlert {
    UIAlertController *loadingAlert = [UIAlertController 
                                       alertControllerWithTitle:@"正在验证" 
                                       message:@"请稍候..."
                                       preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:loadingAlert animated:YES completion:nil];
}

// 显示成功提示
- (void)showSuccessAlert:(NSString *)message {
    UIAlertController *successAlert = [UIAlertController 
                                       alertControllerWithTitle:@"激活成功" 
                                       message:message
                                       preferredStyle:UIAlertControllerStyleAlert];
    
    [successAlert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                                     style:UIAlertActionStyleDefault 
                                                   handler:nil]];
    
    [self presentViewController:successAlert animated:YES completion:nil];
}

// 显示错误提示
- (void)showErrorAlert:(NSString *)message retry:(BOOL)retry {
    UIAlertController *errorAlert = [UIAlertController 
                                     alertControllerWithTitle:@"验证失败" 
                                     message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    
    if (retry) {
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"重试" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:^(UIAlertAction * _Nonnull action) {
            [self showCardKeyAlert];
        }]];
    } else {
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil]];
    }
    
    [self presentViewController:errorAlert animated:YES completion:nil];
}

// 预加载头像图片
- (void)preloadAvatarImage {
    // 添加加载指示器
    if (!self.loadingIndicator) {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        self.loadingIndicator.center = self.avatarImageView.center;
        [self.headerView addSubview:self.loadingIndicator];
        [self.loadingIndicator startAnimating];
    }
    
    // 1. 先尝试从内存缓存加载
    NSData *cachedImageData = [[NSUserDefaults standardUserDefaults] objectForKey:kAvatarCacheKey];
    if (cachedImageData) {
        UIImage *cachedImage = [UIImage imageWithData:cachedImageData];
        if (cachedImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.avatarImageView.image = cachedImage;
                [self.loadingIndicator stopAnimating];
                [self.loadingIndicator removeFromSuperview];
            });
            return;
        }
    }
    
    // 2. 如果内存缓存没有，则从URL加载
    NSString *avatarURL = [[NSUserDefaults standardUserDefaults] objectForKey:kUserAvatarURLKey];
    if (avatarURL.length > 0) {
        NSURL *url = [NSURL URLWithString:avatarURL];
        if (url) {
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error || !data) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.loadingIndicator stopAnimating];
                        [self.loadingIndicator removeFromSuperview];
                    });
                    return;
                }
                
                UIImage *image = [UIImage imageWithData:data];
                if (!image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.loadingIndicator stopAnimating];
                        [self.loadingIndicator removeFromSuperview];
                    });
                    return;
                }
                
                // 缓存图片数据
                [[NSUserDefaults standardUserDefaults] setObject:data forKey:kAvatarCacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 设置图片
                    self.avatarImageView.image = image;
                    
                    // 确保圆角
                    self.avatarImageView.layer.cornerRadius = kAvatarSize / 2;
                    self.avatarImageView.layer.masksToBounds = YES;
                    
                    // 停止加载指示器
                    [self.loadingIndicator stopAnimating];
                    [self.loadingIndicator removeFromSuperview];
                });
            }];
            [task resume];
        }
    } else {
        // 如果没有URL，则使用CSUserInfoHelper获取
        [self loadAvatarImage];
    }
}

// 加载头像图片 (备用方法，当预加载失败时使用)
- (void)loadAvatarImage {
    NSString *avatarURL = [CSUserInfoHelper getUserAvatarURL];
    if (avatarURL.length > 0) {
        NSURL *url = [NSURL URLWithString:avatarURL];
        if (url) {
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error || !data) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.loadingIndicator stopAnimating];
                        [self.loadingIndicator removeFromSuperview];
                    });
                    return;
                }
                
                UIImage *image = [UIImage imageWithData:data];
                if (!image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.loadingIndicator stopAnimating];
                        [self.loadingIndicator removeFromSuperview];
                    });
                    return;
                }
                
                // 缓存图片数据
                [[NSUserDefaults standardUserDefaults] setObject:data forKey:kAvatarCacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 设置图片
                    self.avatarImageView.image = image;
                    
                    // 确保圆角
                    self.avatarImageView.layer.cornerRadius = kAvatarSize / 2;
                    self.avatarImageView.layer.masksToBounds = YES;
                    
                    // 停止加载指示器
                    [self.loadingIndicator stopAnimating];
                    [self.loadingIndicator removeFromSuperview];
                });
            }];
            [task resume];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            [self.loadingIndicator removeFromSuperview];
        });
    }
}

- (void)setupHeaderView {
    // 创建头部视图
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kHeaderViewHeight)];
    self.headerView.backgroundColor = [UIColor clearColor];
    
    // 创建头像视图
    self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - kAvatarSize) / 2, 
                                                                        kAvatarTopMargin, 
                                                                        kAvatarSize, 
                                                                        kAvatarSize)];
    self.avatarImageView.layer.cornerRadius = kAvatarSize / 2;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = [UIColor systemGray5Color];
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    
    // 设置默认头像
    if (@available(iOS 13.0, *)) {
        UIImage *defaultAvatar = [UIImage systemImageNamed:@"person.crop.circle.fill"];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:60 weight:UIImageSymbolWeightRegular];
        self.avatarImageView.image = [defaultAvatar imageWithConfiguration:config];
        self.avatarImageView.tintColor = [UIColor systemGray3Color];
    }
    
    // 创建昵称标签
    self.nicknameLabel = [[UILabel alloc] initWithFrame:CGRectMake(kLabelHorizontalMargin, 
                                                                  CGRectGetMaxY(self.avatarImageView.frame) + kNicknameTopMargin,
                                                                  self.view.bounds.size.width - 2 * kLabelHorizontalMargin, 
                                                                  kNicknameHeight)];
    self.nicknameLabel.textAlignment = NSTextAlignmentCenter;
    self.nicknameLabel.font = [UIFont systemFontOfSize:kNicknameFontSize weight:UIFontWeightMedium];
    self.nicknameLabel.text = [CSUserInfoHelper getUserNickname];
    
    // 创建微信号标签
    self.wxidLabel = [[UILabel alloc] initWithFrame:CGRectMake(kLabelHorizontalMargin,
                                                              CGRectGetMaxY(self.nicknameLabel.frame) + kWXIDTopMargin,
                                                              self.view.bounds.size.width - 2 * kLabelHorizontalMargin,
                                                              kWXIDHeight)];
    self.wxidLabel.textAlignment = NSTextAlignmentCenter;
    self.wxidLabel.font = [UIFont systemFontOfSize:kWXIDFontSize];
    self.wxidLabel.textColor = [UIColor systemGrayColor];
    NSString *aliasName = [CSUserInfoHelper getUserAliasName];
    self.wxidLabel.text = [NSString stringWithFormat:@"微信号: %@", aliasName ?: @"未知"];
    
    // 添加视图到headerView
    [self.headerView addSubview:self.avatarImageView];
    [self.headerView addSubview:self.nicknameLabel];
    [self.headerView addSubview:self.wxidLabel];
    
    // 加载头像
    [self loadAvatarImage];
}

- (void)setupData {
    // 功能增强组
    CSSettingItem *backgroundRunItem = [CSSettingItem itemWithTitle:@"后台运行" 
                                                         iconName:@"arrow.clockwise.icloud" 
                                                        iconColor:[UIColor systemPurpleColor]
                                                          detail:nil];
    
    CSSettingItem *gameCheatsItem = [CSSettingItem itemWithTitle:@"游戏辅助"
                                                      iconName:@"gamecontroller.fill"
                                                     iconColor:[UIColor systemGreenColor]
                                                       detail:nil];

    // 添加淘口令跳转设置项
    CSSettingItem *taobaoJumpItem = [CSSettingItem itemWithTitle:@"淘口令跳转"
                                                       iconName:@"cart.fill"
                                                      iconColor:[UIColor systemOrangeColor]
                                                        detail:nil];

    CSSettingSection *enhancementSection = [CSSettingSection sectionWithHeader:@"功能增强" 
                                                                      items:@[backgroundRunItem,
                                                                             gameCheatsItem,
                                                                             taobaoJumpItem]];
    
    // 插件设置组
    CSSettingItem *entrySettingsItem = [CSSettingItem itemWithTitle:@"入口设置"
                                                         iconName:@"door.right.hand.open"
                                                        iconColor:[UIColor systemBrownColor]
                                                          detail:nil];
    
    // 添加重置设置项
    CSSettingItem *resetSettingsItem = [CSSettingItem itemWithTitle:@"重置设置"
                                                         iconName:@"arrow.counterclockwise.circle"
                                                        iconColor:[UIColor systemRedColor]
                                                          detail:nil];
    
    CSSettingSection *pluginSection = [CSSettingSection sectionWithHeader:@"插件设置"
                                                                 items:@[entrySettingsItem, 
                                                                        resetSettingsItem]];
    
    // 关于组
    CSSettingItem *versionItem = [CSSettingItem itemWithTitle:@"版本信息"
                                                   iconName:@"info.circle"
                                                  iconColor:[UIColor systemBlueColor]
                                                    detail:kPluginVersionString];
    
    CSSettingSection *aboutSection = [CSSettingSection sectionWithHeader:@"关于"
                                                                 items:@[versionItem]];
    
    self.sections = @[enhancementSection, pluginSection, aboutSection];
}

- (void)setupUI {
    // 设置背景颜色
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 创建并配置tableView
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 设置分割线样式
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    
    // 设置tableView的头部视图
    self.tableView.tableHeaderView = self.headerView;
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // 注册通用设置cell
    [CSSettingTableViewCell registerToTableView:self.tableView];
    
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CSSettingTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[CSSettingTableViewCell reuseIdentifier]];
    
    // 获取当前项数据并配置cell
    CSSettingItem *item = self.sections[indexPath.section].items[indexPath.row];
    [cell configureWithItem:item];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].header;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 获取点击的item
    CSSettingItem *item = self.sections[indexPath.section].items[indexPath.row];
    
    // 根据item类型和标题处理不同的点击事件
    if (item.itemType == CSSettingItemTypeNormal) {
        // 处理后台运行点击
        if ([item.title isEqualToString:@"后台运行"]) {
            CSBackgroundRunViewController *backgroundVC = [[CSBackgroundRunViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:backgroundVC animated:YES];
        }
        // 处理游戏辅助点击
        else if ([item.title isEqualToString:@"游戏辅助"]) {
            CSGameCheatsViewController *gameCheatsVC = [[CSGameCheatsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:gameCheatsVC animated:YES];
        }
        // 处理淘口令跳转点击
        else if ([item.title isEqualToString:@"淘口令跳转"]) {
            CSTaobaoJumpViewController *taobaoJumpVC = [[CSTaobaoJumpViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:taobaoJumpVC animated:YES];
        }
        // 处理入口设置点击
        else if ([item.title isEqualToString:@"入口设置"]) {
            CSEntrySettingsViewController *entrySettingsVC = [[CSEntrySettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:entrySettingsVC animated:YES];
        }
        // 处理重置设置点击
        else if ([item.title isEqualToString:@"重置设置"]) {
            CSResetSettingsViewController *resetVC = [[CSResetSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:resetVC animated:YES];
        }
    }
    // 处理输入类型项的点击
    else if (item.itemType == CSSettingItemTypeInput) {
        [CSUIHelper showInputAlertWithTitle:item.title
                                  message:nil
                               initialValue:item.inputValue
                               placeholder:item.inputPlaceholder
                          inViewController:self
                                completion:^(NSString *value) {
            // 更新item的值
            item.inputValue = value;
            
            // 刷新表格
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            
            // 执行回调
            if (item.inputValueChanged) {
                item.inputValueChanged(value);
            }
        }];
    }
}

// 设置cell的背景色
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 使用secondarySystemGroupedBackgroundColor来获得正确的深色模式下的背景色
    if (@available(iOS 13.0, *)) {
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    // 配置选中状态的背景色
    UIView *selectedBackgroundView = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        selectedBackgroundView.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    } else {
        selectedBackgroundView.backgroundColor = [UIColor systemGray5Color];
    }
    cell.selectedBackgroundView = selectedBackgroundView;
}

@end 