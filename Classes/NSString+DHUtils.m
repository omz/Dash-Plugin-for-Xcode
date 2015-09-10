#import "NSString+DHUtils.h"

@implementation NSString (DHUtils)

- (NSString *)dh_stringByRemovingCharactersInSet:(NSCharacterSet *)aSet
{
    NSMutableString *string = [NSMutableString string];
    NSRange range = NSMakeRange(NSNotFound, 0);
    while((range = [string rangeOfCharacterFromSet:aSet]).location != NSNotFound)
    {
        [string replaceCharactersInRange:range withString:@""];
    }
    return string;
}

- (BOOL)dh_hasCaseInsensitivePrefix:(NSString *)prefix
{
    if(!prefix.length)
    {
        return NO;
    }
    return ([self rangeOfString:prefix options:NSAnchoredSearch | NSCaseInsensitiveSearch].location != NSNotFound);
}

- (BOOL)dh_hasCaseInsensitiveSuffix:(NSString *)suffix
{
    if(!suffix.length)
    {
        return NO;
    }
    return ([self rangeOfString:suffix options:NSAnchoredSearch | NSCaseInsensitiveSearch | NSBackwardsSearch].location != NSNotFound);
}

- (NSString *)dh_stringByAddingWildcardsEverywhere:(NSString *)escapeChar
{
    NSMutableString *mutable = [NSMutableString string];
    [mutable appendString:@"%"];
    for(NSInteger i = 0; i < self.length; i++)
    {
        NSString *currentChar = [self dh_substringWithRange:NSMakeRange(i, 1)];
        if([currentChar isEqualToString:escapeChar] && i+1 < self.length)
        {
            [mutable appendString:currentChar];
            [mutable appendString:[self dh_substringWithRange:NSMakeRange(i+1, 1)]];
            [mutable appendString:@"%"];
            ++i;
        }
        else
        {
            [mutable appendString:currentChar];
            [mutable appendString:@"%"];
        }
    }
    return mutable;
}

- (NSString *)dh_substringFromIndex:(NSUInteger)from
{
    if(from >= self.length)
    {
        return @"";
    }
    if(from <= 0)
    {
        return self;
    }
    return [self substringFromIndex:from];
}

- (NSString *)dh_substringToIndex:(NSUInteger)to
{
    if(to <= 0)
    {
        return @"";
    }
    if(to >= self.length)
    {
        return self;
    }
    return [self substringToIndex:to];
}

- (NSString *)dh_substringWithRange:(NSRange)range
{
    if(!self.length)
    {
        return @"";
    }
    NSRange myRange = NSMakeRange(0, self.length);
    NSRange intersect = NSIntersectionRange(myRange, range);
    if(!NSEqualRanges(range, intersect))
    {
        NSLog(@"substringWithRange exception:%@ - %@ for %@", NSStringFromRange(range), NSStringFromRange(intersect), self);
    }
    if(intersect.length)
    {
        return [self substringWithRange:intersect];
    }
    return @"";
}

- (NSString *)dh_substringBetweenString:(NSString *)start andString:(NSString *)end
{
    return [self dh_substringBetweenString:start andString:end options:NSCaseInsensitiveSearch];
}

- (NSString *)dh_substringBetweenString:(NSString *)start andString:(NSString *)end options:(NSStringCompareOptions)options
{
    NSInteger startLocation = 0;
    NSInteger endLocation = 0;
    return [self dh_substringBetweenString:start andString:end startLocation:&startLocation endLocation:&endLocation options:options];
}

- (NSString *)dh_substringBetweenString:(NSString *)start andString:(NSString *)end startLocation:(NSInteger *)startLocation endLocation:(NSInteger *)endLocation options:(NSStringCompareOptions)options
{
    NSRange startRange = [self rangeOfString:start options:options|NSCaseInsensitiveSearch];
    if(startRange.location != NSNotFound)
    {
        *startLocation = startRange.location;
        if(end == nil)
        {
            return [self dh_substringFromIndex:startRange.location+startRange.length];
        }
        NSRange endRange = [self rangeOfString:end options:NSCaseInsensitiveSearch range:NSMakeRange(startRange.location+startRange.length, self.length-startRange.location-startRange.length)];
        if(endRange.location != NSNotFound)
        {
            *endLocation = endRange.location+endRange.length;
            return [self dh_substringWithRange:NSMakeRange(startRange.location+startRange.length, endRange.location-startRange.location-startRange.length)];
        }
    }
    return nil;
}

- (NSString *)dh_substringToStringReturningNil:(NSString *)string
{
    NSRange range = [self rangeOfString:string];
    if(range.location != NSNotFound)
    {
        return [self dh_substringToIndex:range.location];
    }
    return nil;
}

- (NSString *)dh_substringFromStringReturningNil:(NSString *)string
{
    NSRange range = [self rangeOfString:string];
    if(range.location != NSNotFound)
    {
        return [self dh_substringFromIndex:range.location+range.length];
    }
    return nil;
}

