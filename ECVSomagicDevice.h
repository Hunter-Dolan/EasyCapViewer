/* Copyright (c) 2013, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHORS ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "ECVCaptureDevice.h"

@interface ECVSomagicDevice : ECVCaptureDevice
{
	@private
	NSInteger _offset;
	BOOL _signalLock;
	NSUInteger _discard;
	UInt8 _flags;
	NSUInteger _hState, _vState;
}

- (BOOL)getStartOfRow:(out NSUInteger *const)outRow flags:(out UInt8 *const)outFlags withBytes:(UInt8 const *const)bytes length:(NSUInteger const)length;
- (BOOL)getStartOfField:(out NSUInteger *const)outField flags:(out UInt8 *const)outFlags withBytes:(UInt8 const *const)bytes length:(NSUInteger const)length;
- (void)writePacketBytes:(UInt8 const *)bytes length:(NSUInteger)length toStorage:(ECVVideoStorage *const)storage;

@end
