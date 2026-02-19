use candle_core::{Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::encodec::{Config, Model};
use std::fs::File;
use std::io::Write;
use std::path::Path;
use symphonia::core::audio::Signal;
use symphonia::core::codecs::DecoderOptions;
use symphonia::core::errors::Error;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;

/// 示例：将 MP3 转换为 .ecdc (EnCodec 压缩格式)
/// 运行方式: cargo run --example mp3_to_ecdc -- rust/assets/test.mp3 output.ecdc
fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        println!("Usage: cargo run --example mp3_to_ecdc -- <input_mp3> <output_ecdc>");
        return Ok(());
    }
    let input_path = &args[1];
    let output_path = &args[2];
    let model_path = "rust/assets/encodec_24khz.safetensors";

    println!("🚀 [Encoder] Loading MP3: {}", input_path);
    let pcm = decode_mp3(input_path)?;
    println!("✅ [Encoder] MP3 decoded, samples: {}", pcm.len());

    let device = Device::Cpu;

    // 1. Load Model
    println!("🚀 [Encoder] Loading Model: {}", model_path);
    // Try to find model in multiple locations (root or rust dir)
    let model_file = if Path::new(model_path).exists() {
        model_path.to_string()
    } else if Path::new("assets/encodec_24khz.safetensors").exists() {
        "assets/encodec_24khz.safetensors".to_string()
    } else {
        model_path.to_string()
    };

    let vb = unsafe {
        VarBuilder::from_mmaped_safetensors(&[model_file], candle_core::DType::F32, &device)?
    };
    let config = Config::default(); // 24kHz
    let model = Model::new(&config, vb)?;

    // 2. Encode
    println!("🚀 [Encoder] Encoding to neural codes...");

    // EnCodec requires input length to be a multiple of 320
    let mut pcm = pcm;
    let padding = (320 - (pcm.len() % 320)) % 320;
    if padding > 0 {
        pcm.resize(pcm.len() + padding, 0.0);
    }
    let samples = pcm.len();

    // Shape: [Batch, Channels, Time] -> [1, 1, T]
    let pcm_tensor = Tensor::from_vec(pcm, (1, 1, samples), &device)?;

    let codes = model.encode(&pcm_tensor)?;
    // codes shape: [1, n_q, T]

    // 🔥 OPTIMIZATION: Limit to 4 codebooks for 3kbps bandwidth
    // Original model might return 32 codebooks (24kbps)
    let codes = codes.narrow(1, 0, 4)?;

    let codes_data = codes.to_vec3::<u32>()?[0].clone(); // [n_q, T]
    let n_q = codes_data.len();
    let t = codes_data[0].len();
    println!(
        "✅ [Encoder] Encoded! Indices shape: [{}, {}] (3kbps mode)",
        n_q, t
    );

    // 3. Save to .ecdc (Header: n_q(u32), t(u32) + Body: flat u16 tokens)
    println!("🚀 [Encoder] Saving to {}", output_path);
    let mut file = File::create(output_path)?;
    file.write_all(&(n_q as u32).to_le_bytes())?;
    file.write_all(&(t as u32).to_le_bytes())?;

    for q in 0..n_q {
        for val in &codes_data[q] {
            file.write_all(&(*val as u16).to_le_bytes())?;
        }
    }

    println!("🎉 [Success] File saved: {}", output_path);
    Ok(())
}

fn decode_mp3(path: &str) -> anyhow::Result<Vec<f32>> {
    let src = File::open(path)?;
    let mss = MediaSourceStream::new(Box::new(src), Default::default());
    let mut hint = Hint::new();
    hint.with_extension("mp3");

    let probed = symphonia::default::get_probe().format(
        &hint,
        mss,
        &FormatOptions::default(),
        &MetadataOptions::default(),
    )?;
    let mut format = probed.format;
    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != symphonia::core::codecs::CODEC_TYPE_NULL)
        .ok_or(anyhow::anyhow!("no supported audio track"))?;

    let mut decoder =
        symphonia::default::get_codecs().make(&track.codec_params, &DecoderOptions::default())?;
    let track_id = track.id;

    let mut samples = Vec::new();
    while let Ok(packet) = format.next_packet() {
        if packet.track_id() != track_id {
            continue;
        }
        match decoder.decode(&packet) {
            Ok(decoded) => {
                let mut buf = decoded.make_equivalent::<f32>();
                decoded.convert(&mut buf);
                samples.extend_from_slice(buf.chan(0)); // Mono
            }
            Err(Error::IoError(_)) => break,
            Err(e) => return Err(e.into()),
        }
    }
    Ok(samples)
}