- (BOOL)dh_contains:(NSString *)otherString
{
    return [self rangeOfString:otherString options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSArray *)dh_allOccurrencesOfSubstringsBetweenString:(NSString *)from andString:(NSString *)to
{
    NSMutableArray *matches = [NSMutableArray array];
    NSString *string = self;
    while(1)
    {
        NSString *match = [string dh_substringBetweenString:from andString:to options:NSLiteralSearch];
        if(match)
        {
            [matches addObject:match];
        }
        else
        {
            break;
        }
        string = [string dh_substringFromStringReturningNil:[NSString stringWithFormat:@"%@%@%@", from, match, to]];
    }
    return matches;
}

- (NSString *)dh_substringToString:(NSString *)string
{
    NSRange range = [self rangeOfString:string];
    if(range.location != NSNotFound)
    {
        return [self dh_substringToIndex:range.location];
    }
    return self;
}

- (NSString *)dh_substringToLastOccurrenceOfString:(NSString *)string
{
    NSRange range = [self rangeOfString:string options:NSBackwardsSearch];
    if(range.location != NSNotFound)
    {
        return [self dh_substringToIndex:range.location];
    }
    return self;
}

- (NSString *)dh_substringFromLastOccurrenceOfStringExceptSuffix:(NSString *)string
{
    if(self.length <= 1)
    {
        return self;
    }
    NSRange range = [self rangeOfString:string options:NSBackwardsSearch range:NSMakeRange(0, self.length-1)];
    if(range.location != NSNotFound)
    {
        return [self dh_substringFromIndex:range.location+range.length];
    }
    return self;
}

- (NSString *)dh_substringFromLastOccurrenceOfString:(NSString *)string
{
    NSRange range = [self rangeOfString:string options:NSBackwardsSearch];
    if(range.location != NSNotFound)
    {
        return [self dh_substringFromIndex:range.location+range.length];
    }
    return self;
}

- (NSString *)dh_substringFromString:(NSString *)string
{
    NSRange range = [self rangeOfString:string];
    if(range.location != NSNotFound)
    {
        return [self dh_substringFromIndex:range.location+range.length];
    }
    return self;
}

- (NSArray *)dh_rangesOfString:(NSString *)aString
{
    NSMutableArray *ranges = [NSMutableArray array];
    NSRange range = [self rangeOfString:aString options:NSCaseInsensitiveSearch];
    while(range.location != NSNotFound)
    {
        [ranges addObject:[NSValue valueWithRange:range]];
        range = [self rangeOfString:aString options:NSCaseInsensitiveSearch range:NSMakeRange(range.location+range.length, self.length-range.location-range.length)];
    }
    return ranges;
}

- (NSString *)dh_stringByDeletingCharactersInSet:(NSCharacterSet *)aSet removedRanges:(NSMutableArray *)removedRanges
{
    NSRange charRange = NSMakeRange(self.length, 0);
    NSMutableString *mutableString = [NSMutableString stringWithString:self];
    while((charRange = [self rangeOfCharacterFromSet:aSet options:NSBackwardsSearch range:NSMakeRange(0, charRange.location)]).location != NSNotFound)
    {
        if(removedRanges)
        {
            [removedRanges addObject:[NSValue valueWithRange:charRange]];            
        }
        [mutableString replaceCharactersInRange:charRange withString:@""];
    }
    if(removedRanges && removedRanges.count > 0)
    {
        NSUInteger i = 0;
        NSUInteger j = [removedRanges count] - 1;
        while (i < j)
        {
            [removedRanges exchangeObjectAtIndex:i withObjectAtIndex:j];
            i++;
            j--;
        }
    }
    return mutableString;
}

- (NSString *)dh_stringByDeletingCharactersInSet:(NSCharacterSet *)aSet
{
    return [self dh_stringByDeletingCharactersInSet:aSet removedRanges:nil];
}

- (void)dh_enumerateLettersUsingBlock:(void (^)(NSString *letter))block
{
    for(NSUInteger i = 0; i < self.length; i++)
    {
        NSString *letter = [self substringWithRange:NSMakeRange(i, 1)];
        block(letter);
    }
}

- (NSString *)dh_firstChar
{
    return [self dh_substringToIndex:1];
}

- (BOOL)dh_isLowercase
{
    return [[self lowercaseString] isEqualToString:self];
}

- (BOOL)dh_isUppercase
{
    return [[self uppercaseString] isEqualToString:self];
}

- (BOOL)dh_firstCharIsUppercase
{
    NSString *firstChar = [self dh_firstChar];
    return [[firstChar uppercaseString] isEqualToString:firstChar];
}

- (BOOL)dh_firstCharIsLowercase
{
    NSString *firstChar = [self dh_firstChar];
    return [[firstChar lowercaseString] isEqualToString:firstChar];
}

- (BOOL)dh_isCaseInsensitiveEqual:(NSString *)object
{
    if(!object)
    {
        return NO;
    }
    return [self caseInsensitiveCompare:object] == NSOrderedSame;
}

- (NSString *)dh_trimWhitespace
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)dh_trimNewline
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

@end
