#import "DXRemoteBuild.h"
#import "../../Vendor/libarchive-headers/archive.h"
#import "../../Vendor/libarchive-headers/archive_entry.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>

static NSString *const DXRemoteServerKey = @"DXRemoteBuildServer";
static NSString *const DXRemoteSchemeKey = @"DXRemoteBuildScheme";
static NSString *const DXRemoteArchKey   = @"DXRemoteBuildArch";
static NSString *const DXRemoteInjectKey = @"DXRemoteBuildInject";

static NSString *DXTrim(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *DXValue(NSString *key, NSString *fallback, NSArray<NSString *> *allowed) {
    NSString *value = [NSUserDefaults.standardUserDefaults stringForKey:key];
    return value && [allowed containsObject:value] ? value : fallback;
}

NSString *DXRemoteBuildServer(void) {
    return DXTrim([NSUserDefaults.standardUserDefaults stringForKey:DXRemoteServerKey]);
}

void DXRemoteBuildSetServer(NSString *server) {
    NSString *value = DXTrim(server);
    if (value.length) [NSUserDefaults.standardUserDefaults setObject:value forKey:DXRemoteServerKey];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:DXRemoteServerKey];
}

NSString *DXRemoteBuildScheme(void) { return DXValue(DXRemoteSchemeKey, @"rootless", @[@"rootful", @"rootless", @"roothide"]); }
void DXRemoteBuildSetScheme(NSString *scheme) {
    if (![@[@"rootful", @"rootless", @"roothide"] containsObject:scheme]) return;
    [NSUserDefaults.standardUserDefaults setObject:scheme forKey:DXRemoteSchemeKey];
}
NSString *DXRemoteBuildArch(void) { return DXValue(DXRemoteArchKey, @"fat", @[@"fat", @"arm64", @"arm64e"]); }
void DXRemoteBuildSetArch(NSString *arch) {
    if (![@[@"fat", @"arm64", @"arm64e"] containsObject:arch]) return;
    [NSUserDefaults.standardUserDefaults setObject:arch forKey:DXRemoteArchKey];
}
NSString *DXRemoteBuildInject(void) { return DXValue(DXRemoteInjectKey, @"ipa_standalone", @[@"jailbreak", @"ipa_substrate", @"ipa_standalone"]); }
void DXRemoteBuildSetInject(NSString *inject) {
    if (![@[@"jailbreak", @"ipa_substrate", @"ipa_standalone"] containsObject:inject]) return;
    [NSUserDefaults.standardUserDefaults setObject:inject forKey:DXRemoteInjectKey];
}

static NSError *DXError(NSString *message) {
    return [NSError errorWithDomain:@"AiFlex2.RemoteBuild" code:1 userInfo:@{NSLocalizedDescriptionKey: message ?: @"远程构建失败"}];
}

// 规范化服务器地址：补 scheme、去掉末尾斜杠，保留子路径。
static NSURL *DXNormalizedBase(NSError **error) {
    NSString *text = DXRemoteBuildServer();
    if (!text.length) {
        if (error) *error = DXError(@"请先在「设置 → 构建 → 远程构建」填写打包服务器地址");
        return nil;
    }
    if ([text rangeOfString:@"://"].location == NSNotFound) text = [@"https://" stringByAppendingString:text];
    NSURLComponents *components = [NSURLComponents componentsWithString:text];
    NSString *scheme = components.scheme.lowercaseString;
    if (!components.host.length || !([scheme isEqual:@"http"] || [scheme isEqual:@"https"])) {
        if (error) *error = DXError(@"服务器地址无效，请填写形如 https://your-domain.com 的地址");
        return nil;
    }
    NSString *path = components.path ?: @"";
    while (path.length > 1 && [path hasSuffix:@"/"]) path = [path substringToIndex:path.length - 1];
    components.path = [path isEqual:@"/"] ? @"" : path;
    components.query = nil;
    components.fragment = nil;
    return components.URL;
}

BOOL DXRemoteBuildConfigured(void) {
    return DXNormalizedBase(NULL) != nil;
}

