#import <Foundation/Foundation.h>
#include <stdbool.h>
#include <stdint.h>

__attribute__((visibility("hidden")))
bool __isPlatformVersionAtLeast(int32_t platform, int32_t major, int32_t minor, int32_t subminor) {
    (void)platform;

    NSOperatingSystemVersion requiredVersion = {
        .majorVersion = major,
        .minorVersion = minor,
        .patchVersion = subminor,
    };
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:requiredVersion];
}
