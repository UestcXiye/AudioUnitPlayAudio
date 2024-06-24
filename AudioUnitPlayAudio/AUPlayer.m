//
//  AUPlayer.m
//  AudioUnitPlayPCM
//
//  Created by 刘文晨 on 2024/6/21.
//

#import "AUPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define NO_MORE_DATA -1

@implementation AUPlayer
{
    AudioFileID audioFileID;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamPacketDescription *audioPacketFormat;
    
    UInt64 readPacketCnt; // 已读的音频 packet 的数量
    UInt64 totalPacketCnt; // 总的音频 packet 的数量
    // UInt64 bufferPacketCnt; // buffer 中 packet 的数量
    
    AudioUnit audioUnit;
    AudioBufferList *audioBufferList; // 音频的缓存数据结构
    // NSInputStream *inputSteam;
    AudioConverterRef audioConverter;
    Byte *convertBuffer;
}

- (void)play
{
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}

- (double)getCurrentTime
{
    double timeInterval = readPacketCnt * 1.0 / totalPacketCnt;
    return timeInterval;
}

- (void)initPlayer
{
    // open file
    NSBundle *bundle = [NSBundle mainBundle];
    // NSURL *url = [bundle URLForResource:@"music" withExtension:@"m4a"];
    // NSURL *url = [bundle URLForResource:@"music" withExtension:@"mp3"];
    // NSURL *url = [bundle URLForResource:@"music" withExtension:@"aac"];
    NSURL *url = [bundle URLForResource:@"壱雫空" withExtension:@"flac"];
    
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID);
    if (status)
    {
        NSLog(@"failed to open file: %@", url);
        return;
    }
    
    // 读取 kAudioFilePropertyDataFormat 属性
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioFileFormat); // 读取文件格式
    NSAssert(status == noErr, ([NSString stringWithFormat:@"get kAudioFilePropertyDataFormat property error with status: %d", status]));
    [self printAudioStreamBasicDescription:audioFileFormat];
            
    // 读取 kAudioFilePropertyAudioDataPacketCount 属性
    size = sizeof(totalPacketCnt);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyAudioDataPacketCount, &size, &totalPacketCnt);
        
    readPacketCnt = 0;
        
    uint32_t sizePerPacket = audioFileFormat.mFramesPerPacket;
    if (sizePerPacket == 0)
    {
        // 读取 kAudioFilePropertyMaximumPacketSize 属性作为 sizePerPacket 的值
        size = sizeof(sizePerPacket);
        status = AudioFileGetProperty(audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &sizePerPacket);
        NSAssert(status == noErr && sizePerPacket != 0, @"AudioFileGetProperty error or sizePerPacket = 0");
    }
        
    audioPacketFormat = malloc(sizeof(AudioStreamPacketDescription) * (CONST_BUFFER_SIZE / sizePerPacket + 1));
    
    audioConverter = NULL;
        
    // init buffer
    audioBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    audioBufferList->mNumberBuffers = 1; // AudioBuffer 的数量
    audioBufferList->mBuffers[0].mNumberChannels = 1; // 声道数
    audioBufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    audioBufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    convertBuffer = malloc(CONST_BUFFER_SIZE);
    
    NSError *audioSessionError = nil;
    
    // set audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
    
    // create an audio component description to identify an audio unit
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    // obtain an audio unit instance using the audio unit API
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    // audio property
    UInt32 flag = 1;
    if (flag)
    {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status)
    {
        NSLog(@"Audio Unit set property error with status: %d", status);
    }
    
    // output format
    AudioStreamBasicDescription outputFormat = {0};
    // memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = 44100.0; // 采样率
    outputFormat.mFormatID = kAudioFormatLinearPCM; // PCM 格式
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger; // 整形
    outputFormat.mFramesPerPacket = 1; // 每帧只有 1 个 packet
    outputFormat.mChannelsPerFrame = 1; // 声道数
    outputFormat.mBytesPerFrame = 2; // 每帧只有 2 个 byte，声道*位深*Packet
    outputFormat.mBytesPerPacket = 2; // 每个 Packet 只有 2 个 byte
    outputFormat.mBitsPerChannel = 16; // 位深
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = AudioConverterNew(&audioFileFormat, &outputFormat, &audioConverter);
    if (status)
    {
        NSLog(@"create audio converter error with status: %d", status);
    }
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status)
    {
        NSLog(@"Audio Unit set property eror with status: %d", status);
    }
    
    // attach a render callback immediately
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result: %d", result);
}

OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData)
{
    AUPlayer *player = (__bridge AUPlayer *)inRefCon;
    
    player->audioBufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    OSStatus status =
        AudioConverterFillComplexBuffer(player->audioConverter, AUInputDataProc, inRefCon, &inNumberFrames, player->audioBufferList, NULL);
    if (status)
    {
        NSLog(@"failed to convert audio format");
    }
        
    NSLog(@"output buffer size: %d", player->audioBufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = player->audioBufferList->mBuffers[0].mDataByteSize;
    memcpy(ioData->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mDataByteSize);
    
    fwrite(player->audioBufferList->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mDataByteSize, 1, [player pcmFile]);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}

OSStatus AUInputDataProc(AudioConverterRef inAudioConverter,
                         UInt32 *ioNumberDataPackets,
                         AudioBufferList *ioData,
                         AudioStreamPacketDescription **outDataPacketDescription,
                         void *inUserData)
{
    AUPlayer *player = (__bridge AUPlayer *)(inUserData);
        
    UInt32 byteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioFileReadPacketData(player->audioFileID, NO, &byteSize, player->audioPacketFormat, player->readPacketCnt, ioNumberDataPackets, player->convertBuffer);
        
    if (outDataPacketDescription)
    {
        // 这里要设置好 packetFormat，否则会转码失败
        *outDataPacketDescription = player->audioPacketFormat;
    }
        
    if (status)
    {
        NSLog(@"failed to read file");
    }
        
    if (!status && ioNumberDataPackets > 0)
    {
        ioData->mBuffers[0].mDataByteSize = byteSize;
        ioData->mBuffers[0].mData = player->convertBuffer;
        player->readPacketCnt += *ioNumberDataPackets;
        return noErr;
    }
    else
    {
        return NO_MORE_DATA;
    }
}

- (FILE *)pcmFile
{
    static FILE *_pcmFile;
    if (_pcmFile == nil)
    {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"music.pcm"];
        NSLog(@"%@", filePath);
        _pcmFile = fopen(filePath.UTF8String, "w");
    }
    return _pcmFile;
}

- (void)stop
{
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (audioBufferList != nil)
    {
        if (audioBufferList->mBuffers[0].mData)
        {
            free(audioBufferList->mBuffers[0].mData);
            audioBufferList->mBuffers[0].mData = nil;
        }
        free(audioBufferList);
        audioBufferList = nil;
    }
    
    if (convertBuffer != nil)
    {
        free(convertBuffer);
        convertBuffer = nil;
    }
    
    AudioConverterDispose(audioConverter);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)])
    {
        __strong typeof(AUPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
}

- (void)dealloc
{
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    if (audioBufferList != nil)
    {
        free(audioBufferList);
        audioBufferList = nil;
    }
    if (convertBuffer != nil)
    {
        free(convertBuffer);
        convertBuffer = nil;
    }
    AudioConverterDispose(audioConverter);
}

- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd
{
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&formatID, formatIDString, 4);
    formatIDString[4] = '\0';

    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    asbd.mBitsPerChannel);
    
    printf("\n");
}

@end