static NSURLSession *DXSession(void) {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 600;
        config.timeoutIntervalForResource = 900;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

static NSString *DXBodyText(NSData *data) {
    if (!data.length) return @"";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
        ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: @"";
}

static NSError *DXHTTPFailure(NSData *data, NSHTTPURLResponse *response, NSError *error) {
    if (error) return error;
    NSInteger status = response.statusCode;
    if (status >= 200 && status < 300) return nil;
    if (status == 403) return DXError(@"服务器拒绝了请求（403）：请确认地址是该打包站首页，且没有启用额外访问限制");
    NSString *body = DXBodyText(data);
    if (body.length > 200) body = [body substringToIndex:200];
    return DXError([NSString stringWithFormat:@"服务器返回 HTTP %ld%@", (long)status, body.length ? [@": " stringByAppendingString:body] : @""]);
}

static NSData *DXMultipartBody(NSDictionary<NSString *, NSString *> *fields,
                               NSDictionary<NSString *, NSData *> *files,
                               NSString *boundary) {
    NSMutableData *body = [NSMutableData data];
    for (NSString *name in fields) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", boundary, name, fields[name]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    for (NSString *name in files) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@.zip\"\r\nContent-Type: application/zip\r\n\r\n", boundary, name, name] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:files[name]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    return body;
}

static NSURLSessionDataTask *DXPost(NSString *base,
                                    NSDictionary<NSString *, NSString *> *fields,
                                    NSDictionary<NSString *, NSData *> *files,
                                    void (^completion)(NSData *data, NSHTTPURLResponse *response, NSError *error)) {
    NSURL *endpoint = [NSURL URLWithString:[base stringByAppendingString:@"/api.php"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    [request setValue:[base stringByAppendingString:@"/"] forHTTPHeaderField:@"Referer"];
    [request setValue:@"AiFlex2" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    if (files.count) {
        NSString *boundary = [@"AiFlex2-" stringByAppendingString:NSUUID.UUID.UUIDString];
        [request setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = DXMultipartBody(fields, files, boundary);
    } else {
        NSMutableArray<NSString *> *pairs = [NSMutableArray array];
        NSMutableCharacterSet *allowed = [NSCharacterSet.alphanumericCharacterSet mutableCopy];
        [allowed addCharactersInString:@"-._~"];
        for (NSString *key in fields) {
            NSString *escaped = [fields[key] stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, escaped]];
        }
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [[pairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    }
    NSURLSessionDataTask *task = [DXSession() dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        completion(data, [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil, error);
    }];
    [task resume];
    return task;
}

static NSData *DXPostSync(NSString *base,
                          NSDictionary<NSString *, NSString *> *fields,
                          NSDictionary<NSString *, NSData *> *files,
                          NSError **error,
                          void (^registerTask)(NSURLSessionDataTask *task)) {
    __block NSData *result = nil;
    __block NSError *failure = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = DXPost(base, fields, files, ^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
        failure = DXHTTPFailure(data, response, requestError);
        if (!failure) result = data;
        dispatch_semaphore_signal(semaphore);
    });
    if (registerTask) registerTask(task);
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(620 * NSEC_PER_SEC))) != 0) {
        failure = DXError(@"等待服务器响应超时，请检查网络或服务器状态");
    }
    if (error) *error = failure;
    return result;
}

static NSData *DXDownloadSync(NSURL *url, NSError **error, void (^registerTask)(NSURLSessionDataTask *task)) {
    __block NSData *result = nil;
    __block NSError *failure = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"AiFlex2" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [DXSession() dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
        failure = DXHTTPFailure(data, [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil, requestError);
        if (!failure && !data.length) failure = DXError(@"服务器返回了空产物");
        if (!failure) result = data;
        dispatch_semaphore_signal(semaphore);
    }];
    if (registerTask) registerTask(task);
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_SEC))) != 0) {
        failure = DXError(@"下载产物超时，请稍后重试");
    }
    if (error) *error = failure;
    return result;
}

