// Compatibility shim for Android 8.1 stagefright HTTPBase socket tagging.
//
// The 8.1 IMS stack (system/lib/libimsma_socketwrapper.so) imports
// android::HTTPBase::RegisterSocketUserTag / UnRegisterSocketUserTag, which
// Android 10 no longer exports. They only tag sockets for netd traffic
// accounting, so a no-op is safe.

extern "C" {

void _ZN7android8HTTPBase21RegisterSocketUserTagEijj(int fd, unsigned uid, unsigned tag) {
    (void)fd;
    (void)uid;
    (void)tag;
}

void _ZN7android8HTTPBase23UnRegisterSocketUserTagEi(int fd) {
    (void)fd;
}

}  // extern "C"
