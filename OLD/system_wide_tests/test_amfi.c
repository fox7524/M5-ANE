#include <stdio.h>
#include <sys/sysctl.h>

int main() {
    int amfi_status = 0;
    size_t size = sizeof(amfi_status);
    
    if (sysctlbyname("security.mac.amfi.allow_any_signature", &amfi_status, &size, NULL, 0) == 0) {
        printf("AMFI Allow Any Signature: %d\n", amfi_status);
    } else {
        printf("Failed to read AMFI status.\n");
    }
    return 0;
}
