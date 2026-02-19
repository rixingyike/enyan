import argparse
import torch
import torchaudio
from encodec import EncodecModel
from encodec.utils import convert_audio
import struct
import os
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

def main():
    parser = argparse.ArgumentParser(description='Encodec Maker (Python Version)')
    parser.add_argument('--input', required=True, help='Input audio file (mp3/wav)')
    parser.add_argument('--output', required=True, help='Output ecdc file')
    parser.add_argument('--target_bandwidth', type=float, default=6.0, help='Target bandwidth in kbps (e.g. 1.5, 3.0, 6.0, 12.0, 24.0)')
    args = parser.parse_args()

    # 1. Load Model (24kHz)
    print(f"Loading EnCodec model (24kHz, target_bandwidth={args.target_bandwidth} kbps)...")
    model = EncodecModel.encodec_model_24khz()
    model.set_target_bandwidth(args.target_bandwidth)

    # 2. Load Audio
    print(f"Loading audio: {args.input}")
    # Load and resample to 24kHz
    wav, sr = torchaudio.load(args.input)
    wav = convert_audio(wav, sr, model.sample_rate, model.channels)

    # 3. Add batch dimension
    wav = wav.unsqueeze(0)

    # 4. Encode
    print("Encoding...")
    with torch.no_grad():
        encoded_frames = model.encode(wav)

    # encoded_frames is a list of (codes, scale) tuples
    # codes: [Batch, n_q, T]
    
    # Flatten all codes from all frames (though typically we just process one file as one batch/frame sequence if short enough)
    all_codes = []
    
    # We assume simple single batch processing for this demo
    codes = encoded_frames[0][0] # Tuple (codes, scale), take codes
    # codes shape: [1, n_q, T]
    
    codes = codes.squeeze(0) # [n_q, T]
    n_q, t = codes.shape
    
    print(f"Encoded shape: [{n_q}, {t}]")

    # 5. Save to custom file format
    # Format: 
    #   Magic: "ECDC" (4 bytes) - Optional, let's keep it simple as planned
    #   Header: n_q (4 bytes u32), t (4 bytes u32)
    #   Body: flattend codes (u16)
    
    with open(args.output, 'wb') as f:
        # Write dimensions
        f.write(struct.pack('<I', n_q))
        f.write(struct.pack('<I', t))
        
        # Write codes (flattened)
        # Transpose? Rust implementation expects [1, n_q, T] flattened? OR [n_q, T] flattened?
        # Candle's `flatten_all` usually goes row by row.
        # codes is [n_q, T]. Flattening it means codebook 0 first, then codebook 1...
        # Let's stick to this order.
        
        flat_codes = codes.flatten().tolist()
        
        for code in flat_codes:
            f.write(struct.pack('<H', int(code))) # u16

    print(f"Saved to {args.output}")
    file_size = os.path.getsize(args.output)
    print(f"Output size: {file_size} bytes")

if __name__ == "__main__":
    main()