static NSDictionary *DXProjectConfig(NSString *root) {
    NSData *data = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"MobileCompiler.json"]];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *DXIdentifier(NSString *text) {
    NSMutableString *out = [NSMutableString new];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar c = [text characterAtIndex:index];
        BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
        [out appendFormat:@"%C", ok ? c : (unichar)'_'];
    }
    if (!out.length) out = [NSMutableString stringWithString:@"Tweak"];
    unichar first = [out characterAtIndex:0];
    if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z'))) [out insertString:@"T" atIndex:0];
    return out;
}

static BOOL DXSkipName(NSString *name) {
    static NSSet *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [NSSet setWithArray:@[@".git", @"build", @"dist", @".theos", @"packages", @".StudioTrash", @"node_modules", @".specs", @"DerivedData", @".DS_Store"]];
    });
    if ([names containsObject:name]) return YES;
    NSString *extension = name.pathExtension.lowercaseString;
    return [@[@"deb", @"dylib", @"o", @"a", @"zip"] containsObject:extension];
}

static NSArray<NSString *> *DXScanSources(NSString *root) {
    NSMutableArray<NSString *> *found = [NSMutableArray array];
    NSMutableArray<NSString *> *pending = [NSMutableArray arrayWithObject:@""];
    while (pending.count && found.count < 200) {
        NSString *relative = pending.firstObject;
        [pending removeObjectAtIndex:0];
        NSString *directory = relative.length ? [root stringByAppendingPathComponent:relative] : root;
        for (NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
            if (DXSkipName(name) || [name hasPrefix:@"."]) continue;
            NSString *child = relative.length ? [relative stringByAppendingPathComponent:name] : name;
            BOOL isDirectory = NO;
            [NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:child] isDirectory:&isDirectory];
            if (isDirectory) {
                if ([child pathComponents].count < 3) [pending addObject:child];
                continue;
            }
            NSString *extension = name.pathExtension.lowercaseString;
            if ([@[@"xm", @"x", @"m", @"mm", @"cpp", @"c"] containsObject:extension]) [found addObject:child];
        }
    }
    return found;
}

static NSString *DXMakefile(NSString *root, NSDictionary *config) {
    NSString *existing = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"Makefile"] encoding:NSUTF8StringEncoding error:nil];
    if (existing.length) return existing;

    NSString *product = DXIdentifier([config[@"productName"] isKindOfClass:NSString.class] ? config[@"productName"] : root.lastPathComponent);
    NSArray *configured = [config[@"sources"] isKindOfClass:NSArray.class] ? config[@"sources"] : nil;
    NSArray<NSString *> *sources = configured.count ? configured : DXScanSources(root);

    BOOL logos = NO;
    for (NSString *source in sources) {
        NSString *extension = [source pathExtension].lowercaseString;
        if ([extension isEqual:@"xm"] || [extension isEqual:@"x"]) logos = YES;
    }
    NSNumber *package = [config[@"package"] isKindOfClass:NSNumber.class] ? config[@"package"] : nil;
    BOOL tweak = logos || !package || package.boolValue;

    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%@ = %@\n", tweak ? @"TWEAK_NAME" : @"LIBRARY_NAME", product];
    if (!tweak) [text appendFormat:@"# TWEAK_NAME = %@  (供打包脚本识别产物名)\n", product];
    if (sources.count) [text appendFormat:@"%@_FILES = %@\n", product, [sources componentsJoinedByString:@" "]];
    NSArray *frameworks = [config[@"frameworks"] isKindOfClass:NSArray.class] ? config[@"frameworks"] : @[@"Foundation", @"UIKit"];
    [text appendFormat:@"%@_FRAMEWORKS = %@\n", product, [frameworks componentsJoinedByString:@" "]];
    [text appendFormat:@"%@_CFLAGS = -fobjc-arc\n", product];
    [text appendString:@"include $(THEOS)/makefiles/common.mk\n"];
    [text appendFormat:@"include $(THEOS_MAKE_PATH)/%@.mk\n", tweak ? @"tweak" : @"library"];
    return text;
}

