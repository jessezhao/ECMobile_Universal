//
//	 ______    ______    ______
//	/\  __ \  /\  ___\  /\  ___\
//	\ \  __<  \ \  __\_ \ \  __\_
//	 \ \_____\ \ \_____\ \ \_____\
//	  \/_____/  \/_____/  \/_____/
//
//
//	Copyright (c) 2013-2014, {Bee} open source community
//	http://www.bee-framework.com
//
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the "Software"),
//	to deal in the Software without restriction, including without limitation
//	the rights to use, copy, modify, merge, publish, distribute, sublicense,
//	and/or sell copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//	IN THE SOFTWARE.
//

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

#import "Bee_UIImageView.h"
#import "Bee_Cache.h"
#import "Bee_Network.h"
#import "Bee_UIActivityIndicatorView.h"

#import "UIImage+BeeExtension.h"

#import "UIView+BeeUISignal.h"
#import "UIView+LifeCycle.h"

#pragma mark -

@interface BeeImageCache()
{
	BOOL				_asyncLoad;
	BOOL				_asyncSave;
	
	BeeMemoryCache *	_memoryCache;
	BeeFileCache *		_fileCache;
}

@property (atomic, retain) BeeMemoryCache *		memoryCache;
@property (atomic, retain) BeeFileCache *		fileCache;

@end

#pragma mark -

@implementation BeeImageCache

DEF_SINGLETON( BeeImageCache );

@synthesize asyncLoad = _asyncLoad;
@synthesize asyncSave = _asyncSave;

@synthesize memoryCache = _memoryCache;
@synthesize fileCache = _fileCache;

- (id)init
{
	self = [super init];
	if ( self )
	{
		_memoryCache = [[BeeMemoryCache alloc] init];
		_memoryCache.clearWhenMemoryLow = YES;

		_fileCache = [[BeeFileCache alloc] init];
		_fileCache.cachePath = [NSString stringWithFormat:@"%@/ImageCache/", [BeeSandbox libCachePath]];
		_fileCache.cacheUser = @"";
	}
	return self;
}

- (void)dealloc
{
	self.memoryCache = nil;
	self.fileCache = nil;

    [super dealloc];
}

- (BOOL)hasCachedForURL:(NSString *)string
{
	NSString * cacheKey = [string MD5];
	
	BOOL flag = [self.memoryCache hasObjectForKey:cacheKey];
	if ( NO == flag )
	{
		flag = [self.fileCache hasObjectForKey:cacheKey];
	}
	
	return flag;	
}

- (BOOL)hasFileCachedForURL:(NSString *)url
{
	NSString * cacheKey = [url MD5];
	
	return [self.fileCache hasObjectForKey:cacheKey];
}

- (BOOL)hasMemoryCachedForURL:(NSString *)url
{
	NSString * cacheKey = [url MD5];
	
	return [self.memoryCache hasObjectForKey:cacheKey];
}

- (UIImage *)fileImageForURL:(NSString *)url
{
	NSString *	cacheKey = [url MD5];
	UIImage *	image = nil;

	NSString * fullPath = [self.fileCache fileNameForKey:cacheKey];
	if ( fullPath )
	{
		image = [[[UIImage alloc] initWithContentsOfFile:fullPath] autorelease];
		
		UIImage * cachedImage = (UIImage *)[self.memoryCache objectForKey:cacheKey];
		if ( nil == cachedImage && image != cachedImage )
		{
			[self.memoryCache setObject:image forKey:cacheKey];
		}
	}

	return image;
}

- (UIImage *)memoryImageForURL:(NSString *)url
{
	NSString *	cacheKey = [url MD5];
	UIImage *	image = nil;
	
	NSObject * object = [self.memoryCache objectForKey:cacheKey];
	if ( object && [object isKindOfClass:[UIImage class]] )
	{
		image = (UIImage *)object;
	}

	return image;
}


- (UIImage *)imageForURL:(NSString *)string
{
	UIImage * image = [self memoryImageForURL:string];
	if ( nil == image )
	{
		image = [self fileImageForURL:string];
	}
	return image;
}

- (void)saveImage:(UIImage *)image forURL:(NSString *)string
{
	NSString * cacheKey = [string MD5];
	UIImage * cachedImage = (UIImage *)[self.memoryCache objectForKey:cacheKey];
	if ( nil == cachedImage && image != cachedImage )
	{
		[self.memoryCache setObject:image forKey:cacheKey];
	}
}

- (void)saveData:(NSData *)data forURL:(NSString *)string
{
	NSString * cacheKey = [string MD5];
	[self.fileCache setObject:data forKey:cacheKey];
}

- (void)deleteImageForURL:(NSString *)string
{
	NSString * cacheKey = [string MD5];
	
	[self.memoryCache removeObjectForKey:cacheKey];
	[self.fileCache removeObjectForKey:cacheKey];
}

