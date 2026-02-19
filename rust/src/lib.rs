pub mod api;
mod frb_generated;

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "C" fn Java_com_yishulun_enyan_MainActivity_initRustTts(
    mut env: jni::JNIEnv,
    _this: jni::objects::JObject,
    context: jni::objects::JObject,
) -> jni::sys::jstring {
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Debug)
            .with_tag("🦀 [Rust]"),
    );
    log::info!("initRustTts called");

    // Heartbeat for library loading verification
    let heartbeat = "Rust Engine v1.0 Alive";

    // Attempt to find the Bridge class early to ensure ClassLoader is correct
    match env.find_class("rs/tts/Bridge") {
        Ok(_) => log::info!("Successfully found rs/tts/Bridge in initRustTts"),
        Err(e) => log::error!("Failed to find rs/tts/Bridge in initRustTts: {:?}", e),
    }

    use jni::JavaVM;
    let vm = env.get_java_vm().expect("Failed to get JavaVM");
    let global_context = env
        .new_global_ref(context)
        .expect("Failed to create global reference for context");
    unsafe {
        ndk_context::initialize_android_context(
            vm.get_java_vm_pointer() as *mut _,
            global_context.as_raw() as *mut _,
        );
    }

    // Pre-warm TTS instance on main thread to ensure Bridge class is found
    log::info!("Pre-warming TTS instance on main thread...");
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        crate::api::simple::custom_init_tts();
    })) {
        Ok(_) => log::info!("TTS pre-warm completed"),
        Err(e) => log::error!("TTS pre-warm panicked: {:?}", e),
    }

    // Leak the global reference so it stays valid for the lifetime of the app
    std::mem::forget(global_context);

    env.new_string(heartbeat)
        .expect("Failed to create JNI string")
        .into_raw()
}

/// JNI bridge for Bridge.nativeOnStop(String utteranceId).
/// Bridge.java wraps onStop(String, boolean) -> nativeOnStop(String)
/// because the tts crate's exported Java_rs_tts_Bridge_onStop expects
/// only (JNIEnv, JObject, JString) but UtteranceProgressListener.onStop
/// has (String, boolean) — a JNI mangled name mismatch.
#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "C" fn Java_rs_tts_Bridge_nativeOnStop(
    env: jni::JNIEnv,
    obj: jni::objects::JObject,
    utterance_id: jni::objects::JString,
) {
    log::debug!("nativeOnStop bridge called, forwarding to tts crate onStop");
    // Forward to the tts crate's exported JNI function.
    // We use raw pointers in the extern block to avoid FFI-safety issues
    // with jni crate wrapper types, then transmute back.
    extern "C" {
        #[allow(non_snake_case)]
        fn Java_rs_tts_Bridge_onStop(
            env: *mut std::ffi::c_void,
            obj: *mut std::ffi::c_void,
            utterance_id: *mut std::ffi::c_void,
        );
    }
    // The jni wrapper types are repr-transparent over raw pointers,
    // so this transmute is safe and matches the actual C ABI.
    Java_rs_tts_Bridge_onStop(
        std::mem::transmute(env),
        std::mem::transmute(obj),
        std::mem::transmute(utterance_id),
    );
}
