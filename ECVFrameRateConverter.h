/* Copyright (c) 2011, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import <QTKit/QTKit.h>

// Other Sources
#import "ECVRational.h"

@interface ECVFrameRateConverter : NSObject
{
	QTTime _sourceFrameRate;
	QTTime _targetFrameRate;
	NSData *_frameRepeatData;
	NSUInteger _count;
	NSUInteger _index;
}

+ (QTTime)frameRateWithRatio:(ECVRational)ratio ofFrameRate:(QTTime)rate;

- (id)initWithSourceFrameRate:(QTTime)sourceFrameRate targetFrameRate:(QTTime)targetFrameRate;
@property(readonly, assign) QTTime sourceFrameRate;
@property(readonly, assign) QTTime targetFrameRate;

- (NSUInteger)currentFrameRepeatCount;
- (NSUInteger)nextFrameRepeatCount;

@end
