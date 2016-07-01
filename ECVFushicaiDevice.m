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
#import "ECVFushicaiDevice.h"

// TODO: Copy/pasted from ECVEM2860Device.
static void ECVPixelFormatHack(uint16_t *const bytes, size_t const len) {
	for(size_t i = 0; i < len / sizeof(uint16_t); ++i) bytes[i] = CFSwapInt16(bytes[i]);
}

enum {
	ECVFushicaiHighFieldFlag = 1 << 3,
};

#define CTRL(pipe, type, req, idx, val) \
({ \
	[self controlRequestWithType:type request:req value:val index:idx length:0 data:NULL];\
})

#define VND_RD(request, idx, val, ...) \
({ \
	u_int8_t const expected[] = {__VA_ARGS__}; \
	u_int8_t data[] = {__VA_ARGS__}; \
	size_t const length = sizeof(expected); \
	if(![self readRequest:(request) value:(val) index:(idx) length:length data:data]) return; \
	if(memcmp(expected, data, length) != 0) ECVLog(ECVNotice, @"Line %d, read %04x: Expected %@, received %@", __LINE__, (idx), [NSData dataWithBytesNoCopy:(void *)expected length:length freeWhenDone:NO], [NSData dataWithBytesNoCopy:(void *)data length:length freeWhenDone:NO]); \
})
#define VND_WR(request, idx, val, ...) \
({ \
	u_int8_t data[] = {__VA_ARGS__}; \
	if(![self writeRequest:(request) value:(val) index:(idx) length:sizeof(data) data:data]) return; \
})

@implementation ECVFushicaiDevice

#pragma mark -ECVFushicaiDevice

- (BOOL)modifyIndex:(UInt16 const)idx enable:(UInt8 const)enable disable:(UInt8 const)disable
{
	NSAssert(!(enable & disable), @"Can't enable and disable the same flag(s).");
	UInt8 old = 0;
	if(![self readRequest:11 value:0 index:idx length:sizeof(old) data:&old]) return NO;
	UInt8 new = (old | enable) & ~disable;
	if(![self writeRequest:12 value:new index:idx length:0 data:NULL]) return NO;
	return YES;
}
- (void)writePacket:(UInt8 const *const)bytes length:(NSUInteger const)length toStorage:(ECVVideoStorage *const)storage
{
	NSUInteger const headerLength = 4;
	NSUInteger const trailerLength = 60;

	if(length < headerLength + trailerLength) return;
	if(0x00 == bytes[0]) return; // Empty packet.
	if(0x88 != bytes[0]) {
		ECVLog(ECVError, @"Unexpected device packet header %x\n", CFSwapInt32BigToHost(*(unsigned int *)bytes));
		// TODO: Just checking our assumptions.
	}

	NSUInteger const fieldIndex = bytes[1]; // Unused.
	NSUInteger const flags = (bytes[2] >> 4) & 0x0f;
	NSUInteger const packetIndex = (bytes[2] & 0x0f) << 8 | bytes[3];

	if(0x000 == packetIndex) {
		ECVFieldType const field = ECVFushicaiHighFieldFlag & flags ? ECVHighField : ECVLowField;
		[self pushVideoFrame:[storage finishedFrameWithNextFieldType:field]];
		_offset = 0;
	}

	// TODO: This gets copy and pasted over and over... Can we abstract it?
	NSUInteger const realLength = length - headerLength - trailerLength;
	ECVIntegerSize const pixelSize = [[self videoFormat] frameSize];
	ECVIntegerSize const inputSize = (ECVIntegerSize){720, pixelSize.height};
	OSType const pixelFormat = [self pixelFormat];
	NSUInteger const bytesPerRow = ECVPixelFormatBytesPerPixel(pixelFormat) * inputSize.width;
	ECVPixelFormatHack((void *)bytes+headerLength, realLength);
	ECVPointerPixelBuffer *const buffer = [[ECVPointerPixelBuffer alloc] initWithPixelSize:inputSize bytesPerRow:bytesPerRow pixelFormat:pixelFormat bytes:bytes + headerLength validRange:NSMakeRange(_offset, realLength)];
	[storage drawPixelBuffer:buffer atPoint:(ECVIntegerPoint){-8, 0}];
	[buffer release];
	_offset += realLength;
}
- (void)writeBrightnessAndContrast
{
	uint16_t const b = round(_brightness * 0x3ff);
	uint16_t const c = round(_contrast * 0x3ff);
	uint8_t data[] = {
		((c >> 4) & 0xf0) | ((b >> 8) & 0x0f),
		c & 0xff,
		b & 0xff,
	};
	[self writeRequest:11 value:0 index:0xc244 length:sizeof(data) data:&data];
}

