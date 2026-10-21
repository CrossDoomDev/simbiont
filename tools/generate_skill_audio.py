"""Deterministically synthesize five original cast sounds; no external samples."""
from pathlib import Path
import hashlib, json, math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
NAMES = ['wave', 'spores', 'shield', 'dash', 'rupture']
DURATIONS = [.4,.7,.8,.3,.85]
records=[]
for index,(name,duration) in enumerate(zip(NAMES,DURATIONS)):
    rng=random.Random(7901+index)
    samples=[]
    noise=0.0
    phase=0.0
    for i in range(round(duration*RATE)):
        t=i/RATE
        u=t/duration
        env=min(1.0,t/.012)*min(1.0,(duration-t)/.1)*math.exp(-u*(2.0 if index!=2 else .8))
        noise=.82*noise+.18*rng.uniform(-1,1)
        frequency=[95-65*u,240+100*math.sin(u*20),330,900-750*u,140-100*u][index]
        phase+=math.tau*frequency/RATE
        if index==0:
            value=.65*math.sin(phase)+noise*1.0+.2*math.sin(phase*3.2)
        elif index==1:
            value=noise*1.1+.3*math.sin(phase+math.sin(t*87)*4)*math.sin(t*32)**2
        elif index==2:
            value=.45*math.sin(phase)+.3*math.sin(phase*1.5)+.2*math.sin(phase*2)
        elif index==3:
            value=noise*1.7+.3*math.sin(phase)
        else:
            value=.65*math.sin(phase)+noise*1.5+.25*math.sin(phase*2.7)
        samples.append(value*env)
    peak=max(abs(x) for x in samples)
    pcm=b''.join(struct.pack('<hh',round(x/peak*.48*32767),round(x/peak*.48*32767)) for x in samples)
    path=ROOT/'assets'/'audio'/('skill_'+name+'.wav')
    with wave.open(str(path),'wb') as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(pcm)
    records.append({'file':path.name,'duration':duration,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(ROOT/'assets'/'audio'/'skills_manifest.json').write_text(json.dumps({'generator':'tools/generate_skill_audio.py','rate':RATE,'original_synthesis':True,'files':records},indent=2)+'\n')
print('SKILL_AUDIO_OK: 5 original stereo cast sounds')
