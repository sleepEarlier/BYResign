//
//  ViewController.m
//  BYResign
//
//  Created by kimiLin on 2016/12/29.
//  Copyright © 2016年 kimiLin. All rights reserved.
//

#import "ViewController.h"
#import "BYTextFieldDrag.h"
#import "TaskManager.h"

static NSString *IPAKey = @"BY_IPA_PATH_KEY";
static NSString *resourceKey = @"REOURCE_KEY";
static NSString *PPKey = @"PROVISIONING_PROFILE_KEY";
static NSString *modifyEnableKey = @"BUNDLE_ID_MODYFY_ENABLE";
static NSString *bundleIDKey = @"BUNDLE_ID_KEY";

@interface ViewController ()<NSComboBoxDataSource,NSComboBoxDelegate>
{
    NSFileManager *fm;
    NSString *workFloder;
    NSString *targetFloder;
    NSString *payloadPath;
    NSString *infoPlistPath;
    NSString *embededPath;
}
@property (weak) IBOutlet BYTextFieldDrag *ipaField;
@property (weak) IBOutlet BYTextFieldDrag *resourceField;
@property (weak) IBOutlet BYTextFieldDrag *ppField;
@property (weak) IBOutlet NSTextField *bundleIdField;
@property (weak) IBOutlet NSButton *ipaBrowse;
@property (weak) IBOutlet NSButton *resourceBrowse;
@property (weak) IBOutlet NSButton *ppBrowse;
@property (weak) IBOutlet NSComboBox *box;
@property (weak) IBOutlet NSButton *resignBtn;
@property (weak) IBOutlet NSButton *bundleIdCheckBtn;
@property (weak) IBOutlet NSProgressIndicator *indicator;
@property (weak) IBOutlet NSTextField *status;

@property (nonatomic, strong) NSMutableArray *cerNames;
@property (nonatomic, strong) NSMutableArray *cerSHA1s;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self dataInit];
    [self toolsCheck];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self getCerts];
    });
    [self dataHandlerForLoad:YES];
}

- (void)testData {
    self.ipaField.stringValue = @"/Users/kimilin/Downloads/target.ipa";
    self.resourceField.stringValue = @"/Users/kimilin/Downloads/LJDebug/dfqp_v3.0.app/scripts/regionConfig710.lua";
    self.ppField.stringValue = @"";
    self.bundleIdField.stringValue = @"";
    [self.box selectItemWithObjectValue:@"iPhone Distribution: lian wen (5QVFGL3BHF)"]; //1852277D7E547D424D50597AB7E817DB2D85DB46
}

- (void)dataInit {
    fm = [NSFileManager defaultManager];
    workFloder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"BYResign"];
    NSLog(@"%@",workFloder);
    BOOL result = [fm createDirectoryAtPath:workFloder withIntermediateDirectories:YES attributes:nil error:nil];
    if (!result) {
        [self showAlertWithMsg:@"无法创建临时工作目录，请重启后尝试。"];
        return;
    }
    self.cerNames  = @[].mutableCopy;
    self.cerSHA1s = @[].mutableCopy;
    
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    if (![df objectForKey:IPAKey]) {
        [df setObject:@"" forKey:IPAKey];
        [df setObject:@"" forKey:resourceKey];
        [df setObject:@"" forKey:PPKey];
        [df setObject:@(NO) forKey:modifyEnableKey];
        [df setObject:@"" forKey:bundleIDKey];
    }
    self.status.stringValue = @"获取证书中...";
}

