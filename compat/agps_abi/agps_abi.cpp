// Compatibility shim for the 8.1 AGPS daemon.
//
// BoringSSL dropped SSLv3_client_method. Previously this tree rewrote the
// daemon to the vendor's OpenSSL 1.0 copies (libssl-ss / libcrypto-ss), but
// those lack SSL_is_init_finished, so linking just moved to a different
// missing symbol. Keep the platform BoringSSL for all real SSL calls and
// provide only SSLv3_client_method, backed by BoringSSL's TLS_client_method.

extern "C" const void* TLS_client_method();

extern "C" const void* SSLv3_client_method() {
    return TLS_client_method();
}
