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
#import "ECVRational.h"

NSInteger ECVIntegerGCD(NSInteger a, NSInteger b)
{
	return b ? ECVIntegerGCD(b, a - (b * (a / b))) : a;
}
NSUInteger ECVIntegerLCM(NSInteger a, NSInteger b)
{
	NSInteger gcd = ECVIntegerGCD(a, b);
	return ABS((a * b) / gcd);
}

ECVRational ECVRationalGCD(ECVRational a, ECVRational b)
{
	if(!b.numer) return a;
	ECVRational const f = ECVMakeRational(floor(ECVRationalToCGFloat(ECVRationalDivide(a, b))), 1);
	return ECVRationalGCD(b, ECVRationalSubtract(a, ECVRationalMultiply(b, f)));
}
ECVRational ECVRationalLCM(ECVRational a, ECVRational b)
{
	ECVRational const gcd = ECVRationalGCD(a, b);
	return ECVMakeRational(ABS(a.numer * b.numer * gcd.denom), ABS(a.denom * b.denom * gcd.numer));
}
NSString *ECVRationalToString(ECVRational r)
{
	return [NSString stringWithFormat:@"{%ld / %ld}", (unsigned long)r.numer, (unsigned long)r.denom];
}
