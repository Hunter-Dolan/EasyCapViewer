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
#import "ECVPixelBuffer.h"

// Other Sources
#import "ECVPixelFormat.h"

typedef struct {
	NSInteger location;
	NSUInteger length;
} ECVRange;

NS_INLINE ECVRange ECVRangeFromNSRange(NSRange const r)
{
	return (ECVRange){r.location, r.length};
}
NS_INLINE NSInteger ECVMaxRange(ECVRange const r)
{
	return r.location + r.length;
}
NS_INLINE ECVRange ECVIntersectionRange(ECVRange const r1, ECVRange const r2)
{
	ECVRange r;
	r.location = MAX(r1.location, r2.location);
	r.length = MAX(0, SUB_ZERO(MIN(ECVMaxRange(r1), ECVMaxRange(r2)), r.location));
	return r;
}
NS_INLINE ECVRange ECVRebaseRange(ECVRange const range, ECVRange const base)
{
	ECVRange r = ECVIntersectionRange(range, base);
	r.location -= base.location;
	return r;
}
NS_INLINE NSRange ECVNSRebaseRange(NSRange const range, NSRange const base)
{
	NSRange r = NSIntersectionRange(range, base);
	r.location -= base.location;
	return r;
}

typedef struct {
	size_t bytesPerRow;
	size_t bytesPerPixel;
	ECVRange validRange;
} const ECVFastPixelBufferInfo;

NS_INLINE ECVRange ECVValidRows(ECVFastPixelBufferInfo *info)
{
	return (ECVRange){info->validRange.location / info->bytesPerRow, info->validRange.length / info->bytesPerRow + 2};
}
NS_INLINE void ECVDraw(UInt8 *dst, UInt8 const *src, size_t length, BOOL blended)
{
	if(blended) {
		size_t i;
		for(i = 0; i < length; ++i) dst[i] = dst[i] / 2 + src[i] / 2;
	} else memcpy(dst, src, length);
}
NS_INLINE void ECVDrawRow(UInt8 *dst, ECVFastPixelBufferInfo *dstInfo, UInt8 const *src, ECVFastPixelBufferInfo *srcInfo, ECVIntegerPoint dstPoint, ECVIntegerPoint srcPoint, size_t length, BOOL blended)
{
	ECVRange const dstDesiredRange = (ECVRange){dstPoint.y * dstInfo->bytesPerRow + dstPoint.x * dstInfo->bytesPerPixel, length * dstInfo->bytesPerPixel};
	ECVRange const srcDesiredRange = (ECVRange){srcPoint.y * srcInfo->bytesPerRow + srcPoint.x * srcInfo->bytesPerPixel, length * srcInfo->bytesPerPixel};

	ECVRange const dstRowRange = (ECVRange){dstPoint.y * dstInfo->bytesPerRow, dstInfo->bytesPerRow};
	ECVRange const srcRowRange = (ECVRange){srcPoint.y * srcInfo->bytesPerRow, srcInfo->bytesPerRow};

	ECVRange const dstValidRange = ECVIntersectionRange(ECVIntersectionRange(dstDesiredRange, dstRowRange), dstInfo->validRange);
	ECVRange const srcValidRange = ECVIntersectionRange(ECVIntersectionRange(srcDesiredRange, srcRowRange), srcInfo->validRange);

	NSInteger const dstMinOffset = dstValidRange.location - dstDesiredRange.location;
	NSInteger const srcMinOffset = srcValidRange.location - srcDesiredRange.location;
	NSInteger const commonOffset = MAX(dstMinOffset, srcMinOffset);

	NSUInteger const dstMaxLength = SUB_ZERO(dstValidRange.length, (NSUInteger)(commonOffset - dstMinOffset));
	NSUInteger const srcMaxLength = SUB_ZERO(srcValidRange.length, (NSUInteger)(commonOffset - srcMinOffset));
	NSUInteger const commonLength = MIN(dstMaxLength, srcMaxLength);

	if(!commonLength) return;
	ECVRange const dstRange = ECVRebaseRange((ECVRange){dstDesiredRange.location + commonOffset, commonLength}, dstInfo->validRange);
	ECVRange const srcRange = ECVRebaseRange((ECVRange){srcDesiredRange.location + commonOffset, commonLength}, srcInfo->validRange);
	UInt8 *const dstBytes = dst + dstRange.location;
	UInt8 const *const srcBytes = src + srcRange.location;
	ECVDraw(dstBytes, srcBytes, commonLength, blended);
}
static void ECVDrawRect(ECVMutablePixelBuffer *dst, ECVPixelBuffer *src, ECVIntegerPoint dstPoint, ECVIntegerPoint srcPoint, ECVIntegerSize size, ECVPixelBufferDrawingOptions options)
{
	ECVFastPixelBufferInfo dstInfo = {
		.bytesPerRow = [dst bytesPerRow],
		.bytesPerPixel = ECVPixelFormatBytesPerPixel([dst pixelFormat]),
		.validRange = ECVRangeFromNSRange([dst validRange]),
	};
	ECVFastPixelBufferInfo srcInfo = {
		.bytesPerRow = [src bytesPerRow],
		.bytesPerPixel = ECVPixelFormatBytesPerPixel([src pixelFormat]),
		.validRange = ECVRangeFromNSRange([src validRange]),
	};
	UInt8 *const dstBytes = [dst mutableBytes];
	UInt8 const *const srcBytes = [src bytes];
	BOOL const useFields = ECVDrawToHighField & options || ECVDrawToLowField & options;
	NSUInteger const dstRowSpacing = useFields ? 2 : 1;
	BOOL const blended = !!(ECVDrawBlended & options);

	ECVRange const srcRows = ECVIntersectionRange((ECVRange){srcPoint.y, size.height}, ECVValidRows(&srcInfo));
	for(NSInteger i = srcRows.location; i < ECVMaxRange(srcRows); ++i) {
		if(ECVDrawToHighField & options || !useFields) {
			ECVDrawRow(dstBytes, &dstInfo, srcBytes, &srcInfo, (ECVIntegerPoint){dstPoint.x, dstPoint.y + 0 + (i * dstRowSpacing)}, (ECVIntegerPoint){srcPoint.x, srcPoint.y + i}, size.width, blended);
		}
		if(ECVDrawToLowField & options) {
			ECVDrawRow(dstBytes, &dstInfo, srcBytes, &srcInfo, (ECVIntegerPoint){dstPoint.x, dstPoint.y + 1 + (i * dstRowSpacing)}, (ECVIntegerPoint){srcPoint.x, srcPoint.y + i}, size.width, blended);
		}
	}
}