#pragma mark -ECVCaptureDevice

- (id)initWithService:(io_service_t const)service
{
	_brightness = [[NSUserDefaults standardUserDefaults] doubleForKey:ECVBrightnessKey];
	_contrast = [[NSUserDefaults standardUserDefaults] doubleForKey:ECVContrastKey];
	_saturation = [[NSUserDefaults standardUserDefaults] doubleForKey:ECVSaturationKey];
	_hue = [[NSUserDefaults standardUserDefaults] doubleForKey:ECVHueKey];
	return [super initWithService:service];
}

#pragma mark -ECVCaptureDevice(ECVRead_Thread)

- (void)read
{
[self setAlternateInterface:0];
VND_RD(2, 0x0000, 0x00a0, 0x01, 0x3a);
VND_RD(7, 0x003a, 0x00a0, 0x00, 0x6f);
VND_RD(7, 0x0000, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x0020, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x0040, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x0060, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x0080, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x00a0, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x00c0, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_RD(7, 0x00e0, 0x00a2, 0x01, 0x6f, 0xd0, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c);
VND_WR(12, 0xc008, 0x0001);
VND_WR(12, 0xc1d0, 0x00ff);
VND_WR(12, 0xc1d9, 0x0002);
VND_WR(12, 0xc1da, 0x0013);
VND_WR(12, 0xc1db, 0x0012);
VND_WR(12, 0xc1e9, 0x0002);
VND_WR(12, 0xc1ec, 0x006c);
VND_WR(12, 0xc25b, 0x0030);
VND_WR(12, 0xc254, 0x0073);
VND_WR(12, 0xc294, 0x0020);
VND_WR(12, 0xc255, 0x00cf);
VND_WR(12, 0xc256, 0x0020);
VND_WR(12, 0xc1eb, 0x0030);
VND_WR(12, 0xc105, 0x0060);
VND_WR(12, 0xc11f, 0x00f2);
VND_WR(12, 0xc127, 0x0060);
VND_WR(12, 0xc0ae, 0x0010);
VND_WR(12, 0xc284, 0x00aa);
VND_WR(12, 0xc003, 0x0004);
	VND_WR(12, 0xc01a, 0x0068);
	VND_WR(12, 0xc100, 0x00d3);
	VND_WR(12, 0xc10e, 0x0072);
	VND_WR(12, 0xc10f, 0x00a2);
	VND_WR(12, 0xc112, 0x00b0);
	VND_WR(12, 0xc115, 0x0015);
	VND_WR(12, 0xc117, 0x0001);
	VND_WR(12, 0xc118, 0x002c);
	VND_WR(12, 0xc12d, 0x0010);
	VND_WR(12, 0xc12f, 0x0020);
	VND_WR(12, 0xc220, 0x002e);
	VND_WR(12, 0xc225, 0x0008);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0002);
	VND_WR(12, 0xc254, 0x0059);
	VND_WR(12, 0xc25a, 0x0016);
	VND_WR(12, 0xc25b, 0x0035);
	VND_WR(12, 0xc263, 0x0017);
	VND_WR(12, 0xc266, 0x0016);
	VND_WR(12, 0xc267, 0x0036);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0002);
