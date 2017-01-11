//
//  BYTextFieldDrag.h
//  BYResign
//
//  Created by kimiLin on 2016/12/29.
//  Copyright © 2016年 kimiLin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BYTextFieldDrag : NSTextField
@property (nonatomic, assign) BOOL isMuti; // 是否多个元素
@property (nonatomic, copy) NSString * seperator; // 多元素时的分隔符
@end