- (void)deleteAllImages
{
	[self.memoryCache removeAllObjects];
	[self.fileCache removeAllObjects];
}

@end

#pragma mark -

@interface BeeUIImageView()
{
	BOOL							_inited;
	BOOL							_gray;
	BOOL							_round;
	BOOL							_pattern;
	BOOL							_strech;
	UIEdgeInsets					_strechInsets;
	BOOL							_loading;
	BeeUILabel *					_altLabel;
	BeeUIActivityIndicatorView *	_indicator;
	NSString *						_loadedURL;
	BOOL							_loaded;
	UIImage *						_defaultImage;
}

- (void)initSelf;
- (void)changeImage:(UIImage *)image;

@end

@implementation BeeUIImageView

DEF_SIGNAL( LOAD_START )
DEF_SIGNAL( LOAD_COMPLETED )
DEF_SIGNAL( LOAD_FAILED )
DEF_SIGNAL( LOAD_CANCELLED )
DEF_SIGNAL( LOAD_CACHE )

//DEF_SIGNAL( WILL_CHANGE )
//DEF_SIGNAL( DID_CHANGED )

@synthesize gray = _gray;
@synthesize round = _round;
@synthesize pattern = _pattern;
@synthesize strech = _strech;
@synthesize strechInsets = _strechInsets;
@synthesize loading = _loading;
@synthesize altLabel = _altLabel;
@synthesize indicator = _indicator;
@dynamic indicatorStyle;
@dynamic indicatorColor;
@synthesize loadedURL = _loadedURL;
@synthesize loaded	= _loaded;
@synthesize defaultImage = _defaultImage;

@synthesize url;
@synthesize file;
@synthesize resource;

- (id)init
{
	self = [super init];
	if ( self )
	{
		[self initSelf];
	}
	return self;
}

- (id)initWithImage:(UIImage *)image
{
	self = [super initWithImage:image];
	if ( self )
	{
		[self initSelf];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if ( self )
	{
		[self initSelf];
	}
	return self;
}

- (void)initSelf
{
	if ( NO == _inited )
	{
		self.hidden = NO;
		self.backgroundColor = [UIColor clearColor];
		self.layer.masksToBounds = YES;
		self.layer.opaque = YES;
		self.contentMode = UIViewContentModeCenter;

		_loading = NO;
		_loaded	 = NO;

		_gray = NO;
		_round = NO;
		_pattern = NO;
		_strech = NO;
		_strechInsets = UIEdgeInsetsZero;
		
		_inited = YES;

		[self load];
	}
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[self unload];
	
	[self cancelRequests];
	
	self.loadedURL = nil;
	self.loading = NO;
	self.defaultImage = nil;
	self.image = nil;
	
	[_indicator removeFromSuperview];
	[_indicator release];
	
	[_altLabel removeFromSuperview];
	[_altLabel release];
	
	[super dealloc];
}

- (void)GET:(NSString *)string useCache:(BOOL)useCache
{
	[self GET:string useCache:useCache placeHolder:nil];
}

- (void)GET:(NSString *)string useCache:(BOOL)useCache placeHolder:(UIImage *)defaultImage
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	self.defaultImage = defaultImage;

	if ( nil == string || 0 == string.length )
	{
		[self changeImage:nil];
		return;
	}

	if ( NO == [string hasPrefix:@"http://"] )
	{
		string = [NSString stringWithFormat:@"http://%@", string];
	}
	
	if ( [string isEqualToString:self.loadedURL] )
	{
		[self setNeedsDisplay];
		return;
	}

	if ( [self requestingURL:string] )
	{
		[self setNeedsDisplay];
		return;
	}

	self.loading	= NO;
	self.loadedURL	= string;
	self.loaded		= NO;
	
	[self cancelRequests];

	if ( useCache )
	{
		BeeImageCache * cache = [BeeImageCache sharedInstance];
		if ( cache.asyncLoad )
		{
			if ( [cache hasMemoryCachedForURL:string] )
			{
				UIImage * image = [cache memoryImageForURL:string];
				if ( image )
				{
					[self changeImage:image];
					self.loaded = YES;

					[self sendUISignal:BeeUIImageView.LOAD_CACHE];
					return;
				}	
			}
			else if ( [cache hasFileCachedForURL:string] )
			{
				[self changeImage:self.defaultImage];

				BACKGROUND_BEGIN
				{
					UIImage * newImage = [cache fileImageForURL:string];
					if ( newImage )
					{
						FOREGROUND_BEGIN
						{
							if ( newImage )
							{
								[self changeImage:newImage];
								self.loaded = YES;
								
								[self sendUISignal:BeeUIImageView.LOAD_CACHE];
							}
							else
							{
								[self HTTP_GET:string].timeOutSeconds = 20.0f;
							}

							return;
						}
						FOREGROUND_COMMIT
					}
				}
				BACKGROUND_COMMIT

				return;
			}
		}
		else
		{
			if ( [cache hasCachedForURL:string] )
			{
				UIImage * image = [cache imageForURL:string];
				if ( image )
				{
					[self changeImage:image];
					self.loaded = YES;
					
					[self sendUISignal:BeeUIImageView.LOAD_CACHE];
					return;
				}
			}
		}
	}

	[self changeImage:self.defaultImage];
	[self HTTP_GET:string].timeOutSeconds = 20.0f;
}

