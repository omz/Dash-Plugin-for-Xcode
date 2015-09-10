#import <Foundation/Foundation.h>

@interface NSString (DHUtils)

- (NSString *)dh_trimNewline;
- (NSString *)dh_trimWhitespace;
- (BOOL)dh_isCaseInsensitiveEqual:(NSString *)object;
- (BOOL)dh_firstCharIsUppercase;
- (BOOL)dh_contains:(NSString *)otherString;
- (BOOL)dh_isUppercase;
- (BOOL)dh_isLowercase;
- (NSString *)dh_firstChar;
- (void)dh_enumerateLettersUsingBlock:(void (^)(NSString *letter))block;
- (NSString *)dh_stringByDeletingCharactersInSet:(NSCharacterSet *)aSet;
- (NSArray *)dh_rangesOfString:(NSString *)aString;
- (NSString *)dh_substringToString:(NSString *)string;
- (NSString *)dh_substringFromString:(NSString *)string;
- (NSString *)dh_substringFromLastOccurrenceOfString:(NSString *)string;
- (NSString *)dh_substringFromLastOccurrenceOfStringExceptSuffix:(NSString *)string;
- (NSString *)dh_substringFromStringReturningNil:(NSString *)string;
- (NSString *)dh_substringToStringReturningNil:(NSString *)string;
- (NSString *)dh_substringBetweenString:(NSString *)start andString:(NSString *)end;
- (NSString *)dh_substringWithRange:(NSRange)range;
- (NSString *)dh_substringToIndex:(NSUInteger)to;
- (NSString *)dh_substringFromIndex:(NSUInteger)from;
- (NSString *)dh_stringByAddingWildcardsEverywhere:(NSString *)escapeChar;
- (BOOL)dh_hasCaseInsensitiveSuffix:(NSString *)suffix;
- (BOOL)dh_hasCaseInsensitivePrefix:(NSString *)prefix;
- (NSString *)dh_stringByRemovingCharactersInSet:(NSCharacterSet *)aSet;

@end