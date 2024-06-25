//
//  ViewController.m
//  AudioUnitPlayAudio
//
//  Created by 刘文晨 on 2024/6/24.
//

#import "ViewController.h"
#import "AUPlayer.h"

@interface ViewController () <AUPlayerDelegate>

@end

@implementation ViewController
{
    AUPlayer* player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view setBackgroundColor:UIColor.whiteColor];
    
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    self.label.textColor = [UIColor blackColor];
    self.label.text = @"使用 Audio Unit 播放音频文件";
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
        
    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    self.currentTimeLabel.textColor = [UIColor grayColor];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
    self.playButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    [self.playButton setTitle:@"decode and play" forState:UIControlStateNormal];
    [self.playButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    // 添加目标-动作对
    [self.playButton addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.displayLink.preferredFramesPerSecond = 12;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.view addSubview:self.label];
    [self.view addSubview:self.currentTimeLabel];
    [self.view addSubview:self.playButton];
    
    /* 添加约束 */
    [NSLayoutConstraint activateConstraints:@[
        [self.label.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:95],
        [self.label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.currentTimeLabel.topAnchor constraintEqualToAnchor:self.label.bottomAnchor constant:150],
        [self.currentTimeLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.topAnchor constraintEqualToAnchor:self.currentTimeLabel.bottomAnchor constant:150],
        [self.playButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (void)onDecodeStart
{
    self.playButton.hidden = YES;
    player = [[AUPlayer alloc] init];
    // AUPlayer delegate
    player.delegate = self;
    [player play];
}

- (void)updateFrame
{
    if (player)
    {
        self.currentTimeLabel.text = [NSString stringWithFormat:@"当前进度: %3d%%", (int)([player getCurrentTime] * 100)];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - AUPlayer Delegate Method

- (void)onPlayToEnd:(AUPlayer *)player
{
    [self updateFrame];
    player = nil;
    self.playButton.hidden = NO;
}

@end
