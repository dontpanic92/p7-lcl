#include "protosept_extension.h"

#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if UINTPTR_MAX == UINT64_MAX
_Static_assert(sizeof(P7CallbackValue) == 40, "P7CallbackValue size");
_Static_assert(offsetof(P7CallbackValue, int_value) == 8, "P7CallbackValue.int_value");
_Static_assert(offsetof(P7CallbackValue, float_value) == 16, "P7CallbackValue.float_value");
_Static_assert(offsetof(P7CallbackValue, bytes) == 24, "P7CallbackValue.bytes");
_Static_assert(offsetof(P7CallbackValue, length) == 32, "P7CallbackValue.length");
_Static_assert(sizeof(P7Value) == 8, "P7Value size");
_Static_assert(sizeof(P7NativeFunctionDescriptor) == 64, "descriptor size");
_Static_assert(offsetof(P7NativeFunctionDescriptor, callback) == 40, "descriptor.callback");
_Static_assert(offsetof(P7NativeFunctionDescriptor, drop_userdata) == 56, "descriptor.drop_userdata");
_Static_assert(sizeof(P7HostApi) == 72, "host API size");
_Static_assert(offsetof(P7HostApi, struct_size) == 8, "host API struct_size");
_Static_assert(offsetof(P7HostApi, invoke_rooted_callback_values) == 64,
               "host API invoke_rooted_callback_values");
_Static_assert(sizeof(P7CallApi) == 176, "call API size");
_Static_assert(offsetof(P7CallApi, struct_size) == 8, "call API struct_size");
_Static_assert(offsetof(P7CallApi, set_error_details) == 168,
               "call API set_error_details");
#endif

static P7Status register_function(
    void *runtime,
    const P7NativeFunctionDescriptor *descriptor) {
    (void)runtime;
    if (descriptor == NULL ||
        descriptor->struct_size < sizeof(P7NativeFunctionDescriptor)) {
        return P7_STATUS_INVALID_ARGUMENT;
    }
    return P7_STATUS_OK;
}

static P7Status register_foreign_type(
    void *runtime,
    const char *type_tag,
    const char *finalizer) {
    (void)runtime;
    (void)type_tag;
    (void)finalizer;
    return P7_STATUS_OK;
}

static P7Status invalidate_foreign_handle(
    void *runtime,
    const uint8_t *type_tag,
    size_t type_tag_len,
    int64_t host_handle) {
    (void)runtime;
    (void)type_tag;
    (void)type_tag_len;
    (void)host_handle;
    return P7_STATUS_OK;
}

static P7Status invoke_rooted_callback(void *runtime, uint64_t token) {
    (void)runtime;
    (void)token;
    return P7_STATUS_OK;
}

static P7Status release_rooted_callback(void *runtime, uint64_t token) {
    (void)runtime;
    (void)token;
    return P7_STATUS_OK;
}

static P7Status invoke_rooted_callback_values(
    void *runtime,
    uint64_t token,
    const P7CallbackValue *args,
    size_t arg_count,
    P7CallbackValue *output) {
    (void)runtime;
    (void)token;
    (void)args;
    (void)arg_count;
    (void)output;
    return P7_STATUS_OK;
}

static P7HostApi make_host_api(void) {
    P7HostApi api;
    memset(&api, 0, sizeof(api));
    api.abi_version = P7_NATIVE_ABI_VERSION;
    api.struct_size = sizeof(api);
    api.register_function = register_function;
    api.register_foreign_type = register_foreign_type;
    api.invalidate_foreign_handle = invalidate_foreign_handle;
    api.invoke_rooted_callback = invoke_rooted_callback;
    api.release_rooted_callback = release_rooted_callback;
    api.invoke_rooted_callback_values = invoke_rooted_callback_values;
    return api;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <extension>\n", argv[0]);
        return 2;
    }

    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }
    P7ExtensionInit initialize =
        (P7ExtensionInit)dlsym(library, P7_EXTENSION_INIT_SYMBOL);
    if (initialize == NULL) {
        fprintf(stderr, "dlsym failed: %s\n", dlerror());
        dlclose(library);
        return 1;
    }

    P7HostApi current = make_host_api();
    if (initialize(&current) != P7_STATUS_OK) {
        fprintf(stderr, "current host table was rejected\n");
        dlclose(library);
        return 1;
    }

    P7HostApi older = make_host_api();
    older.struct_size = offsetof(P7HostApi, invoke_rooted_callback_values);
    if (initialize(&older) != P7_STATUS_INVALID_ARGUMENT) {
        fprintf(stderr, "truncated host table was not rejected\n");
        dlclose(library);
        return 1;
    }

    struct {
        P7HostApi api;
        uintptr_t future_fields[4];
    } newer;
    memset(&newer, 0, sizeof(newer));
    newer.api = make_host_api();
    newer.api.struct_size = sizeof(newer);
    if (initialize(&newer.api) != P7_STATUS_OK) {
        fprintf(stderr, "extended host table was rejected\n");
        dlclose(library);
        return 1;
    }

    P7HostApi wrong_version = make_host_api();
    wrong_version.abi_version++;
    if (initialize(&wrong_version) != P7_STATUS_INVALID_ARGUMENT) {
        fprintf(stderr, "unknown ABI version was not rejected\n");
        dlclose(library);
        return 1;
    }

    dlclose(library);
    return 0;
}
