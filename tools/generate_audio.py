import math, wave, struct, random
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets'; rate=22050
rng=random.Random(42)
def save(name,duration,fn,loop=False):
    samples=[]
    for i in range(int(rate*duration)):
        t=i/rate
        v=fn(t)*(.8 if loop else min(1,t*80)*max(0,1-t/duration)**.7)
        samples.append(struct.pack('<h',int(max(-1,min(1,v)) * 22000)))
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed')); f.writeframes(b''.join(samples))
save('engine',1,lambda t: .28*math.sin(2*math.pi*60*t)+.12*math.sin(2*math.pi*120*t)+.06*math.sin(2*math.pi*180*t),True)
save('drift',1,lambda t: .23*rng.uniform(-1,1)+.1*math.sin(2*math.pi*720*t),True)
save('boost',.65,lambda t: .3*math.sin(2*math.pi*(180*t+680*t*t))+.16*rng.uniform(-1,1))
save('collision',.22,lambda t: .6*rng.uniform(-1,1)+.25*math.sin(2*math.pi*75*t))
save('pickup',.38,lambda t: .45*math.sin(2*math.pi*(660 if t<.12 else 880 if t<.24 else 1320)*t))
save('item',.55,lambda t: .4*math.sin(2*math.pi*(180+math.sin(t*35)*90)*t))
save('ui',.1,lambda t:.35*math.sin(2*math.pi*880*t))
save('countdown',.18,lambda t:.5*math.sin(2*math.pi*600*t))
save('go',.5,lambda t:.4*math.sin(2*math.pi*1200*t))
# Original 120 BPM chip-synth loop: minor arpeggios, bass, kick, snare, hats.
chords=[[57,60,64,67],[53,57,60,64],[48,52,55,59],[55,59,62,65]]
def music(t):
    step=int(t/.125); phase=t%.125; bar=int(t/2)%4
    n=chords[bar][step%4]+12
    hz=440*2**((n-69)/12)
    lead=(math.sin(2*math.pi*hz*t)+.25*math.sin(2*math.pi*2*hz*t))*.10*math.exp(-phase*13)
    bass_hz=440*2**((chords[bar][0]-24-69)/12)
    bass=math.sin(2*math.pi*bass_hz*t)*.15
    beat=t%.5
    kick=math.sin(2*math.pi*(46*beat+4*(1-math.exp(-beat*35))))*.26*math.exp(-beat*22)
    noise=rng.uniform(-1,1)
    hat=noise*.055*math.exp(-phase*65)
    snare=noise*.13*math.exp(-beat*22) if int(t/.5)%2 else 0
    return lead+bass+kick+hat+snare
save('music',32,music,True)
for n in ['music','engine','drift']:
    p=out/(n+'.wav.import')
    if p.exists():
        text=p.read_text()
        p.write_text(text.replace('edit/loop_mode=0','edit/loop_mode=2'))
    else:
        p.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\npath=""\n[deps]\nsource_file="res://assets/'+n+'.wav"\n[params]\nedit/loop_mode=2\nedit/loop_begin=0\nedit/loop_end=-1\n')
print('Generated 10 original PCM audio assets')