static NSString *DXControl(NSString *root, NSDictionary *config) {
    NSString *existing = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"control"] encoding:NSUTF8StringEncoding error:nil];
    if (existing.length) return existing;
    NSString *product = DXIdentifier([config[@"productName"] isKindOfClass:NSString.class] ? config[@"productName"] : root.lastPathComponent);
    NSString *name = [config[@"name"] isKindOfClass:NSString.class] ? config[@"name"] : root.lastPathComponent;
    return [NSString stringWithFormat:@"Package: com.aiflex2.%@\nName: %@\nVersion: 1.0.0\nArchitecture: iphoneos-arm64\nDescription: Built with AiFlex2 remote build\nMaintainer: AiFlex2\nAuthor: AiFlex2\nSection: Tweaks\n", product.lowercaseString, name];
}

static NSString *DXFilter(NSString *root, NSDictionary *config) {
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:nil];
    for (NSString *name in entries) {
        if (![name.pathExtension.lowercaseString isEqual:@"plist"] || [name isEqual:@"Info.plist"]) continue;
        NSString *text = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:name] encoding:NSUTF8StringEncoding error:nil];
        if ([text rangeOfString:@"Filter"].location != NSNotFound) return text;
    }
    NSString *bundle = [config[@"bundleID"] isKindOfClass:NSString.class] ? config[@"bundleID"] : @"com.apple.springboard";
    return [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict><key>Filter</key><dict><key>Bundles</key><array><string>%@</string></array></dict></dict></plist>\n", bundle];
}

static NSString *DXTweakSource(NSString *root) {
    NSString *text = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"Tweak.xm"] encoding:NSUTF8StringEncoding error:nil];
    if (text.length > 1048576) text = [text substringToIndex:1048576];
    return text ?: @"";
}

#pragma mark - ZIP

static BOOL DXZipAppend(struct archive *writer, NSString *root, NSString *relative, NSUInteger *entries,
                        unsigned long long *bytes, CFAbsoluteTime started, NSError **error) {
    NSString *path = relative.length ? [root stringByAppendingPathComponent:relative] : root;
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if (!attributes) {
        if (error) *error = DXError([NSString stringWithFormat:@"无法读取工程文件：%@", relative.length ? relative : root.lastPathComponent]);
        return NO;
    }
    BOOL isDirectory = [attributes[NSFileType] isEqual:NSFileTypeDirectory];
    if (!isDirectory && ![attributes[NSFileType] isEqual:NSFileTypeRegular]) {
        if (error) *error = DXError(@"工程目录含符号链接或特殊文件，请移除后重试");
        return NO;
    }
    if (++(*entries) > 3000) {
        if (error) *error = DXError(@"工程文件超过 3000 个，请精简后再试");
        return NO;
    }
    if (CFAbsoluteTimeGetCurrent() - started > 120) {
        if (error) *error = DXError(@"打包工程超时，请精简工程后重试");
        return NO;
    }
    unsigned long long size = isDirectory ? 0 : [attributes[NSFileSize] unsignedLongLongValue];
    if (size > 50ULL * 1024 * 1024 - *bytes) {
        if (error) *error = DXError(@"工程超过 50MB 上传限制，请移除构建产物或大文件");
        return NO;
    }
    *bytes += size;

    struct archive_entry *entry = archive_entry_new();
    NSString *entryName = isDirectory && relative.length ? [relative stringByAppendingString:@"/"] : relative;
    archive_entry_set_pathname(entry, entryName.UTF8String);
    archive_entry_set_filetype(entry, isDirectory ? AE_IFDIR : AE_IFREG);
    archive_entry_set_perm(entry, isDirectory ? 0755 : 0644);
    archive_entry_set_size(entry, isDirectory ? 0 : (la_int64_t)size);
    BOOL ok = archive_write_header(writer, entry) == ARCHIVE_OK;
    archive_entry_free(entry);
    if (!ok) {
        if (error) *error = DXError(@"无法写入工程 ZIP，请检查可用存储空间");
        return NO;
    }
    if (isDirectory) {
        for (NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
            if (DXSkipName(name)) continue;
            NSString *child = relative.length ? [relative stringByAppendingPathComponent:name] : name;
            if (!DXZipAppend(writer, root, child, entries, bytes, started, error)) return NO;
        }
        return YES;
    }
    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0) {
        if (error) *error = DXError([NSString stringWithFormat:@"无法读取文件：%@", relative]);
        return NO;
    }
    uint8_t buffer[65536];
    unsigned long long remaining = size;
    while (remaining > 0) {
        ssize_t count = read(fd, buffer, (size_t)MIN((unsigned long long)sizeof(buffer), remaining));
        if (count <= 0 || archive_write_data(writer, buffer, (size_t)count) != count) {
            close(fd);
            if (error) *error = DXError([NSString stringWithFormat:@"读取或压缩失败：%@", relative]);
            return NO;
        }
        remaining -= (unsigned long long)count;
    }
    close(fd);
    return YES;
}

