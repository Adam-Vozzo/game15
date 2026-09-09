"""Original, seamless shore wash with sparse synthesized coastal bird calls."""
import numpy as np, wave, math
from pathlib import Path
root=Path(__file__).resolve().parents[1];rate=22050;duration=32;n=rate*duration;t=np.arange(n)/rate
rng=np.random.default_rng(832);f=np.fft.rfftfreq(n,1/rate)
spec=(rng.normal(size=len(f))+1j*rng.normal(size=len(f)))/np.maximum(f,65)**.65
spec[f<35]=0;spec[f>6500]*=.3
wash=np.fft.irfft(spec,n);wash/=np.max(abs(wash));wash*=.21+.13*np.sin(math.tau*t/8)+.035*np.sin(math.tau*t/4)
calls=np.zeros(n)
for onset in [4.2,4.9,15.0,24.4,25.1]:
    q=t-onset;envelope=np.where((q>0)&(q<.6),np.sin(np.clip(q/.6,0,1)*math.pi)**2,0)
    calls+=.032*envelope*np.sin(math.tau*(1780*q-480*q*q+12*np.sin(q*19)))
stereo=np.stack((wash+calls,np.roll(wash,170)+calls*.65),axis=1)
with wave.open(str(root/'assets/audio/phuket_noon.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(rate);out.writeframes((np.clip(stereo,-1,1)*30000).astype('<i2').tobytes())
print('PHUKET_AUDIO_READY')