- (void)getCerts {

    [TaskManager launchTaskWithPath:@"/usr/bin/security" args:@[@"find-identity", @"-v", @"-p", @"codesigning"] onSuccess:^(NSString *resultString) {
        
        NSArray<NSString *> *arr = [resultString componentsSeparatedByString:@"\n"];
        [arr enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![obj containsString:@"valid identities found"]) {
                // Search SHA
                NSString *re = @"\\) [\\w\\d]+";
                NSRange range = [obj rangeOfString:re options:NSRegularExpressionSearch];
                if (range.length > 0) {
                    NSString *sha = [[obj substringWithRange:range] substringFromIndex:2];
                    [self.cerSHA1s addObject:sha];
                }
                
                // Search Common Name
                re = @"iPhone[\\d\\D]+?\"";
                range = [obj rangeOfString:re options:NSRegularExpressionSearch];
                if (range.length > 0) {
                    NSString *result =  [obj substringWithRange:range];
                    NSString *cerName = [result substringToIndex:result.length-1];
                    [self.cerNames addObject:cerName];
                }
            }
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 可能出现同名的新旧证书，两者SHA1不同但名称完全一致，因此无法进行过滤，保留重复项
            if (self.cerNames.count != self.cerSHA1s.count) {
                self.status.stringValue = @"正则匹配错误，证书名与SHA1数量不匹配";
                [self showAlertWithMsg:@"正则匹配错误，证书名与SHA1数量不匹配"];
            } else {
                if (self.cerNames.count == 0) {
                    self.status.stringValue = @"此Mac上还没有可用的证书";
                    [self showAlertWithMsg:@"此Mac上还没有可用的证书"];
                    return ;
                }
                
                self.status.stringValue = @"准备签名";
                [self.box addItemsWithObjectValues:self.cerNames];
            }
        });
        
    } onFail:^(NSString *resultString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlertWithMsg:resultString];
        });
        
    }];
}

#pragma mark - Action

- (IBAction)browseFile:(NSButton *)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    if (sender.tag == 0) { [openDlg setAllowedFileTypes:@[@"IPA",@"ipa"]]; }
    else if (sender.tag == 1) {
        [openDlg setAllowsMultipleSelection:YES];
        [openDlg setAllowedFileTypes:nil];
    }
    else if (sender.tag == 2) { [openDlg setAllowedFileTypes:@[@"mobileprovision"]]; }
    
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        NSLog(@"chooseFile:%@",fileNameOpened);
        if (sender.tag == 0) { // IPA
            
            self.ipaField.stringValue = fileNameOpened;
        }
        else if (sender.tag == 1) { // 替换资源
            NSArray *urls = [openDlg URLs];
            NSMutableArray *pathes = [NSMutableArray arrayWithCapacity:urls.count];
            for (NSURL *ul in urls) {
                if (ul.path) {
                    [pathes addObject:ul.path];
                }
            }
            self.resourceField.stringValue = [pathes componentsJoinedByString:self.resourceField.seperator];
        }
        else if (sender.tag == 2) { // 描述文件
            self.ppField.stringValue = fileNameOpened;
        }
    }
}

- (IBAction)onResign:(NSButton *)sender {
    
    BOOL result = [fm createDirectoryAtPath:workFloder withIntermediateDirectories:YES attributes:nil error:nil];
    if (!result) {
        [self showAlertWithMsg:@"无法创建临时工作目录，请重启后尝试。"];
        return;
    }
    
    [self controlsEnable:NO];
    
    
    if (![self dataCheckBeforeResign]) {
        return;
    }
    
    [self dataHandlerForLoad:NO];
    
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"resign" ofType:@"pyc"];
    if (![fm fileExistsAtPath:scriptPath]) {
        scriptPath = [[NSBundle mainBundle] pathForResource:@"resign" ofType:@"py"];
    }
    if (![fm fileExistsAtPath:scriptPath]) {
        [self showAlertWithMsg:@"工具资源不完整，无法签名"];
        return;
    }
    
    NSArray *arguments = @[
                           scriptPath, // script
                           self.ipaField.stringValue, // IPA
                           self.resourceField.stringValue, // resource
                           self.ppField.stringValue, // PP file
                           self.bundleIdField.stringValue, // new BundleId
                           self.cerSHA1s[self.box.indexOfSelectedItem], // sha1
                           self.box.objectValueOfSelectedItem, // cerName
                           workFloder // tempFloder to use
                           ];
    
    __weak typeof(self)weakSelf = self;

    
    self.status.stringValue = @"签名中...";
    
    [TaskManager launchTaskWithPath:@"/usr/bin/python" args:arguments onSuccess:^(NSString *resultString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf controlsEnable:YES];
            weakSelf.status.stringValue = @"重签名成功!";
        });
        
    } onFail:^(NSString *resultString) {
        
        NSLog(@"fail:%@",resultString);
        NSString *msg = [[resultString componentsSeparatedByString:@"\n"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [evaluatedObject length] > 0;
        }]].lastObject;
        [self showAlertWithMsg:msg];
        
    }];
}

#pragma mark Alert
- (void)showAlertWithMsg:(NSString *)msg{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"错误"];
        [alert setInformativeText:msg];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert runModal];
        [self controlsEnable:YES];
    });
}

#pragma mark - ComboBox DataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return  self.cerNames.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return self.cerNames[index];
}
 