// 返回 ZIP 路径；调用方负责删除其父目录。
static NSURL *DXZipProject(NSString *root, NSError **error) {
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[@"DXRemoteBuild-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:error]) return nil;
    NSString *name = DXIdentifier(root.lastPathComponent);
    NSURL *zip = [directory URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"zip"]];
    struct archive *writer = archive_write_new();
    archive_write_set_format_zip(writer);
    archive_write_add_filter_none(writer);
    BOOL ok = archive_write_open_filename(writer, zip.fileSystemRepresentation) == ARCHIVE_OK;
    NSUInteger entries = 0;
    unsigned long long bytes = 0;
    if (ok) ok = DXZipAppend(writer, root, @"", &entries, &bytes, CFAbsoluteTimeGetCurrent(), error);
    else if (error) *error = DXError(@"无法创建工程 ZIP");
    if (archive_write_close(writer) != ARCHIVE_OK && ok) {
        if (error) *error = DXError(@"无法完成工程 ZIP，请检查存储空间");
        ok = NO;
    }
    archive_write_free(writer);
    if (!ok) {
        [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
        return nil;
    }
    return zip;
}

#pragma mark - 响应解析

static void DXSplitBuildResponse(NSData *data, NSString **log, NSString **html) {
    NSString *text = DXBodyText(data);
    NSRange marker = [text rangeOfString:@"|<div class='alert" options:NSBackwardsSearch];
    if (marker.location == NSNotFound) marker = [text rangeOfString:@"|<div" options:NSBackwardsSearch];
    if (marker.location == NSNotFound) marker = [text rangeOfString:@"|" options:NSBackwardsSearch];
    if (marker.location == NSNotFound) {
        if (log) *log = text;
        if (html) *html = @"";
        return;
    }
    if (log) *log = [text substringToIndex:marker.location];
    if (html) *html = [text substringFromIndex:NSMaxRange(marker)];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *DXArtifactLinks(NSString *html) {
    NSString *source = html ?: @"";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"deb_files/([^\"'<>\\s]+)" options:0 error:nil];
    NSMutableArray *links = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    [expression enumerateMatchesInString:source options:0 range:NSMakeRange(0, source.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.numberOfRanges < 2) return;
        NSString *encoded = [source substringWithRange:[result rangeAtIndex:1]];
        NSString *name = [encoded stringByRemovingPercentEncoding] ?: encoded;
        if (!name.length || [seen containsObject:name]) return;
        [seen addObject:name];
        [links addObject:@{@"name": name, @"path": [@"/deb_files/" stringByAppendingString:encoded]}];
    }];
    return links;
}

#pragma mark - 构建任务

@interface DXRemoteBuildJob ()
@property(nonatomic, copy) NSString *root;
@property(nonatomic, copy) void (^progress)(NSString *line);
@property(nonatomic, copy) void (^completion)(BOOL success, NSArray<NSString *> *artifacts, NSString *summary);
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, weak) NSURLSessionDataTask *task;
@property(nonatomic, assign) BOOL cancelled;
@property(nonatomic, assign) BOOL finished;
- (void)execute;
- (void)emit:(NSString *)line;
- (void)finish:(BOOL)success artifacts:(NSArray<NSString *> *)artifacts summary:(NSString *)summary;
- (BOOL)stopped:(NSError **)error;
@end

@implementation DXRemoteBuildJob

