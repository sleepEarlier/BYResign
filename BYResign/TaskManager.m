//
//  TaskManager.m
//  BYResign
//
//  Created by kimiLin on 2016/12/29.
//  Copyright © 2016年 kimiLin. All rights reserved.
//

#import "TaskManager.h"

@implementation TaskManager

+ (TaskManager *)sharedInstace
    {
        static TaskManager *instance = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instance = [[TaskManager alloc] init];
        });
        return instance;
}

+ (NSTask *)launchTaskWithPath:(NSString *)path args:(NSArray *)args wait:(BOOL)wait onSuccess:(TaskResult)success onFail:(TaskResult)fail {
    NSTask *task = [[NSTask alloc]init];
    task.launchPath = path;
    task.arguments = args;
    NSPipe *outputPipe = [NSPipe pipe];
    
    task.standardOutput = outputPipe;
    task.standardError = outputPipe;
    [task launch];
    if (wait) {
        [task waitUntilExit];
        int status = [task terminationStatus];
        NSFileHandle *fileHandler = [outputPipe fileHandleForReading];
        if (status == 0) {
            NSLog(@"Task succeeded.");
            if (success) {
                NSData *fileData = [fileHandler readDataToEndOfFile];
                NSString * resultMsg = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
                success(resultMsg);
            }
        } else {
            NSLog(@"Task failed.");
            if (fail) {
                NSData *fileData = [fileHandler readDataToEndOfFile];
                NSString * resultMsg = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
                fail(resultMsg);
            }
        }
    }
    return task;
}

+ (NSTask *)launchTaskWithPath:(NSString *)path args:(NSArray *)args onSuccess:(TaskResult)success onFail:(TaskResult)fail {
    return [self launchTaskWithPath:path args:args wait:YES onSuccess:success onFail:fail];
}


@end