VND_WR(12, 0xc239, 0x0040);
VND_WR(12, 0xc240, 0x0000);
VND_WR(12, 0xc241, 0x0000);
VND_WR(12, 0xc242, 0x0002);
VND_WR(12, 0xc243, 0x0080);
VND_WR(12, 0xc244, 0x0012);
VND_WR(12, 0xc245, 0x0090);
VND_WR(12, 0xc246, 0x0000);
//VND_RD(11, 0xc278, 0x0000, 0x08);
//VND_WR(12, 0xc278, 0x0009);
//VND_WR(12, 0xc278, 0x000d);
//VND_WR(12, 0xc278, 0x002d);
[self modifyIndex:0xc278 enable:1 << 0 | 1 << 2 | 1 << 5 disable:0];
//VND_RD(11, 0xc279, 0x0000, 0x00);
//VND_WR(12, 0xc279, 0x0002);
//VND_WR(12, 0xc279, 0x000a);
[self modifyIndex:0xc279 enable:1 << 1 | 1 << 3 disable:0];
//VND_RD(11, 0xc27a, 0x0000, 0x30);
//VND_WR(12, 0xc27a, 0x0030);
//VND_WR(12, 0xc27a, 0x0030);
//VND_WR(12, 0xc27a, 0x0032);
//VND_WR(12, 0xc27a, 0x0032);
[self modifyIndex:0xc27a enable:1 << 1 | 1 << 4 | 1 << 5 disable:0];
//VND_RD(11, 0xf890, 0x0000, 0x0c);
//VND_WR(12, 0xf890, 0x000c);
[self modifyIndex:0xf890 enable:0 disable:1 << 7];
//VND_RD(11, 0xf894, 0x0000, 0x87);
//VND_WR(12, 0xf894, 0x0086);
[self modifyIndex:0xf894 enable:1 << 7 | 1 << 1 disable:1 << 0];
VND_WR(12, 0xc0ac, 0x00c0);
VND_WR(12, 0xc0ad, 0x0000);
VND_WR(12, 0xc0a2, 0x0012);
VND_WR(12, 0xc0a3, 0x00e0);
VND_WR(12, 0xc0a4, 0x0028);
VND_WR(12, 0xc0a5, 0x0082);
VND_WR(12, 0xc0a7, 0x0080);
VND_WR(12, 0xc000, 0x0014);
VND_WR(12, 0xc006, 0x0003);
VND_WR(12, 0xc090, 0x0099);
VND_WR(12, 0xc091, 0x0090);
VND_WR(12, 0xc094, 0x0068);
VND_WR(12, 0xc095, 0x0070);
VND_WR(12, 0xc09c, 0x0030);
VND_WR(12, 0xc09d, 0x00c0);
VND_WR(12, 0xc09e, 0x00e0);
VND_WR(12, 0xc019, 0x0006);
VND_WR(12, 0xc08c, 0x00ba);
VND_WR(12, 0xc101, 0x00ff);
VND_WR(12, 0xc10c, 0x00b3);
VND_WR(12, 0xc1b2, 0x0080);
VND_WR(12, 0xc1b4, 0x00a0);
VND_WR(12, 0xc14c, 0x00ff);
VND_WR(12, 0xc14d, 0x00ca);
VND_WR(12, 0xc113, 0x0053);
VND_WR(12, 0xc119, 0x008a);
VND_WR(12, 0xc13c, 0x0003);
VND_WR(12, 0xc150, 0x009c);
VND_WR(12, 0xc151, 0x0071);
VND_WR(12, 0xc152, 0x00c6);
VND_WR(12, 0xc153, 0x0084);
VND_WR(12, 0xc154, 0x00bc);
VND_WR(12, 0xc155, 0x00a0);
VND_WR(12, 0xc156, 0x00a0);
VND_WR(12, 0xc157, 0x009c);
VND_WR(12, 0xc158, 0x001f);
VND_WR(12, 0xc159, 0x0006);
VND_WR(12, 0xc15d, 0x0000);
//VND_RD(11, 0xc27d, 0x0000, 0x00);
//VND_WR(12, 0xc27d, 0x0002);
//VND_WR(12, 0xc27d, 0x0006);
//VND_WR(12, 0xc27d, 0x0026);
//VND_WR(12, 0xc27d, 0x0026);
//VND_WR(12, 0xc27d, 0x00a6);
[self modifyIndex:0xc27d enable:1 << 1 | 1 << 2 | 1 << 5 | 1 << 7 disable:0];
VND_WR(12, 0xc280, 0x0011);
VND_WR(12, 0xc281, 0x0040);
VND_WR(12, 0xc282, 0x0011);
VND_WR(12, 0xc283, 0x0040);
//VND_RD(11, 0xf891, 0x0000, 0x10);
//VND_WR(12, 0xf891, 0x0010);
[self modifyIndex:0xf891 enable:0 disable:1 << 5];
VND_RD(11, 0xc0ae, 0x0000, 0x10);
VND_RD(11, 0xc284, 0x0000, 0xaa);
VND_WR(12, 0xc105, 0x0060);
VND_WR(12, 0xc11f, 0x00f2);
VND_WR(12, 0xc127, 0x0060);
VND_WR(12, 0xc0ae, 0x0010);
VND_RD(11, 0xc0ae, 0x0000, 0x10);
//VND_RD(11, 0xc284, 0x0000, 0xaa);
//VND_WR(12, 0xc284, 0x0088);
[self modifyIndex:0xc284 enable:0 disable:1 << 5 | 1 << 1];
VND_WR(12, 0xc003, 0x0004);
if([[self videoFormat] is60Hz]) { // 60Hz
	VND_WR(12, 0xc01a, 0x0079);
	VND_WR(12, 0xc100, 0x00d3);
	VND_WR(12, 0xc10e, 0x0068);
	VND_WR(12, 0xc10f, 0x009c);
	VND_WR(12, 0xc112, 0x00f0);
	VND_WR(12, 0xc115, 0x0015);
	VND_WR(12, 0xc117, 0x0000);
	VND_WR(12, 0xc118, 0x00fc);
	VND_WR(12, 0xc12d, 0x0004);
	VND_WR(12, 0xc12f, 0x0008);
	VND_WR(12, 0xc220, 0x002e);
	VND_WR(12, 0xc225, 0x0008);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0001);
	VND_WR(12, 0xc254, 0x005f);
	VND_WR(12, 0xc25a, 0x0012);
	VND_WR(12, 0xc25b, 0x0001);
	VND_WR(12, 0xc263, 0x001c);
	VND_WR(12, 0xc266, 0x0011);
	VND_WR(12, 0xc267, 0x0005);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0002);
	VND_WR(12, 0xc16f, 0x00b8);
	// 0x00b8 = NTSC-M?
	// 0x00bc = PAL-60?
} else { // 50Hz
	VND_WR(12, 0xc01a, 0x0068);
	VND_WR(12, 0xc100, 0x00d3);
	VND_WR(12, 0xc10e, 0x0072);
	VND_WR(12, 0xc10f, 0x00a2);
	VND_WR(12, 0xc112, 0x00b0);
	VND_WR(12, 0xc115, 0x0015);
	VND_WR(12, 0xc117, 0x0001);
	VND_WR(12, 0xc118, 0x002c);
	VND_WR(12, 0xc12d, 0x0010);
	VND_WR(12, 0xc12f, 0x0020);
	VND_WR(12, 0xc220, 0x002e);
	VND_WR(12, 0xc225, 0x0008);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0002);
	VND_WR(12, 0xc254, 0x0059);
	VND_WR(12, 0xc25a, 0x0016);
	VND_WR(12, 0xc25b, 0x0035);
	VND_WR(12, 0xc263, 0x0017);
	VND_WR(12, 0xc266, 0x0016);
	VND_WR(12, 0xc267, 0x0036);
	VND_WR(12, 0xc24e, 0x0002);
	VND_WR(12, 0xc24f, 0x0002);
	VND_WR(12, 0xc16f, 0x00ee);
}
VND_RD(11, 0xc0ae, 0x0000, 0x10);
VND_RD(11, 0xc244, 0x0000, 0x12);
VND_RD(11, 0xc246, 0x0000, 0x00);
VND_RD(11, 0xc244, 0x0000, 0x12);
VND_RD(11, 0xc245, 0x0000, 0x90);
VND_RD(11, 0xc242, 0x0000, 0x02);
VND_RD(11, 0xc243, 0x0000, 0x80);
VND_RD(11, 0xc240, 0x0000, 0x00);
VND_RD(11, 0xc241, 0x0000, 0x00);
VND_RD(11, 0xc239, 0x0000, 0x40);
VND_RD(11, 0xc244, 0x0000, 0x12);
VND_RD(11, 0xc246, 0x0000, 0x00);
VND_RD(11, 0xc244, 0x0000, 0x12);
VND_RD(11, 0xc245, 0x0000, 0x90);
VND_WR(11, 0xc244, 0x0000);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc245, 0x0000, 0x90);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_WR(11, 0xc244, 0x0000);
VND_RD(11, 0xc242, 0x0000, 0x02);
VND_RD(11, 0xc243, 0x0000, 0x80);
VND_WR(11, 0xc242, 0x0000);
VND_RD(11, 0xc240, 0x0000, 0x00);
VND_RD(11, 0xc241, 0x0000, 0x00);
VND_WR(11, 0xc240, 0x0000);
//VND_RD(11, 0xc239, 0x0000, 0x40);
//VND_WR(12, 0xc239, 0x0060);
[self modifyIndex:0xc239 enable:1 << 1 disable:0 << 1]; // Related to PAL-60? (And below)
[self setAlternateInterface:1];
CTRL(0, USBmakebmRequestType(kUSBOut, kUSBStandard, kUSBEndpoint), kUSBRqClearFeature, 0, 0);
if([[self videoSource] SVideo]) {
	VND_WR(12, 0xc105, 0x0010);
	VND_WR(12, 0xc11f, 0x00ff);
	VND_WR(12, 0xc127, 0x0060);
	VND_WR(12, 0xc0ae, 0x0030);
	VND_WR(12, 0xc284, 0x0088);
} else { // Composite
	VND_WR(12, 0xc105, 0x0060);
	VND_WR(12, 0xc11f, 0x00f2);
	VND_WR(12, 0xc127, 0x0060);
	VND_WR(12, 0xc0ae, 0x0010);
	VND_WR(12, 0xc284, 0x00aa);
	VND_WR(12, 0xc105, 0x0060);
	VND_WR(12, 0xc11f, 0x00f2);
	VND_WR(12, 0xc127, 0x0060);
	VND_WR(12, 0xc0ae, 0x0010);
	VND_WR(12, 0xc284, 0x00aa);
}
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc246, 0x0000, 0xd0);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc245, 0x0000, 0xc0);
VND_RD(11, 0xc242, 0x0000, 0x02);
VND_RD(11, 0xc243, 0x0000, 0x00);
VND_RD(11, 0xc240, 0x0000, 0x82);
VND_RD(11, 0xc241, 0x0000, 0x00);
VND_RD(11, 0xc239, 0x0000, 0x60);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc246, 0x0000, 0xd0);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc245, 0x0000, 0xc0);
VND_WR(11, 0xc244, 0x0000);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_RD(11, 0xc245, 0x0000, 0xc0);
VND_RD(11, 0xc244, 0x0000, 0x11);
VND_WR(11, 0xc244, 0x0000);
VND_RD(11, 0xc242, 0x0000, 0x02);
VND_RD(11, 0xc243, 0x0000, 0x00);
VND_WR(11, 0xc242, 0x0000);
VND_RD(11, 0xc240, 0x0000, 0x82);
VND_RD(11, 0xc241, 0x0000, 0x00);
VND_WR(11, 0xc240, 0x0000);
//VND_RD(11, 0xc239, 0x0000, 0x60);
//VND_WR(12, 0xc239, 0x0060);
[self modifyIndex:0xc239 enable:1 << 1 disable:0 << 1];