+ (instancetype)runProject:(NSString *)root
                  progress:(void (^)(NSString *line))progress
                completion:(void (^)(BOOL success, NSArray<NSString *> *localArtifacts, NSString *summary))completion {
    DXRemoteBuildJob *job = [DXRemoteBuildJob new];
    job.root = root;
    job.progress = progress;
    job.completion = completion;
    job.queue = dispatch_queue_create("com.hoko2.aiflex2.remotebuild", DISPATCH_QUEUE_SERIAL);
    dispatch_async(job.queue, ^{ [job execute]; });
    return job;
}

- (void)cancel {
    self.cancelled = YES;
    [self.task cancel];
}

- (void)emit:(NSString *)line {
    void (^progress)(NSString *) = self.progress;
    if (!progress) return;
    dispatch_async(dispatch_get_main_queue(), ^{ progress(line); });
}

- (void)finish:(BOOL)success artifacts:(NSArray<NSString *> *)artifacts summary:(NSString *)summary {
    if (self.finished) return;
    self.finished = YES;
    void (^completion)(BOOL, NSArray *, NSString *) = self.completion;
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{ completion(success, artifacts ?: @[], summary ?: @""); });
}

- (BOOL)stopped:(NSError **)error {
    if (!self.cancelled) return NO;
    if (error) *error = DXError(@"已取消");
    return YES;
}

