"""Rebuild the 24 s mono PCM loop from the retained CC0 field recording."""
from pathlib import Path
import array
import subprocess
import sys
import wave
root = Path(__file__).resolve().parent
raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(root / 'originals/Swale.ogg'), '-ss', '3', '-t', '25', '-ar', '24000', '-ac', '1', '-f', 's16le', '-'])
samples = array.array('h', raw)
if sys.byteorder != 'little':
    samples.byteswap()
n = 24000
# End crosses into start; following sample continues the original at 1 second.
blend = [round((samples[-n+i] * (1-i/n) + samples[i] * (i/n)) * 0.5) for i in range(n)]
result = array.array('h', blend + [round(x * 0.5) for x in samples[n:-n]])
if sys.byteorder != 'little':
    result.byteswap()
with wave.open(str(root / 'swale-v1.wav'), 'wb') as out:
    out.setnchannels(1); out.setsampwidth(2); out.setframerate(24000); out.writeframes(result.tobytes())