@implementation ECVPixelBuffer

#pragma mark -ECVPixelBuffer

- (NSRange)fullRange
{
	return NSMakeRange(0, [self bytesPerRow] * [self pixelSize].height);
}

@end

@implementation ECVPointerPixelBuffer

#pragma mark -ECVPointerPixelBuffer

- (id)initWithPixelSize:(ECVIntegerSize)pixelSize bytesPerRow:(size_t)bytesPerRow pixelFormat:(OSType)pixelFormat bytes:(void const *)bytes validRange:(NSRange)validRange
{
	if((self = [super init])) {
		_pixelSize = pixelSize;
		_bytesPerRow = bytesPerRow;
		_pixelFormat = pixelFormat;

		_bytes = bytes;
		_validRange = validRange;
	}
	return self;
}

#pragma mark -ECVPixelBuffer(ECVAbstract)

- (ECVIntegerSize)pixelSize
{
	return _pixelSize;
}
- (size_t)bytesPerRow
{
	return _bytesPerRow;
}
- (OSType)pixelFormat
{
	return _pixelFormat;
}

#pragma mark -

- (void const *)bytes
{
	return _bytes;
}
- (NSRange)validRange
{
	return _validRange;
}

#pragma mark -ECVPixelBuffer(ECVAbstract) <NSLocking>

- (void)lock {}
- (void)unlock {}

@end

@implementation ECVMutablePixelBuffer

#pragma mark -ECVMutablePixelBuffer

- (void)drawPixelBuffer:(ECVPixelBuffer *)src
{
	[self drawPixelBuffer:src options:kNilOptions];
}
- (void)drawPixelBuffer:(ECVPixelBuffer *)src options:(ECVPixelBufferDrawingOptions)options
{
	[self drawPixelBuffer:src options:options atPoint:(ECVIntegerPoint){0, 0}];
}
- (void)drawPixelBuffer:(ECVPixelBuffer *)src options:(ECVPixelBufferDrawingOptions)options atPoint:(ECVIntegerPoint)point
{
	ECVIntegerPoint const dstPoint = point;
	ECVIntegerPoint const srcPoint = (ECVIntegerPoint){0, 0};
	ECVDrawRect(self, src, dstPoint, srcPoint, [src pixelSize], options);
}