- (void)execute {
    NSError *error = nil;
    NSString *root = self.root;
    if (![NSFileManager.defaultManager fileExistsAtPath:root isDirectory:NULL]) {
        [self finish:NO artifacts:@[] summary:@"工程目录不存在或已被移动"];
        return;
    }
    NSURL *baseURL = DXNormalizedBase(&error);
    if (!baseURL) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }
    NSString *base = baseURL.absoluteString;
    NSDictionary *config = DXProjectConfig(root);

    if ([self stopped:&error]) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }
    [self emit:@"正在打包工程…"];
    NSURL *zip = DXZipProject(root, &error);
    if (!zip) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }
    NSData *zipData = [NSData dataWithContentsOfURL:zip options:0 error:&error];
    [NSFileManager.defaultManager removeItemAtURL:zip.URLByDeletingLastPathComponent error:nil];
    if (!zipData.length) { [self finish:NO artifacts:@[] summary:error.localizedDescription ?: @"读取工程 ZIP 失败"]; return; }
    if ([self stopped:&error]) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }

    [self emit:[NSString stringWithFormat:@"工程已打包（%.1f MB），正在上传…", zipData.length / 1048576.0]];
    NSData *upload = DXPostSync(base, @{@"action": @"upload_project"}, @{@"project_zip": zipData}, &error, ^(NSURLSessionDataTask *task) { self.task = task; });
    if (!upload) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }

    id uploadJSON = [NSJSONSerialization JSONObjectWithData:upload options:0 error:nil];
    NSString *projectName = [uploadJSON isKindOfClass:NSDictionary.class] ? uploadJSON[@"project_name"] : nil;
    if (![projectName isKindOfClass:NSString.class] || !projectName.length) {
        NSString *message = [uploadJSON isKindOfClass:NSDictionary.class] ? uploadJSON[@"message"] : nil;
        [self finish:NO artifacts:@[] summary:[NSString stringWithFormat:@"上传失败：%@", message ?: @"服务器未返回项目名"]];
        return;
    }
    if ([self stopped:&error]) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }

    [self emit:[NSString stringWithFormat:@"上传完成（%@），服务器开始编译…", projectName]];
    BOOL dylibTarget = [config[@"package"] isKindOfClass:NSNumber.class] && ![config[@"package"] boolValue];
    NSString *target = dylibTarget ? @"dylib" : @"deb";
    NSDictionary *fields = @{
        @"action": @"build",
        @"mode": @"select",
        @"project_name": projectName,
        @"makefile": DXMakefile(root, config),
        @"control": DXControl(root, config),
        @"filter_plist": DXFilter(root, config),
        @"tweak_xm": DXTweakSource(root),
        @"target": target,
        @"inject_mode": DXRemoteBuildInject(),
        @"arch_mode": DXRemoteBuildArch(),
        @"package_scheme": DXRemoteBuildScheme(),
    };
    NSData *response = DXPostSync(base, fields, nil, &error, ^(NSURLSessionDataTask *task) { self.task = task; });

    // 编译成功才清理服务器上的临时工程，避免 temp_build 堆积。
    if (response && !self.cancelled) {
        DXPostSync(base, @{@"action": @"delete_project", @"project_name": projectName}, nil, nil, nil);
    }
    if ([self stopped:&error]) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }
    if (!response) { [self finish:NO artifacts:@[] summary:error.localizedDescription]; return; }

    NSString *log = nil, *html = nil;
    DXSplitBuildResponse(response, &log, &html);
    if (log.length) [self emit:log.length > 60000 ? [log substringFromIndex:log.length - 60000] : log];
    NSArray<NSDictionary *> *links = DXArtifactLinks(html);
    if (!links.count) {
        NSString *tail = log.length > 4000 ? [log substringFromIndex:log.length - 4000] : log;
        [self finish:NO artifacts:@[] summary:[NSString stringWithFormat:@"编译未产出文件。\n\n%@", tail]];
        return;
    }

    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *product = DXIdentifier([config[@"productName"] isKindOfClass:NSString.class] ? config[@"productName"] : root.lastPathComponent);
    NSString *folder = [[documents stringByAppendingPathComponent:@"RemoteBuilds"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", product, [formatter stringFromDate:NSDate.date]]];

    NSMutableArray<NSString *> *artifacts = [NSMutableArray array];
    for (NSDictionary *link in links) {
        if ([self stopped:&error]) break;
        NSString *name = [link[@"name"] lastPathComponent];
        NSString *path = [folder stringByAppendingPathComponent:name];
        [self emit:[NSString stringWithFormat:@"正在下载 %@…", name]];
        NSURL *url = [NSURL URLWithString:link[@"path"] relativeToURL:baseURL].absoluteURL;
        NSData *data = DXDownloadSync(url, &error, ^(NSURLSessionDataTask *task) { self.task = task; });
        if (!data) {
            [self finish:NO artifacts:artifacts summary:[NSString stringWithFormat:@"下载 %@ 失败：%@", name, error.localizedDescription]];
            return;
        }
        if (![NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error] ||
            ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
            [self finish:NO artifacts:artifacts summary:[NSString stringWithFormat:@"保存 %@ 失败：%@", name, error.localizedDescription ?: @"无法写入 Documents"]];
            return;
        }
        [artifacts addObject:path];
    }
    if ([self stopped:&error]) { [self finish:NO artifacts:artifacts summary:error.localizedDescription]; return; }

    [self emit:[NSString stringWithFormat:@"完成，已下载 %lu 个产物到「产物」页", (unsigned long)artifacts.count]];
    [self finish:YES artifacts:artifacts summary:[NSString stringWithFormat:@"远程编译成功，共 %lu 个产物", (unsigned long)artifacts.count]];
}

@end

#pragma mark - 连通性

void DXRemoteBuildProbe(void (^completion)(BOOL ok, NSString *message)) {
    NSError *error = nil;
    NSURL *baseURL = DXNormalizedBase(&error);
    void (^deliver)(BOOL, NSString *) = ^(BOOL ok, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(ok, message ?: @"");
        });
    };
    if (!baseURL) { deliver(NO, error.localizedDescription); return; }
    NSString *base = baseURL.absoluteString;
    NSData *data = DXPostSync(base, @{@"action": @"caps"}, nil, &error, nil);
    if (!data) { deliver(NO, [NSString stringWithFormat:@"连接失败：%@", error.localizedDescription]); return; }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass:NSDictionary.class] && [json[@"success"] boolValue]) {
        deliver(YES, [NSString stringWithFormat:@"连接正常\n%@", base]);
    } else {
        NSString *message = [json isKindOfClass:NSDictionary.class] ? json[@"message"] : nil;
        deliver(NO, [NSString stringWithFormat:@"服务器响应异常：%@", message ?: DXBodyText(data)]);
    }
}
