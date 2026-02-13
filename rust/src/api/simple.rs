use anyhow::{Context, Result};
use candle_core::{DType, Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::encodec::{Config, Model};
use flutter_rust_bridge::frb;
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

fn get_tts_internal() -> Option<Tts> {
    let mut lock = TTS_INSTANCE.lock().ok()?;
    if lock.is_none() {
        match Tts::default() {
            Ok(mut tts) => {
                // 初始化默认语音 (中文)
                if let Ok(voices) = tts.voices() {
                    let zh_voice = voices.iter().find(|v| {
                        let n = v.name();
                        let id = v.id();
                        if n.contains("Ting-Ting") || n.contains("Meijia") {
                            return true;
                        }
                        if n.contains("zh-CN") || id.contains("zh-CN") {
                            return true;
                        }
                        if (n.contains("Chinese") || n.contains("zh"))
                            && !n.contains("HK")
                            && !n.contains("Cantonese")
                            && !n.contains("Sin-ji")
                            && !id.contains("HK")
                        {
                            return true;
                        }
                        false
                    });

                    if let Some(v) = zh_voice {
                        let _ = tts.set_voice(v);
                        println!("Rust TTS Init: Set voice to {}", v.name());
                    }
                }
                *lock = Some(tts);
            }
            Err(e) => {
                eprintln!("❌ Failed to initialize TTS engine: {:?}", e);
                return None;
            }
        }
    }
    // We can't easily clone Tts, but we only need it for the duration of the call
    // However, MutexGuard doesn't allow returning the inner Tts easily.
    // So we'll keep the lock inside the specific functions or use a helper.
    None
}

// Special helper to run TTS actions
fn with_tts<F, R>(f: F) -> Option<R>
where
    F: FnOnce(&mut Tts) -> R,
{
    let mut lock = TTS_INSTANCE.lock().ok()?;
    if lock.is_none() {
        if let Ok(mut tts) = Tts::default() {
            // Apply selected voice if any
            let voice_id = SELECTED_VOICE_ID.lock().ok().and_then(|l| l.clone());
            if let Ok(voices) = tts.voices() {
                if let Some(vid) = voice_id {
                    if let Some(v) = voices.iter().find(|v| v.id() == vid) {
                        let _ = tts.set_voice(v);
                    }
                } else if let Some(v) = voices.iter().find(|v| {
                    let n = v.name();
                    n.contains("zh-CN") || n.contains("Ting-Ting") || n.contains("Meijia")
                }) {
                    let _ = tts.set_voice(v);
                }
            }
            *lock = Some(tts);
        } else {
            return None;
        }
    }
    lock.as_mut().map(f)
}

pub fn r_get_voices() -> Vec<VoiceInfo> {
    with_tts(|tts| {
        tts.voices()
            .unwrap_or_default()
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
    if let Ok(mut lock) = SELECTED_VOICE_ID.lock() {
        *lock = Some(id.clone());
    }
    with_tts(|tts| {
        if let Ok(voices) = tts.voices() {
            if let Some(v) = voices.iter().find(|v| v.id() == id) {
                let _ = tts.set_voice(v);
                println!("Rust TTS: Switched voice to {}", v.name());
            }
        }
    });
}

pub fn custom_init_tts() {
    with_tts(|_| {});
}

// 核心功能：朗读
pub fn r_speak(text: String) {
    with_tts(|tts| {
        let _ = tts.speak(text, true);
    });
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