[self setBrightness:_brightness];
[self setContrast:_contrast];
[self setSaturation:_saturation];
[self setHue:_hue];

[super read];
[self setAlternateInterface:0];
}

#pragma mark -ECVCaptureDevice(ECVReadAbstract_Thread)

- (void)writeBytes:(UInt8 const *const)bytes length:(NSUInteger const)length toStorage:(ECVVideoStorage *const)storage
{
	if(!length) return;
	if(3072 != length) {
		ECVLog(ECVError, @"Unexpected USB packet length %lu\n", (unsigned long)length);
		// TODO: Intentionally brittle, just checking our assumptions.
		return;
	}
	[self writePacket:bytes + 0 length:1024 toStorage:storage];
	[self writePacket:bytes + 1024 length:1024 toStorage:storage];
	[self writePacket:bytes + 2048 length:1024 toStorage:storage];
}

#pragma mark -ECVCaptureDevice(ECVAbstract)

- (UInt32)maximumMicrosecondsInFrame
{
	return kUSBHighSpeedMicrosecondsInFrame;
}
- (NSArray *)supportedVideoSources
{
	return [NSArray arrayWithObjects:
		[ECVGenericVideoSource_SVideo source],
		[ECVGenericVideoSource_Composite source],
		nil];
}
- (ECVVideoSource *)defaultVideoSource
{
	return [ECVGenericVideoSource_Composite source];
}
- (NSSet *)supportedVideoFormats
{
	return [NSSet setWithObjects:
		[ECVVideoFormat_NTSC_M format],
		[ECVVideoFormat_PAL_BGDHI format],
		nil];
}
- (ECVVideoFormat *)defaultVideoFormat
{
	return [ECVVideoFormat_NTSC_M format];
}
- (OSType)pixelFormat
{
	return k2vuyPixelFormat;
}

