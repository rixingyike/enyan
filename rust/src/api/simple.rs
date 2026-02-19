use anyhow::{Context, Result};
use candle_core::{DType, Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::encodec::{Config, Model};
use flutter_rust_bridge::frb;
use regex::Regex;
use std::io::{Cursor, Read};
use std::path::PathBuf;
use std::sync::Mutex;
use tts::Tts;

#[derive(Debug, Clone)]
pub struct VoiceInfo {
    pub id: String,
    pub name: String,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// Global TTS instance using Mutex (Thread-safe)
static TTS_INSTANCE: Mutex<Option<Tts>> = Mutex::new(None);
static SELECTED_VOICE_ID: Mutex<Option<String>> = Mutex::new(None);
static ASSETS_PATH: Mutex<Option<String>> = Mutex::new(None);

// get_tts_internal was removed — use with_tts() helper instead.

/// Helper to run TTS actions with lazy initialization and retry.
fn with_tts<F, R>(f: F) -> Option<R>
where
    F: FnOnce(&mut Tts) -> R,
{
    let mut lock = TTS_INSTANCE.lock().ok()?;
    if lock.is_none() {
        log::info!("with_tts: TTS not initialized, attempting Tts::default()...");
        // Retry up to 2 times with a small delay (helps with Android init timing)
        let mut last_err = None;
        for attempt in 0..2 {
            match Tts::default() {
                Ok(mut tts) => {
                    log::info!("Tts::default() succeeded on attempt {}", attempt + 1);
                    // Apply selected voice if any (non-Android only; Android voices managed by Java)
                    #[cfg(not(target_os = "android"))]
                    {
                        let voice_id = SELECTED_VOICE_ID.lock().ok().and_then(|l| l.clone());
                        if let Ok(voices) = tts.voices() {
                            if let Some(vid) = voice_id {
                                if let Some(v) = voices.iter().find(|v| v.id() == vid) {
                                    let _ = tts.set_voice(v);
                                }
                            } else if let Some(v) = voices.iter().find(|v| {
                                let n = v.name();
                                n.contains("zh-CN")
                                    || n.contains("Ting-Ting")
                                    || n.contains("Meijia")
                            }) {
                                let _ = tts.set_voice(v);
                            }
                        }
                    }
                    *lock = Some(tts);
                    last_err = None;
                    break;
                }
                Err(e) => {
                    log::warn!("Tts::default() failed on attempt {}: {:?}", attempt + 1, e);
                    last_err = Some(e);
                    if attempt < 1 {
                        // Brief sleep before retry
                        std::thread::sleep(std::time::Duration::from_millis(600));
                    }
                }
            }
        }
        if let Some(e) = last_err {
            log::error!("Tts::default() failed after all retries: {:?}", e);
            return None;
        }
    }
    lock.as_mut().map(f)
}

pub fn r_get_voices() -> Vec<VoiceInfo> {
    log::info!("r_get_voices called");
    with_tts(|tts| {
        let res = tts.voices();
        log::info!("tts.voices() returned: {:?}", res.as_ref().map(|v| v.len()));
        res.unwrap_or_default()
            .into_iter()
            .filter(|v| {
                let lang = v.language().to_lowercase();
                lang.contains("zh") || lang.contains("chn") || lang.contains("chi")
            })
            .map(|v| VoiceInfo {
                id: v.id(),
                name: v.name(),
            })
            .collect()
    })
    .unwrap_or_default()
}

pub fn r_set_voice(id: String) {
    log::info!("r_set_voice called with id: {}", id);
    if let Ok(mut lock) = SELECTED_VOICE_ID.lock() {
        *lock = Some(id.clone());
    }
    // On Android, voice setting is handled by Java layer via MethodChannel.
    // tts crate's Android backend returns UnsupportedFeature for voices().
    #[cfg(not(target_os = "android"))]
    with_tts(|tts| {
        if let Ok(voices) = tts.voices() {
            if let Some(v) = voices.iter().find(|v| v.id() == id) {
                let _ = tts.set_voice(v);
                log::info!("Rust TTS: Switched voice to {}", v.name());
            }
        }
    });
}

pub fn custom_init_tts() {
    log::info!("custom_init_tts called (deprecated, use custom_init_tts_with_path)");
    with_tts(|_| {});
}

pub fn custom_init_tts_with_path(shared_path: String) {
    log::info!("custom_init_tts_with_path: {}", shared_path);
    if let Ok(mut guard) = ASSETS_PATH.lock() {
        *guard = Some(shared_path);
    }
    // Still trigger the lazy init of the default backend for now
    with_tts(|_| {});
}

// 核心功能：朗读
pub fn r_speak(text: String) {
    // Safe truncation for log: use chars() to avoid UTF-8 boundary panic
    let preview: String = text.chars().take(7).collect();
    log::info!("r_speak called, text: {}...", preview);
    let processed = process_tts_text(&text);
    with_tts(|tts| {
        log::info!("Calling tts.speak()");
        match tts.speak(&processed, true) {
            Ok(_) => log::info!("tts.speak() succeeded"),
            Err(e) => log::error!("tts.speak() failed: {:?}", e),
        }
    });
}

fn process_tts_text(text: &str) -> String {
    let mut processed = text.to_string();

    // 1. Try to load dynamic lexicon from local path (Android compatibility)
    if let Ok(path_guard) = ASSETS_PATH.lock() {
        if let Some(base_path) = &*path_guard {
            let lexicon_path = std::path::Path::new(base_path).join("bible_lexicon_chs.json");
            if lexicon_path.exists() {
                if let Ok(content) = std::fs::read_to_string(&lexicon_path) {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
                        if let Some(replacements) = json.as_object() {
                            for (key, val) in replacements {
                                if let Some(to) = val.as_str() {
                                    processed = processed.replace(key, to);
                                }
                            }
                            log::debug!("Applied dynamic lexicon from {}", lexicon_path.display());
                        }
                    }
                }
            } else {
                log::warn!("Lexicon file not found at: {}", lexicon_path.display());
            }
        }
    }

    // 2. Hardcoded fallback for critical pronunciation
    if !processed.contains("[dì]") {
        processed = processed.replace("地", "地[dì]");
    }

    // 3. 匹配 "汉字[拼音]" 的格式，例如 "地[dì]"
    // Regex pattern: matches a Han character followed by [...]
    // We strictly match \p{Han} to avoid affecting other text.
    if let Ok(re) = Regex::new(r"(\p{Han})\[([^\]]+)\]") {
        // Replace with just the pinyin (group 2)
        // input: "天地[dì]..." -> output: "天dì..."
        re.replace_all(&processed, "$2").to_string()
    } else {
        processed
    }
}

// 核心功能：停止
pub fn r_stop() {
    with_tts(|tts| {
        let _ = tts.stop();
    });
}

// 核心功能：查询状态
pub fn r_is_speaking() -> bool {
    with_tts(|tts| tts.is_speaking().unwrap_or(false)).unwrap_or(false)
}

// 兼容旧测试接口
pub fn speak_chinese_test(text: String) -> String {
    r_speak(text.clone());
    format!("已发送朗读请求: {}", text)
}

// EnCodec 解码接口
pub fn r_decode_encodec(model_path: String, input_path: String) -> anyhow::Result<Vec<u8>> {
    eprintln!("🦀 [Rust] STARTING ENCODEC DECODE...");
    // Permanent choice: CPU for maximum compatibility
    let device = Device::Cpu;

    // 1. Load Model
    eprintln!("🦀 [Rust] STAGE 1: Loading model...");
    let model_path_buf = PathBuf::from(model_path);
    if !model_path_buf.exists() {
        return Err(anyhow::anyhow!(
            "Model file not found at {:?}",
            model_path_buf
        ));
    }

    let vb =
        unsafe { VarBuilder::from_mmaped_safetensors(&[model_path_buf], DType::F32, &device)? };
    let config = Config::default(); // 24kHz
    let model = Model::new(&config, vb)?;
    eprintln!("🦀 [Rust] STAGE 1: DONE");

    // 2. Read .ecdc file
    eprintln!("🦀 [Rust] STAGE 2: Reading input...");
    let mut f = std::fs::File::open(input_path)?;
    let mut buffer = Vec::new();
    f.read_to_end(&mut buffer)?;
    eprintln!("🦀 [Rust] Input size: {} bytes", buffer.len());

    let mut cursor = Cursor::new(buffer);

    // Read Header
    let mut u32_buf = [0u8; 4];
    cursor.read_exact(&mut u32_buf)?;
    let n_q = u32::from_le_bytes(u32_buf) as usize;

    cursor.read_exact(&mut u32_buf)?;
    let t = u32::from_le_bytes(u32_buf) as usize;
    eprintln!("🦀 [Rust] Header indices: n_q={}, t={}", n_q, t);

    // Read Tokens (u16)
    let total_tokens = n_q * t;
    let mut tokens = Vec::with_capacity(total_tokens);
    let mut u16_buf = [0u8; 2];

    for _ in 0..total_tokens {
        cursor.read_exact(&mut u16_buf)?;
        tokens.push(u16::from_le_bytes(u16_buf) as u32);
    }
    eprintln!("🦀 [Rust] STAGE 2: DONE (tokens count: {})", tokens.len());

    // 3. Decode
    eprintln!("🦀 [Rust] STAGE 3: Running neural inference (CPU)...");
    let tokens_tensor = Tensor::from_slice(&tokens, (1, n_q, t), &device)?;
    let pcm_tensor = model.decode(&tokens_tensor)?; // [1, 1, samples]
    let pcm_data = pcm_tensor.flatten_all()?.to_vec1::<f32>()?;
    eprintln!(
        "🦀 [Rust] STAGE 3: DONE (samples count: {})",
        pcm_data.len()
    );

    // 4. Encode to WAV (using hound)
    eprintln!("🦀 [Rust] STAGE 4: Generating WAV bytes...");
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate: 24000,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };

    let mut wav_cursor = Cursor::new(Vec::new());
    let mut writer = hound::WavWriter::new(&mut wav_cursor, spec)?;

    for sample in pcm_data {
        let amplitude = i16::MAX as f32;
        let s = (sample * amplitude).clamp(i16::MIN as f32, i16::MAX as f32) as i16;
        writer.write_sample(s)?;
    }
    writer.finalize()?;
    eprintln!("🦀 [Rust] STAGE 4: ALL DONE!");

    Ok(wav_cursor.into_inner())
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
