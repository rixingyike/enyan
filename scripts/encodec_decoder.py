import argparse
import torch
import torchaudio
from encodec import EncodecModel
import struct
import os
import subprocess
import ssl

# Bypass SSL check for model downloading
ssl._create_default_https_context = ssl._create_unverified_context

def main():
    parser = argparse.ArgumentParser(description='Encodec Decoder (Python Version)')
    parser.add_argument('--input', required=True, help='Input ecdc file')
    parser.add_argument('--output', default='output.wav', help='Output wav file')
    parser.add_argument('--play', action='store_true', help='Play immediately after decoding (using afplay)')
    args = parser.parse_args()

    # 1. Load Model (24kHz)
    print("Loading EnCodec model (24kHz)...")
    model = EncodecModel.encodec_model_24khz()
    
    # 2. Read ECDC file
    print(f"Reading: {args.input}")
    with open(args.input, 'rb') as f:
        # Read Header
        n_q_bytes = f.read(4)
        t_bytes = f.read(4)
        
        if not n_q_bytes or not t_bytes:
            print("Error: Invalid file header")
            return

        n_q = struct.unpack('<I', n_q_bytes)[0]
        t = struct.unpack('<I', t_bytes)[0]
        
        print(f"Header: n_q={n_q}, t={t} (Total tokens: {n_q * t})")
        
        # Read Tokens
        # We stored them flattened. Original shape was [n_q, t] (or [1, n_q, t] in batch)
        # Python script stored them via `codes.flatten().tolist()` where codes was [n_q, t]
        
        token_bytes = f.read()
        total_tokens = n_q * t
        
        # Verify size (u16 = 2 bytes)
        if len(token_bytes) != total_tokens * 2:
            print(f"Warning: Expected {total_tokens * 2} bytes of tokens, got {len(token_bytes)}")
        
        # Unpack u16
        # '<' + 'H' * total_tokens
        fmt = '<' + 'H' * total_tokens
        tokens_flat = struct.unpack(fmt, token_bytes)
        
        # Reshape to [1, n_q, t]
        # Torch expects LongTensor for indices
        tokens_tensor = torch.tensor(tokens_flat, dtype=torch.long)
        
        # Reshape using reshape logic. 
        # In encoder: codes.squeeze(0).flatten() where codes was [n_q, t]
        # So flattened is: row 0, then row 1...
        
        tokens_tensor = tokens_tensor.view(1, n_q, t)

    # 3. Decode
    print("Decoding...")
    with torch.no_grad():
        # model.decode expects [(codes, scale)] or just codes?
        # EncodecModel.decode(encoded_frames) where encoded_frames is list of (codes, scale)
        # BUT wait, let's check source code or documentation.
        # model.decode(tokens) -> Tensor [1, 1, T] 
        # model.decode expects list of encoded frames, where each frame is (codes, scale)
        # Scale can be None if unscaled (?) or we need to check how we encoded.
        # But wait, original encode returned `encoded_frames` which is [(codes, scale)].
        # We only saved codes. So scale is missing?
        # EnCodec doc says: "The second element of the tuple is the scale, which is not used if normalize is False."
        # If we didn't use normalization (default True?), scale exists.
        # But for 24kHz model, normalize is False by default?
        # Let's try passing None for scale.
        decoded_wav = model.decode([(tokens_tensor, None)])

    # 4. Save WAV
    print(f"Saving to {args.output}")
    # decoded_wav is [1, 1, T] -> [1, T]
    torchaudio.save(args.output, decoded_wav[0], model.sample_rate)

    # 5. Play
    if args.play:
        print("Playing...")
        subprocess.run(["afplay", args.output])

if __name__ == "__main__":
    main()