- (void)setUrl:(NSString *)string
{
	[self GET:string useCache:YES];
}

- (void)setFile:(NSString *)path
{
	if ( nil == path )
		return;
	
	UIImage * image = [[[UIImage alloc] initWithContentsOfFile:path] autorelease];
	if ( image )
	{
		[self changeImage:image];
	}
	else
	{
		[self changeImage:nil/*self.defaultImage*/];
	}
}

- (void)setResource:(NSString *)string
{
	UIImage * image = [UIImage imageNamed:string];
	if ( image )
	{
		[self changeImage:image];
	}
	else
	{
		[self changeImage:nil/*self.defaultImage*/];
	}
}

- (void)setImage:(UIImage *)image
{
	[self changeImage:image];
}

- (void)changeImage:(UIImage *)image
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	if ( nil == image )
	{
		[self cancelRequests];
		
		self.loadedURL = nil;
		self.loading = NO;
		self.loaded = NO;

		[super setImage:self.defaultImage];
		[super setNeedsDisplay];
		return;
	}

	if ( image != self.image )
	{
		UIColor * backgroundColor = nil;
		
//		[self sendUISignal:BeeUIImageView.WILL_CHANGE];
		
		[self cancelRequests];

		if ( self.round )
		{
			image = [image rounded];
		}

		if ( self.gray )
		{
			image = [image grayscale];
		}
		
		if ( self.strech )
		{
			if ( NO == UIEdgeInsetsEqualToEdgeInsets(_strechInsets, UIEdgeInsetsZero) )
			{
				image = [image stretched:_strechInsets];
			}
			else
			{
				image = [image stretched];
			}
		}
		
		if ( self.pattern )
		{
			backgroundColor = [UIColor colorWithPatternImage:image];
		}
 
		if ( backgroundColor )
		{
			[super setBackgroundColor:backgroundColor];
			[super setImage:nil];
		}
		else
		{
			CGAffineTransform	transform = CGAffineTransformIdentity;
			UIImageOrientation	orientation = image.imageOrientation;
			
			switch ( orientation )
			{
				case UIImageOrientationDown:           // EXIF = 3
				case UIImageOrientationDownMirrored:   // EXIF = 4
					transform = CGAffineTransformRotate(transform, M_PI);
					break;
					
				case UIImageOrientationLeft:           // EXIF = 6
				case UIImageOrientationLeftMirrored:   // EXIF = 5
					transform = CGAffineTransformRotate(transform, M_PI_2);
					break;
					
				case UIImageOrientationRight:          // EXIF = 8
				case UIImageOrientationRightMirrored:  // EXIF = 7
					transform = CGAffineTransformRotate(transform, -M_PI_2);
					break;
				case UIImageOrientationUp:
				case UIImageOrientationUpMirrored:
					break;
			}

			[super setTransform:transform];
			[super setImage:image];
		}

//		[self sendUISignal:BeeUIImageView.DID_CHANGED];
	}
	
	[self setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame
{
	[super setFrame:frame];

	if ( _indicator )
	{
		CGRect indicatorFrame;
		indicatorFrame.size.width = 20.0f;
		indicatorFrame.size.height = 20.0f;
		indicatorFrame.origin.x = (frame.size.width - indicatorFrame.size.width) / 2.0f;
		indicatorFrame.origin.y = (frame.size.height - indicatorFrame.size.height) / 2.0f;
		
		_indicator.frame = indicatorFrame;
	}

	if ( _altLabel )
	{
		_altLabel.frame = CGRectMake( 0, 0, frame.size.width, frame.size.height );
	}
}

- (void)clear
{
	[self cancelRequests];
	[self changeImage:nil];

	self.loadedURL = nil;
	self.loading = NO;
}

- (BeeUILabel *)altLabel
{
	if ( nil == _altLabel )
	{
		_altLabel = [[BeeUILabel alloc] initWithFrame:self.bounds];
		_altLabel.backgroundColor = [UIColor clearColor];
		_altLabel.lineBreakMode = UILineBreakModeTailTruncation;
		_altLabel.numberOfLines = 1;
		_altLabel.textColor = [UIColor blackColor];
		_altLabel.textAlignment = UITextAlignmentCenter;
		_altLabel.font = [UIFont boldSystemFontOfSize:12.0f];
		[self addSubview:_altLabel];
		[self bringSubviewToFront:_altLabel];
	}

	return _altLabel;	
}

- (BeeUIActivityIndicatorView *)indicator
{
	if ( nil == _indicator )
	{
		CGRect indicatorFrame;
		indicatorFrame.size.width = 20.0f;
		indicatorFrame.size.height = 20.0f;
		indicatorFrame.origin.x = (self.frame.size.width - indicatorFrame.size.width) / 2.0f;
		indicatorFrame.origin.y = (self.frame.size.height - indicatorFrame.size.height) / 2.0f;
		
		_indicator = [[BeeUIActivityIndicatorView alloc] initWithFrame:indicatorFrame];
		_indicator.backgroundColor = [UIColor clearColor];
		[self addSubview:_indicator];
	}
	
	return _indicator;
}

- (UIActivityIndicatorViewStyle)indicatorStyle
{
	return self.indicator.activityIndicatorViewStyle;
}

- (void)setIndicatorStyle:(UIActivityIndicatorViewStyle)value
{
	self.indicator.activityIndicatorViewStyle = value;
}

- (UIColor *)indicatorColor
{
	if ( [self.indicator respondsToSelector:@selector(color)] )
	{
		return self.indicator.color;
	}
	
	return [UIColor clearColor];
}

- (void)setIndicatorColor:(UIColor *)color
{
	if ( [self.indicator respondsToSelector:@selector(setColor:)] )
	{
		self.indicator.color = color;
	}
}

#pragma mark -
#pragma mark NetworkRequestDelegate

- (void)handleRequest:(BeeHTTPRequest *)request
{
	if ( request.sending )
	{
		[_indicator startAnimating];

		[self setLoading:YES];
		[self sendUISignal:BeeUIImageView.LOAD_START];
	}
	else if ( request.sendProgressed )
	{
	}
	else if ( request.recving )
	{
	}
	else if ( request.recvProgressed )
	{
	}
	else if ( request.succeed )
	{
		[_indicator stopAnimating];

		NSData * data = [request responseData];
		if ( data )
		{
			UIImage * image = [UIImage imageWithData:data];
			if ( image )
			{
				NSString * string = [request.url absoluteString];
				
				BeeImageCache * cache = [BeeImageCache sharedInstance];
				if ( cache.asyncSave )
				{
					FOREGROUND_BEGIN
					{
						[cache saveImage:image forURL:string];
						
						BACKGROUND_BEGIN
						{
							[cache saveData:data forURL:string];					
						}
						BACKGROUND_COMMIT
					}
					FOREGROUND_COMMIT
				}
				else
				{
					[cache saveImage:image forURL:string];
					[cache saveData:data forURL:string];
				}
				
				[self setLoading:NO];
				self.loaded = YES;
				
				[self changeImage:image];

				[self sendUISignal:BeeUIImageView.LOAD_COMPLETED];
			}
			else
			{
				[self setLoading:NO];
				self.loaded = NO;
				
				[self sendUISignal:BeeUIImageView.LOAD_FAILED];
			}
		}
		else
		{
			[self setLoading:NO];
			self.loaded = NO;
			
			[self sendUISignal:BeeUIImageView.LOAD_FAILED];
		}
	}
	else if ( request.failed )
	{
		[_indicator stopAnimating];	
		
		[self setLoading:NO];
		self.loaded = NO;
		[self sendUISignal:BeeUIImageView.LOAD_FAILED];
	}
	else if ( request.cancelled )
	{
		[_indicator stopAnimating];
		
		[self setLoading:NO];
		[self sendUISignal:BeeUIImageView.LOAD_CANCELLED];
	}
}

#pragma mark -
#pragma mark NetworkRequestDelegate

- (void)handleUISignal:(BeeUISignal *)signal
{
	FORWARD_SIGNAL( signal );

	if ( [signal is:BeeUIImageView.LOAD_START] )
	{
		if ( _altLabel )
		{
			_altLabel.hidden = NO;
		}
	}
	else if ( [signal is:BeeUIImageView.LOAD_COMPLETED] )
	{
		if ( _altLabel )
		{
			_altLabel.hidden = YES;
		}		
	}
	else if ( [signal is:BeeUIImageView.LOAD_FAILED] )
	{
		if ( _altLabel )
		{
			_altLabel.hidden = NO;
		}
	}
	else if ( [signal is:BeeUIImageView.LOAD_CANCELLED] )
	{
		if ( _altLabel )
		{
			_altLabel.hidden = NO;
		}
	}
	else if ( [signal is:BeeUIImageView.LOAD_CACHE] )
	{
		if ( _altLabel )
		{
			_altLabel.hidden = YES;
		}
	}
}

@end

#endif	// #if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
