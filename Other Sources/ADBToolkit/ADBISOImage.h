/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

//ADBISOImage represents the filesystem of an ISO 9660-format (.ISO, .CDR, .BIN/CUE) image.
//It provides information about the structure of the image and allows its contents to be
//iterated and extracted.

//TODOS:
// - More disc metadata (abstract name, etc.)
// - Handle Logical Block Address sizes other than 2048
// - Handle interleaved files


#import <Foundation/Foundation.h>
#import "ADBFilesystem.h"
#import "ADBISOImageConstants.h"

#pragma mark -
#pragma mark Public interface

@protocol ADBReadable, ADBSeekable;
@interface ADBISOImage : NSObject <ADBFilesystemPathAccess>
{
    id <ADBReadable, ADBSeekable> _handle;
    
    NSURL *_baseURL;
    NSString *_volumeName;
    ADBISOFormat _format;
    
    NSMutableDictionary *_pathCache;
}

//The filesystem location of the image file from which this is loaded.
//This is also used as the base URL for image-relative URLs.
@property (readonly, copy, nonatomic) NSURL *baseURL;

//The name of the image volume.
@property (readonly, copy, nonatomic) NSString *volumeName;

//The sector layout format of this ISO, detected when the ISO is first loaded.
//See ADBISOImageConstants for available constants.
@property (readonly, nonatomic) ADBISOFormat format;

#pragma mark - Constructors

//Return an image loaded from the image file at the specified source URL.
//Returns nil and populates outError if the specified image could not be read.
+ (id) imageWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError;
- (id) initWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError;

#pragma mark - ADBFilesystem API

//Clarify method signature to indicate that only readable, not writeable, file handles will be returned.
- (id <ADBFileHandleAccess, ADBReadable, ADBSeekable>) fileHandleAtPath: (NSString *)path
                                                                options: (ADBHandleOptions)options
                                                                  error: (out NSError **)outError;

@end