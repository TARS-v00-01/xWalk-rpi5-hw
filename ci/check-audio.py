#!/usr/bin/env python3
"""Check that the reviewed audio assets are present and have valid media headers."""
from pathlib import Path
import wave

root = Path(__file__).resolve().parents[1] / 'xWalkAudioResources'
for name in ('car-double-horn.wav', 'car-start-engine.wav'):
    with wave.open(str(root / 'sounds' / name), 'rb') as stream:
        if stream.getnchannels() < 1 or stream.getframerate() < 1 or stream.getnframes() < 1:
            raise SystemExit(f'Empty or invalid audio resource: {name}')
        if not stream.readframes(1):
            raise SystemExit(f'Missing audio samples: {name}')
mp3 = root / 'music/slow-trail-Ahjay_Stelino.mp3'
with mp3.open('rb') as stream:
    header = stream.read(3)
if not (header == b'ID3' or len(header) == 3 and header[0] == 255 and header[1] & 224 == 224):
    raise SystemExit('Invalid packaged MP3 header')
print('Validated two WAV resources and the packaged MP3 header')
