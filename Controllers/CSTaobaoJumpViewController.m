//
//  CSTaobaoJumpViewController.m
//  淘口令自动跳转设置
//

#import "CSTaobaoJumpViewController.h"
#import "CSSettingTableViewCell.h"

static NSString * const kTaobaoJumpEnabledKey = @"TaobaoJump_Enabled";

@interface CSTaobaoJumpViewController ()
@property (nonatomic, strong) NSArray<CSSettingSection *> *sections;
@property (nonatomic, assign) BOOL taobaoJumpEnabled;
@end

@implementation CSTaobaoJumpViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"淘口令跳转";
    
    // 设置UI样式
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    
    // 注册设置单元格
    [CSSettingTableViewCell registerToTableView:self.tableView];
    
    // 加载设置
    [self loadSettings];
    
    // 设置数据
    [self setupData];
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.taobaoJumpEnabled = [defaults boolForKey:kTaobaoJumpEnabledKey];
}

- (void)setupData {
    // 功能开关
    __weak typeof(self) weakSelf = self;
    CSSettingItem *enableItem = [CSSettingItem switchItemWithTitle:@"启用淘口令跳转"
                                                            detail:@"长按消息显示\"跳转淘宝\"菜单"
                                                              icon:nil
                                                                on:self.taobaoJumpEnabled
                                                      toggleAction:^(BOOL isOn) {
        weakSelf.taobaoJumpEnabled = isOn;
        [weakSelf saveSettings];
    }];
    
    CSSettingSection *functionSection = [CSSettingSection sectionWithHeader:@"功能设置"
                                                                     items:@[enableItem]];
    
    // 使用说明
    CSSettingItem *descItem = [CSSettingItem itemWithTitle:@"使用说明"
                                                    detail:@"长按聊天消息，在弹出菜单中选择\"跳转淘宝\"，自动复制内容并打开淘宝App"
                                                      icon:nil
                                              accessoryType:UITableViewCellAccessoryNone
                                              selectionAction:nil];
    
    CSSettingItem *tipItem = [CSSettingItem itemWithTitle:@"温馨提示"
                                                   detail:@"适用于淘口令、商品链接等需要在淘宝中打开的内容"
                                                     icon:nil
                                             accessoryType:UITableViewCellAccessoryNone
                                             selectionAction:nil];
    
    CSSettingSection *infoSection = [CSSettingSection sectionWithHeader:@"说明"
                                                                  items:@[descItem, tipItem]];
    
    self.sections = @[functionSection, infoSection];
    
    [self.tableView reloadData];
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.taobaoJumpEnabled forKey:kTaobaoJumpEnabledKey];
    [defaults synchronize];
    
    // 显示保存成功提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置已保存"
                                                                   message:@"重启微信后生效"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CSSettingTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[CSSettingTableViewCell reuseIdentifier]
                                                                   forIndexPath:indexPath];
    
    CSSettingSection *section = self.sections[indexPath.section];
    CSSettingItem *item = section.items[indexPath.row];
    
    [cell configureWithItem:item];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].header;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CSSettingSection *section = self.sections[indexPath.section];
    CSSettingItem *item = section.items[indexPath.row];
    
    if (item.selectionAction) {
        item.selectionAction();
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0f;
}

@end