#pragma mark -

- (void)clearRange:(NSRange)range
{
	NSRange const r = ECVNSRebaseRange(range, [self validRange]);
	if(!r.length) return;
	uint64_t const val = ECVPixelFormatBlackPattern([self pixelFormat]);
	memset_pattern8([self mutableBytes] + r.location, &val, r.length);
}
- (void)clear
{
	NSUInteger const length = [self validRange].length;
	if(!length) return;
	uint64_t const val = ECVPixelFormatBlackPattern([self pixelFormat]);
	memset_pattern8([self mutableBytes], &val, length);
}

@end

@implementation ECVCVPixelBuffer : ECVMutablePixelBuffer

#pragma mark -ECVCVPixelBuffer

- (id)initWithPixelBuffer:(CVPixelBufferRef const)pixelBuffer
{
	NSParameterAssert(pixelBuffer);
	if((self = [super init])) {
		_pixelBuffer = CVPixelBufferRetain(pixelBuffer);
	}
	return self;
}

#pragma mark -ECVMutablePixelBuffer(ECVAbstract)

- (void *)mutableBytes
{
	return CVPixelBufferGetBaseAddress(_pixelBuffer);
}

#pragma mark -ECVPixelBuffer(ECVAbstract)

- (ECVIntegerSize)pixelSize
{
	return (ECVIntegerSize){CVPixelBufferGetWidth(_pixelBuffer), CVPixelBufferGetHeight(_pixelBuffer)};
}
- (size_t)bytesPerRow
{
	return CVPixelBufferGetBytesPerRow(_pixelBuffer);
}
- (OSType)pixelFormat
{
	return CVPixelBufferGetPixelFormatType(_pixelBuffer);
}

#pragma mark -

- (void const *)bytes
{
	return CVPixelBufferGetBaseAddress(_pixelBuffer);
}
- (NSRange)validRange
{
	return [self fullRange];
}

#pragma mark -ECVPixelBuffer(ECVAbstract) <NSLocking>

- (void)lock
{
	CVPixelBufferLockBaseAddress(_pixelBuffer, kNilOptions);
}
- (void)unlock
{
	CVPixelBufferUnlockBaseAddress(_pixelBuffer, kNilOptions);
}

#pragma mark -NSObject

- (void)dealloc
{
	CVPixelBufferRelease(_pixelBuffer);
	[super dealloc];
}

@end

@implementation ECVDataPixelBuffer

#pragma mark -ECVDataPixelBuffer

- (id)initWithPixelSize:(ECVIntegerSize)pixelSize bytesPerRow:(size_t)bytesPerRow pixelFormat:(OSType)pixelFormat data:(NSMutableData *)data offset:(NSUInteger)offset
{
	if((self = [super init])) {
		_pixelSize = pixelSize;
		_bytesPerRow = bytesPerRow;
		_pixelFormat = pixelFormat;

		_data = [data retain];
		_offset = offset;
	}
	return self;
}
- (NSMutableData *)mutableData
{
	return [[_data retain] autorelease];
}

#pragma mark -ECVMutablePixelBuffer(ECVAbstract)

- (void *)mutableBytes
{
	return [_data mutableBytes];
}

#pragma mark -ECVPixelBuffer(ECVAbstract)

- (ECVIntegerSize)pixelSize
{
	return _pixelSize;
}
- (size_t)bytesPerRow
{
	return _bytesPerRow;
}
- (OSType)pixelFormat
{
	return _pixelFormat;
}

#pragma mark -

- (void const *)bytes
{
	return [_data bytes];
}
- (NSRange)validRange
{
	return NSMakeRange(_offset, [_data length]);
}

#pragma mark -ECVPixelBuffer(ECVAbstract) <NSLocking>

- (void)lock {}
- (void)unlock {}

#pragma mark -NSObject

- (void)dealloc
{
	[_data release];
	[super dealloc];
}

@end