#pragma mark -ECVCaptureDevice<ECVCaptureDeviceConfiguring>

- (CGFloat)brightness
{
	return _brightness;
}
- (void)setBrightness:(CGFloat const)val
{
	_brightness = val;
	[self writeBrightnessAndContrast];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:val] forKey:ECVBrightnessKey];
}
- (CGFloat)contrast
{
	return _contrast;
}
- (void)setContrast:(CGFloat const)val
{
	_contrast = val;
	[self writeBrightnessAndContrast];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:val] forKey:ECVContrastKey];
}
- (CGFloat)saturation
{
	return _saturation;
}
- (void)setSaturation:(CGFloat const)val
{
	_saturation = val;
	uint16_t x = CFSwapInt16HostToBig(round(val * 0x3ff));
	[self writeRequest:11 value:0 index:0xc242 length:sizeof(x) data:&x];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:val] forKey:ECVSaturationKey];
}
- (CGFloat)hue
{
	return _hue;
}
- (void)setHue:(CGFloat const)val
{
	_hue = val;
	uint16_t x = round(val * (0xdff*2));
	if(x <= 0xdff) x = 0x8fff - x;
	else x = 0x9200 - 0xdff + x;
	x = CFSwapInt16HostToBig(x);
	[self writeRequest:11 value:0 index:0xc240 length:sizeof(x) data:&x];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:val] forKey:ECVHueKey];
}

@end
