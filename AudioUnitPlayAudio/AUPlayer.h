//
//  AUPlayer.h
//  AudioUnitPlayPCM
//
//  Created by 刘文晨 on 2024/6/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AUPlayer;

@protocol AUPlayerDelegate <NSObject>

- (void)onPlayToEnd:(AUPlayer *)player;

@end

@interface AUPlayer : NSObject

@property (nonatomic, weak) id<AUPlayerDelegate> delegate;

- (void)play;
- (double)getCurrentTime;

@end

NS_ASSUME_NONNULL_END
