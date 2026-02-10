use std::sync::{Mutex, OnceLock};
use tts::Tts;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// Global TTS instance using OnceLock (Thread-safe, standard)
static TTS_INSTANCE: OnceLock<Mutex<Tts>> = OnceLock::new();

fn get_tts() -> &'static Mutex<Tts> {
    TTS_INSTANCE.get_or_init(|| {
        let mut tts = Tts::default().expect("无法初始化 TTS 引擎");

        // 初始化默认语音 (中文)
        if let Ok(voices) = tts.voices() {
            // Priority: zh-CN -> any zh -> Ting-Ting
            // Priority: Ting-Ting (Mandarin) -> Meijia -> zh-CN -> Generic Chinese (excluding HK/Cantonese)
            let zh_voice = voices.iter().find(|v| {
                let n = v.name();
                let id = v.id();
                // 优先匹配明确的普通话语音
                if n.contains("Ting-Ting") || n.contains("Meijia") {
                    return true;
                }
                // 匹配 zh-CN Locale
                if n.contains("zh-CN") || id.contains("zh-CN") {
                    return true;
                }
                // 匹配 Chinese 但排除粤语/香港
                if (n.contains("Chinese") || n.contains("zh"))
                    && !n.contains("HK")
                    && !n.contains("Cantonese")
                    && !n.contains("Sin-ji")
                    && !id.contains("HK")
                {
                    return true;
                }
                return false;
            });

            if let Some(v) = zh_voice {
                let _ = tts.set_voice(v);
                println!("Rust TTS Init: Set voice to {}", v.name());
            }
        }

        Mutex::new(tts)
    })
}

pub fn custom_init_tts() {
    // Force initialization
    get_tts();
}

// 核心功能：朗读
pub fn r_speak(text: String) {
    if let Ok(mut tts) = get_tts().lock() {
        let _ = tts.speak(text, true);
    }
}

// 核心功能：停止
pub fn r_stop() {
    if let Ok(mut tts) = get_tts().lock() {
        let _ = tts.stop();
    }
}

// 兼容旧测试接口
pub fn speak_chinese_test(text: String) -> String {
    r_speak(text.clone());
    format!("已发送朗读请求: {}", text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_global_tts() {
        r_speak("你好，这是 Rust 全局 TTS 测试。".to_string());
        std::thread::sleep(std::time::Duration::from_secs(3));
        r_stop();
    }
}
