//
//  TaskManager.h
//  BYResign
//
//  Created by kimiLin on 2016/12/29.
//  Copyright © 2016年 kimiLin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^TaskResult)(NSString *resultString);

@interface TaskManager : NSObject

+ (NSTask *)launchTaskWithPath:(NSString *)path args:(NSArray *)args onSuccess:(TaskResult)success onFail:(TaskResult)fail;


+ (NSTask *)launchTaskWithPath:(NSString *)path args:(NSArray *)args wait:(BOOL)wait onSuccess:(TaskResult)success onFail:(TaskResult)fail;

@end
