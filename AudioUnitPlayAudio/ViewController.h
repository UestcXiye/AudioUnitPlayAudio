//
//  ViewController.h
//  AudioUnitPlayAudio
//
//  Created by 刘文晨 on 2024/6/24.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