#pragma mark - Help
- (void)controlsEnable:(BOOL)enabled {
    NSArray *controls = @[_ipaField, _resourceField, _ppField, _bundleIdField,_ipaBrowse,_resourceBrowse,_ppBrowse,_box,_resignBtn,_bundleIdCheckBtn];
    for (NSControl *ctr in controls) {
        ctr.enabled = enabled;
    }
    
    if (enabled) {
        [_indicator stopAnimation:self];
        _status.stringValue = @"准备签名";
    } else {
        [_indicator startAnimation:self];
    }
}

- (void)toolsCheck {
    NSArray<NSString *> *path = @[@"/usr/bin/zip",@"/usr/bin/unzip",@"/usr/bin/codesign",@"/usr/bin/security",@"/bin/cp",@"/usr/bin/python"];
    [path enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![fm fileExistsAtPath:obj]) {
            [self showAlertWithMsg:[NSString stringWithFormat:@"Mac环境缺少%@",obj]];
            *stop = YES;
        }
    }];
}

- (BOOL)dataCheckBeforeResign {
    
    __block NSString *message = nil;
    if (self.ipaField.stringValue.length < 1) {
        message = @"请设置重签名IPA包路径";
    }
//    else if (self.resourceField.stringValue.length < 1) {
//        message = @"请设置Lua脚本路径";
//    }
    else if (self.bundleIdCheckBtn.state == NSOnState && self.bundleIdField.stringValue.length < 1) {
        message = @"请设置新的BundleId";
    }
    else if (!self.box.objectValueOfSelectedItem) {
        message = @"请选择签名证书";
    }
    else {
        
        // 资源路径支持多个
        if ([self.resourceField.stringValue hasSuffix:self.resourceField.seperator]) {
            self.resourceField.stringValue = [self.resourceField.stringValue substringToIndex:self.resourceField.stringValue.length-1];
        }
        
        NSArray<NSString *> *resourcePathes = [self.resourceField.stringValue componentsSeparatedByString:self.resourceField.seperator];
        
        // 路径都存在
        if (![self.ipaField.stringValue hasSuffix:@".ipa"]) {
            message = @"IPA路径未指向IPA类型文件";
        }
        else if (![fm fileExistsAtPath:self.ipaField.stringValue]) {
            message = [NSString stringWithFormat:@"IPA文件:\"%@\"不存在",self.ipaField.stringValue.lastPathComponent];
        }
        else if (resourcePathes.count > 0) {
            for (NSString *singlePath in resourcePathes) {
                if (![fm fileExistsAtPath:singlePath]) {
                    message = [NSString stringWithFormat:@"资源文件:\"%@\"不存在",singlePath.lastPathComponent];
                    break;
                }
            }
        }
        else if (self.ppField.stringValue.length > 0) {
            if (![self.ppField.stringValue hasSuffix:@"mobileprovision"]) {
                message = @"描述文件类型错误";
            }
            if (![fm fileExistsAtPath:self.ppField.stringValue]) {
                message = [NSString stringWithFormat:@"描述文件:\"%@\"不存在",self.ppField.stringValue.lastPathComponent];
            }
        }
        
    }
    if (message) {
        [self showAlertWithMsg:message];
        return NO;
    }
    if (self.bundleIdCheckBtn.state == NSOffState) {
        self.bundleIdField.stringValue = @"";
    }
    return YES;
}

- (void)dataHandlerForLoad:(BOOL)isLoad {
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    if (isLoad) {
        _ipaField.stringValue = [df objectForKey:IPAKey];
        _resourceField.stringValue = [df objectForKey:resourceKey];
        _ppField.stringValue = [df objectForKey:PPKey];
        NSNumber *enable = [df objectForKey:modifyEnableKey];
        if (enable.boolValue) {
            _bundleIdField.stringValue = [df objectForKey:bundleIDKey];
        }
    } else {
        [df setObject:_ipaField.stringValue forKey:IPAKey];
        [df setObject:_resourceField.stringValue forKey:resourceKey];
        [df setObject:_ppField.stringValue forKey:PPKey];
        [df setObject:@(_bundleIdCheckBtn.enabled) forKey:modifyEnableKey];
        if (_bundleIdCheckBtn.enabled) {
            [df setObject:_bundleIdField.stringValue forKey:bundleIDKey];
        } else {
            [df setObject:@"" forKey:bundleIDKey];
        }
        [df synchronize];
    }
}

@end
