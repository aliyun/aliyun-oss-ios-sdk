//
//  XMLDictionary.m
//
//  Version 1.4
//
//  Created by Nick Lockwood on 15/11/2010.
//  Copyright 2010 Charcoal Design. All rights reserved.
//
//  Get the latest version of XMLDictionary from here:
//
//  https://github.com/nicklockwood/XMLDictionary
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "OSSXMLDictionary.h"


#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"
#pragma GCC diagnostic ignored "-Wformat-non-iso"
#pragma GCC diagnostic ignored "-Wgnu"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


@interface OSSXMLDictionaryParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableDictionary *root;
@property (nonatomic, strong) NSMutableArray *stack;
@property (nonatomic, strong) NSMutableString *text;

@end


@implementation OSSXMLDictionaryParser

- (id)init
{
    if ((self = [super init]))
    {
        _collapseTextNodes = YES;
        _stripEmptyNodes = YES;
        _trimWhiteSpace = YES;
        _alwaysUseArrays = NO;
        _preserveComments = NO;
        _wrapRootNode = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    OSSXMLDictionaryParser *copy = [[[self class] allocWithZone:zone] init];
    copy.collapseTextNodes = _collapseTextNodes;
    copy.stripEmptyNodes = _stripEmptyNodes;
    copy.trimWhiteSpace = _trimWhiteSpace;
    copy.alwaysUseArrays = _alwaysUseArrays;
    copy.preserveComments = _preserveComments;
    copy.attributesMode = _attributesMode;
    copy.nodeNameMode = _nodeNameMode;
    copy.wrapRootNode = _wrapRootNode;
    return copy;
}

#pragma mark - Public Methods

+ (OSSXMLDictionaryParser *)sharedInstance
{
    static dispatch_once_t once;
    static OSSXMLDictionaryParser *sharedInstance;
    dispatch_once(&once, ^{
        
        sharedInstance = [[OSSXMLDictionaryParser alloc] init];
    });
    return sharedInstance;
}

- (NSDictionary *)dictionaryWithParser:(NSXMLParser *)parser
{
    [parser setDelegate:self];
    BOOL succeed = [parser parse];
#ifdef DEBUG
    NSLog(@"dictionaryWithParser %@",(succeed?@"YES":@"NO"));
#endif
    id result = _root;
    _root = nil;
    _stack = nil;
    _text = nil;
    return result;
}

- (NSDictionary *)dictionaryWithData:(NSData *)data
{
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    return [self dictionaryWithParser:parser];
}

- (NSDictionary *)dictionaryWithString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self dictionaryWithData:data];
}

- (NSDictionary *)dictionaryWithFile:(NSString *)path
{	
	NSData *data = [NSData dataWithContentsOfFile:path];
	return [self dictionaryWithData:data];
}

#pragma mark - Private Methods

+ (NSString *)XMLStringForNode:(id)node withNodeName:(NSString *)nodeName
{	
    if ([node isKindOfClass:[NSArray class]])
    {
        NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:[node count]];
        for (id individualNode in node)
        {
            [nodes addObject:[self XMLStringForNode:individualNode withNodeName:nodeName]];
        }
        return [nodes componentsJoinedByString:@"\n"];
    }
    else if ([node isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *attributes = [(NSDictionary *)node oss_attributes];
        NSMutableString *attributeString = [NSMutableString string];
        for (NSString *key in [attributes allKeys])
        {
            [attributeString appendFormat:@" %@=\"%@\"", [[key description] oss_XMLEncodedString], [[attributes[key] description] oss_XMLEncodedString]];
        }
        
        NSString *innerXML = [node oss_innerXML];
        if ([innerXML length])
        {
            return [NSString stringWithFormat:@"<%1$@%2$@>%3$@</%1$@>", nodeName, attributeString, innerXML];
        }
        else
        {
            return [NSString stringWithFormat:@"<%@%@/>", nodeName, attributeString];
        }
    }
    else
    {
        return [NSString stringWithFormat:@"<%1$@>%2$@</%1$@>", nodeName, [[node description] oss_XMLEncodedString]];
    }
}

