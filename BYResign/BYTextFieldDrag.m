//
//  BYTextFieldDrag.m
//  BYResign
//
//  Created by kimiLin on 2016/12/29.
//  Copyright © 2016年 kimiLin. All rights reserved.
//

#import "BYTextFieldDrag.h"

@implementation BYTextFieldDrag

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.seperator = @",";
    }
    return self;
}
    
- (void)awakeFromNib {
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
}
    
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        NSArray *filePathes = [pboard propertyListForType:NSFilenamesPboardType];
        NSString *firstFilePath = [filePathes objectAtIndex:0];
        if (filePathes.count <= 0) {
            return NO;
        }
        
        if (self.isMuti) {
            // 接收多个路径
            
            if (self.stringValue.length > 0 && ![self.stringValue hasSuffix:self.seperator]) {
                self.stringValue = [self.stringValue stringByAppendingString:self.seperator];
            }
            NSString *appendingPathes = [filePathes componentsJoinedByString:self.seperator];
            self.stringValue = [self.stringValue stringByAppendingString:appendingPathes];
        } else {
            // 只接收一个路径
            
            self.stringValue = firstFilePath;
            
        }
    }
    
    return YES;
}

//- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
//    
//}

// Source: http://www.cocoabuilder.com/archive/cocoa/11014-dnd-for-nstextfields-drag-drop.html
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    
    [self resignFirstResponder];
    if (self.isMuti) {
//        if (self.stringValue.length > 0 && ![self.stringValue hasSuffix:self.seperator]) {
//            self.stringValue = [self.stringValue stringByAppendingString:self.seperator];
//        }
    }
    else {
        if (self.stringValue.length > 0) {
//            self.stringValue = @"";
        }
    }
    
    if (!self.isEnabled) return NSDragOperationNone;
    
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSColorPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}


    
@end
