//
//  main.m
//  AMParser
//
//  Created by Zhou, Yuan on 1/10/14.
//  Copyright (c) 2014 Zhou, Yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XRRun.h"


@implementation NSString (TrimmingAdditions)

- (NSString *)stringByTrimmingLeadingCharactersInSet:(NSCharacterSet *)characterSet {
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];
    [self getCharacters:charBuffer];
    
    for (location; location < length; location++) {
        if (![characterSet characterIsMember:charBuffer[location]]) {
            break;
        }
    }
    
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];
    [self getCharacters:charBuffer];
    
    for (length; length > 0; length--) {
        if (![characterSet characterIsMember:charBuffer[length - 1]]) {
            break;
        }
    }
    
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

@end

int main(int argc, const char *argv[])
{
	@autoreleasepool
	{
        if (argc < 3)
        {
            printf("Please specify the trace file and the target you want to parse!\n");
            printf("Usage: [AMParser *.trace targetName]\n");
            exit(1);
        }
        NSString *target = [NSString stringWithUTF8String:argv[2]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *workihngDic = [fileManager currentDirectoryPath];
        
        NSString *inputTraceFile = [[NSString stringWithUTF8String:argv[1]] stringByExpandingTildeInPath];
        NSString *inputInstrumentDataFile = [NSString stringWithFormat:@"%@/instrument_data", inputTraceFile];
        
        //get device UDID which is used as foler name
        NSError *error;
        NSArray *UUIDfolders = [fileManager contentsOfDirectoryAtPath:inputInstrumentDataFile error:&error];
        if (error) {
            printf("No Activity Manager trace result found!\n");
            exit(1);
        }
        //there are several folders with uuid as folder name
        for (NSString *UUIDfolder in UUIDfolders) {
            NSString *runDataFolder = [NSString stringWithFormat:@"%@/%@/run_data", inputInstrumentDataFile, UUIDfolder];
            NSArray *zipFiles = [fileManager contentsOfDirectoryAtPath:runDataFolder error:&error];
            //in case there are more than 1 zip file
            for (NSString *zipFile in zipFiles) {
                if (error)
                {
                    printf("No Activity Manager trace result zip files found!\n");
                    exit(1);
                }
                // Unzip file
                NSString *resultZipFile = [NSString stringWithFormat:@"%@/%@", runDataFolder, zipFile];
                NSTask *task;
                task = [[NSTask alloc] init];
                [task setLaunchPath: @"/usr/bin/unzip"];
                
                NSArray *arguments;
                arguments = @[@"-o", @"-j", resultZipFile, @"-d", workihngDic];
                [task setArguments: arguments];
                
                NSPipe *pipe;
                pipe = [NSPipe pipe];
                [task setStandardOutput: pipe];
                
                NSFileHandle *file;
                file = [pipe fileHandleForReading];
                
                [task launch];
                
                NSData *data;
                data = [file readDataToEndOfFile];
                
                NSString *string;
                string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                
                printf ("\nunzip trace file:\n%s\n", [string UTF8String]);
                
                // Read the trace file into memory
                printf ("Read trace file into memory. Please wait.\n");
                NSString *unzippedFile = [zipFile substringToIndex:(zipFile.length-4)]; //remove ".zip"
                NSString *resultUnzippedFile = [NSString stringWithFormat:@"%@/%@",workihngDic,unzippedFile];
                NSURL *traceFile = [NSURL fileURLWithPath:[resultUnzippedFile stringByExpandingTildeInPath]];
                NSData *traceData = [NSData dataWithContentsOfURL:traceFile];
                
                // Deserialize the data and dump its content
                printf ("Deserialize the data in trace file.\n");
                
                @try {
                    XRActivityInstrumentRun *run = [NSUnarchiver unarchiveObjectWithData:traceData];
                    printf("\n%s\n", [[run parseTracefile:target] UTF8String]);
                }
                @catch (NSException *exception) {
                    printf ("This zip file doesn't have result data, skip it.\n");
                    NSLog(@"%@", exception);
                }

            }
        }
        
	}
	
    return 0;
}
