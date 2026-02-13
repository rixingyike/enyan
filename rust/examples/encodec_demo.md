# Rust EnCodec 解码示例 (Candle)

这是使用 Rust 和 Hugging Face 的 `candle` 框架加载 EnCodec 模型并将压缩流解码为 PCM 音频的完整示例。

## 1. 依赖配置 (Cargo.toml)

```toml
[dependencies]
anyhow = "1.0"
candle-core = "0.3.3" # 请检查最新版本
candle-transformers = "0.3.3"
candle-nn = "0.3.3"
safetensors = "0.4.1"
```

## 2. Rust 代码示例 (src/main.rs 或 lib.rs)

此函数演示了如何：
1. 加载 `model.safetensors` 权重文件。
2. 构建 EnCodec 模型。
3. 将输入的编码帧 (tokens) 解码为浮点 PCM 数据 (`Vec<f32>`)。

```rust
use anyhow::Result;
use candle_core::{DType, Device, Tensor};
use candle_transformers::models::encodec::{Config, Model};
use candle_nn::VarBuilder;

/// 加载 EnCodec 模型并解码
/// 
/// - `model_path`: 指向 model.safetensors 的路径
/// - `encoded_tokens`: 压缩后的音频 token 序列 (通常由 EnCodec 编码器生成)
/// - 返回: 解码后的 PCM 音频数据 (Float32, 单声道或立体声取决于模型配置)
pub fn decode_encodec_audio(
    model_path: &std::path::Path, 
    encoded_tokens: &[u32] // 假设我们拿到的是扁平化的 token 列表
) -> Result<Vec<f32>> {
    // 1. 选择设备 (macOS 使用 Metal 性能最佳，无卡则通过 CPU)
    let device = Device::new_metal(0).unwrap_or(Device::Cpu);
    
    // 2. 加载模型权重
    let vb = unsafe { 
        VarBuilder::from_mmaped_safetensors(&[model_path], DType::F32, &device)? 
    };

    // 3. 配置模型 (这里以 24kHz 模型为例)
    // 注意：具体配置需与训练时的 config.json 一致
    let config = Config {
        normalize: false,
        ..Config::default() // 使用 24kHz 的默认配置
    };
    let model = Model::new(&config, vb)?;

    // 4. 准备输入 Tensor
    // EnCodec 的输入通常是 [Batch, NumCodebooks, SequenceLength]
    // 假设我们有一个单帧或一段连续的 tokens
    // 这里需要根据实际的编码格式将 flat tokens 重组为 Tensor 形状
    // 示例：假设 encoded_tokens 是一个 [1, K, T] 的展开数组
    let num_codebooks = 32; // EnCodec 24k 通常有 32 个码本 (或更少，取决于带宽设置)
    let seq_len = encoded_tokens.len() / num_codebooks;
    
    let tokens_tensor = Tensor::from_slice(encoded_tokens, (1, num_codebooks, seq_len), &device)?;

    // 5. 执行解码 (Forward Pass)
    // Model.forward() 接收 codes 并返回 PCM Tensor
    let pcm_tensor = model.decode(&tokens_tensor)?;

    // 6. 转换为 Vec<f32> 供 Flutter/media_kit 播放
    // 输出形状通常是 [Batch, Channels, Samples]
    // 我们将其展平为一维数组
    let pcm_data = pcm_tensor.flatten_all()?.to_vec1::<f32>()?;

    Ok(pcm_data)
}

// -------------------------------------------------------------
// 辅助函数：模拟从文件加载模型并测试
// -------------------------------------------------------------
#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_load_and_decode() -> Result<()> {
        // 假设 assets 目录下有模型文件
        let model_path = PathBuf::from("assets/encodec_model.safetensors");
        if !model_path.exists() {
            println!("Model file not found, skipping test.");
            return Ok(());
        }

        // 模拟一些 dummy tokens
        let dummy_tokens = vec![0u32; 32 * 100]; // 100 帧

        let pcm = decode_encodec_audio(&model_path, &dummy_tokens)?;
        println!("Decoded {} samples", pcm.len());
        
        Ok(())
    }
}
```

## 3. 关键说明

1.  **模型权重 (Weights)**: 你需要从 Hugging Face (如 `facebook/encodec_24khz`) 下载 `model.safetensors` 并将其放入 App 的 `assets` 目录。
2.  **输入形状**: EnCodec 的解码核心在于 `codes` Tensor。其形状必须严格匹配 `[Batch Size, n_q (码本数), T (时间步)]`。实际使用时，你需要根据录制时的带宽设置（如 1.5kbps, 3kbps, 6kbps...）来确定 `n_q` 的值。例如 3kbps 对应 `n_q=4` (对于 24kHz 模型)。
3.  **计算性能**: 在 macOS 上，`Device::new_metal(0)` 至关重要。Rust Candle 对 Metal 的支持非常好，可以实现极低延迟的解码。