- (void)endText
{
	if (_trimWhiteSpace)
	{
		_text = [[_text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
	}
	if ([_text length])
	{
        NSMutableDictionary *top = [_stack lastObject];
		id existing = top[OSSXMLDictionaryTextKey];
        if ([existing isKindOfClass:[NSArray class]])
        {
            [existing addObject:_text];
        }
        else if (existing)
        {
            top[OSSXMLDictionaryTextKey] = [@[existing, _text] mutableCopy];
        }
		else
		{
			top[OSSXMLDictionaryTextKey] = _text;
		}
	}
	_text = nil;
}

- (void)addText:(NSString *)text
{	
	if (!_text)
	{
		_text = [NSMutableString stringWithString:text];
	}
	else
	{
		[_text appendString:text];
	}
}

- (NSString *)nameForNode:(NSDictionary *)node inDictionary:(NSDictionary *)dict
{
    if (node.oss_nodeName)
    {
        return node.oss_nodeName;
    }
    else
    {
        for (NSString *name in dict)
        {
            id object = dict[name];
            if (object == node)
            {
                return name;
            }
            else if ([object isKindOfClass:[NSArray class]] && [object containsObject:node])
            {
                return name;
            }
        }
    }
    return nil;
}

#pragma mark - NSXMLParserDelegate mehods

- (void)parser:(__unused NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName attributes:(NSDictionary *)attributeDict
{	
	[self endText];
	
	NSMutableDictionary *node = [NSMutableDictionary dictionary];
	switch (_nodeNameMode)
	{
        case OSSXMLDictionaryNodeNameModeRootOnly:
        {
            if (!_root)
            {
                node[OSSXMLDictionaryNodeNameKey] = elementName;
            }
            break;
        }
        case OSSXMLDictionaryNodeNameModeAlways:
        {
            node[OSSXMLDictionaryNodeNameKey] = elementName;
            break;
        }
        case OSSXMLDictionaryNodeNameModeNever:
        {
            break;
        }
	}
    
	if ([attributeDict count])
	{
        switch (_attributesMode)
        {
            case OSSXMLDictionaryAttributesModePrefixed:
            {
                for (NSString *key in [attributeDict allKeys])
                {
                    node[[OSSXMLDictionaryAttributePrefix stringByAppendingString:key]] = attributeDict[key];
                }
                break;
            }
            case OSSXMLDictionaryAttributesModeDictionary:
            {
                node[OSSXMLDictionaryAttributesKey] = attributeDict;
                break;
            }
            case OSSXMLDictionaryAttributesModeUnprefixed:
            {
                [node addEntriesFromDictionary:attributeDict];
                break;
            }
            case OSSXMLDictionaryAttributesModeDiscard:
            {
                break;
            }
        }
	}
	
	if (!_root)
	{
        _root = node;
        _stack = [NSMutableArray arrayWithObject:node];
        if (_wrapRootNode)
        {
            _root = [NSMutableDictionary dictionaryWithObject:_root forKey:elementName];
            [_stack insertObject:_root atIndex:0];
        }
	}
	else
	{
        NSMutableDictionary *top = [_stack lastObject];
		id existing = top[elementName];
        if ([existing isKindOfClass:[NSArray class]])
        {
            [existing addObject:node];
        }
        else if (existing)
        {
            top[elementName] = [@[existing, node] mutableCopy];
        }
        else if (_alwaysUseArrays)
        {
            top[elementName] = [NSMutableArray arrayWithObject:node];
        }
		else
		{
			top[elementName] = node;
		}
		[_stack addObject:node];
	}
}

- (void)parser:(__unused NSXMLParser *)parser didEndElement:(__unused NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName
{	
	[self endText];
    
    NSMutableDictionary *top = [_stack lastObject];
    [_stack removeLastObject];
    
	if (!top.oss_attributes && !top.oss_childNodes && !top.oss_comments)
    {
        NSMutableDictionary *newTop = [_stack lastObject];
        NSString *nodeName = [self nameForNode:top inDictionary:newTop];
        if (nodeName)
        {
            id parentNode = newTop[nodeName];
            if (top.oss_innerText && _collapseTextNodes)
            {
                if ([parentNode isKindOfClass:[NSArray class]])
                {
                    parentNode[[parentNode count] - 1] = top.oss_innerText;
                }
                else
                {
                    newTop[nodeName] = top.oss_innerText;
                }
            }
            else if (!top.oss_innerText && _stripEmptyNodes)
            {
                if ([parentNode isKindOfClass:[NSArray class]])
                {
                    [parentNode removeLastObject];
                }
                else
                {
                    [newTop removeObjectForKey:nodeName];
                }
            }
            else if (!top.oss_innerText && !_collapseTextNodes && !_stripEmptyNodes)
            {
                top[OSSXMLDictionaryTextKey] = @"";
            }
        }
	}
}

- (void)parser:(__unused NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[self addText:string];
}

- (void)parser:(__unused NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
	[self addText:[[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding]];
}

- (void)parser:(__unused NSXMLParser *)parser foundComment:(NSString *)comment
{
	if (_preserveComments)
	{
        NSMutableDictionary *top = [_stack lastObject];
		NSMutableArray *comments = top[OSSXMLDictionaryCommentsKey];
		if (!comments)
		{
			comments = [@[comment] mutableCopy];
			top[OSSXMLDictionaryCommentsKey] = comments;
		}
		else
		{
			[comments addObject:comment];
		}
	}
}

@end


@implementation NSDictionary(OSSXMLDictionary)

+ (NSDictionary *)oss_dictionaryWithXMLParser:(NSXMLParser *)parser
{
	return [[[OSSXMLDictionaryParser sharedInstance] copy] dictionaryWithParser:parser];
}

+ (NSDictionary *)oss_dictionaryWithXMLData:(NSData *)data
{
	return [[[OSSXMLDictionaryParser sharedInstance] copy] dictionaryWithData:data];
}

+ (NSDictionary *)oss_dictionaryWithXMLString:(NSString *)string
{
	return [[[OSSXMLDictionaryParser sharedInstance] copy] dictionaryWithString:string];
}

+ (NSDictionary *)oss_dictionaryWithXMLFile:(NSString *)path
{
	return [[[OSSXMLDictionaryParser sharedInstance] copy] dictionaryWithFile:path];
}

- (NSDictionary *)oss_attributes
{
	NSDictionary *attributes = self[OSSXMLDictionaryAttributesKey];
	if (attributes)
	{
		return [attributes count]? attributes: nil;
	}
	else
	{
		NSMutableDictionary *filteredDict = [NSMutableDictionary dictionaryWithDictionary:self];
        [filteredDict removeObjectsForKeys:@[OSSXMLDictionaryCommentsKey, OSSXMLDictionaryTextKey, OSSXMLDictionaryNodeNameKey]];
        for (NSString *key in [filteredDict allKeys])
        {
            [filteredDict removeObjectForKey:key];
            if ([key hasPrefix:OSSXMLDictionaryAttributePrefix])
            {
                filteredDict[[key substringFromIndex:[OSSXMLDictionaryAttributePrefix length]]] = self[key];
            }
        }
        return [filteredDict count]? filteredDict: nil;
	}
	return nil;
}

- (NSDictionary *)oss_childNodes
{	
	NSMutableDictionary *filteredDict = [self mutableCopy];
	[filteredDict removeObjectsForKeys:@[OSSXMLDictionaryAttributesKey, OSSXMLDictionaryCommentsKey, OSSXMLDictionaryTextKey, OSSXMLDictionaryNodeNameKey]];
	for (NSString *key in [filteredDict allKeys])
    {
        if ([key hasPrefix:OSSXMLDictionaryAttributePrefix])
        {
            [filteredDict removeObjectForKey:key];
        }
    }
    return [filteredDict count]? filteredDict: nil;
}

- (NSArray *)oss_comments
{
	return self[OSSXMLDictionaryCommentsKey];
}

- (NSString *)oss_nodeName
{
	return self[OSSXMLDictionaryNodeNameKey];
}

- (id)oss_innerText
{	
	id text = self[OSSXMLDictionaryTextKey];
	if ([text isKindOfClass:[NSArray class]])
	{
		return [text componentsJoinedByString:@"\n"];
	}
	else
	{
		return text;
	}
}

- (NSString *)oss_innerXML
{	
	NSMutableArray *nodes = [NSMutableArray array];
	
	for (NSString *comment in [self oss_comments])
	{
        [nodes addObject:[NSString stringWithFormat:@"<!--%@-->", [comment oss_XMLEncodedString]]];
	}
    
    NSDictionary *childNodes = [self oss_childNodes];
	for (NSString *key in childNodes)
	{
		[nodes addObject:[OSSXMLDictionaryParser XMLStringForNode:childNodes[key] withNodeName:key]];
	}
	
    NSString *text = [self oss_innerText];
    if (text)
    {
        [nodes addObject:[text oss_XMLEncodedString]];
    }
	
	return [nodes componentsJoinedByString:@"\n"];
}

- (NSString *)oss_XMLString
{
    if ([self count] == 1 && ![self oss_nodeName])
    {
        //ignore outermost dictionary
        return [self oss_innerXML];
    }
    else
    {
        return [OSSXMLDictionaryParser XMLStringForNode:self withNodeName:[self oss_nodeName] ?: @"root"];
    }
}

- (NSArray *)oss_arrayValueForKeyPath:(NSString *)keyPath
{
    id value = [self valueForKeyPath:keyPath];
    if (value && ![value isKindOfClass:[NSArray class]])
    {
        return @[value];
    }
    return value;
}

- (NSString *)oss_stringValueForKeyPath:(NSString *)keyPath
{
    id value = [self valueForKeyPath:keyPath];
    if ([value isKindOfClass:[NSArray class]])
    {
        value = [value count]? value[0]: nil;
    }
    if ([value isKindOfClass:[NSDictionary class]])
    {
        return [(NSDictionary *)value oss_innerText];
    }
    return value;
}

- (NSDictionary *)oss_dictionaryValueForKeyPath:(NSString *)keyPath
{
    id value = [self valueForKeyPath:keyPath];
    if ([value isKindOfClass:[NSArray class]])
    {
        value = [value count]? value[0]: nil;
    }
    if ([value isKindOfClass:[NSString class]])
    {
        return @{OSSXMLDictionaryTextKey: value};
    }
    return value;
}

@end


@implementation NSString (OSSXMLDictionary)

- (NSString *)oss_XMLEncodedString
{	
	return [[[[[self stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
               stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
              stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]
             stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"]
            stringByReplacingOccurrencesOfString:@"\'" withString:@"&apos;"];
}

@end
