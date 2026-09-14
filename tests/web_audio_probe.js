// Loaded only by tools/serve_audio_probe.mjs, never by the shipping page.
// Observe actual Web Audio source lifetimes and levels without playing loud
// regression failures through the user's speakers. No engine internals patched.
(() => {
  const state = {starts:0,stops:0,buffers:0,allocatedMB:0,peak:0,lastSecondStarts:0,errors:[],lastBuffer:null};
  const connections = new WeakMap();
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function(destination,...args) {
    if (destination instanceof AudioDestinationNode) {
      let meter = connections.get(destination);
      if (!meter) {
        const analyser=this.context.createAnalyser();analyser.fftSize=2048;
        const mute=this.context.createGain();mute.gain.value=0;
        connect.call(analyser,mute);connect.call(mute,destination);
        meter={analyser,values:new Float32Array(2048)};connections.set(destination,meter);
        setInterval(()=>{
          analyser.getFloatTimeDomainData(meter.values);
          for(const v of meter.values)state.peak=Math.max(state.peak,Math.abs(v));
        },100);
      }
      connect.call(this,meter.analyser,...args);
      return destination;
    }
    return connect.call(this,destination,...args);
  };
  const createBuffer=BaseAudioContext.prototype.createBuffer;
  BaseAudioContext.prototype.createBuffer=function(channels,length,rate) {
    state.buffers++;state.allocatedMB+=channels*length*4/1048576;
    return createBuffer.call(this,channels,length,rate);
  };
  const start=AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start=function(...args) {
    state.starts++;
    if(this.buffer) {
      const data=this.buffer.getChannelData(0);let peak=0,sum=0;
      for(let i=0;i<data.length;i+=16){peak=Math.max(peak,Math.abs(data[i]));sum+=data[i]*data[i];}
      state.lastBuffer={seconds:this.buffer.duration,peak,rms:Math.sqrt(sum/Math.ceil(data.length/16)),rate:this.playbackRate.value};
    }
    return start.apply(this,args);
  };
  const stop=AudioBufferSourceNode.prototype.stop;
  AudioBufferSourceNode.prototype.stop=function(...args){state.stops++;return stop.apply(this,args);};
  addEventListener('error',e=>state.errors.push(e.message));
  addEventListener('unhandledrejection',e=>state.errors.push(String(e.reason)));
  let previous=0;
  addEventListener('DOMContentLoaded',()=>{
    const panel=document.createElement('pre');panel.id='audio-probe';
    panel.style='position:fixed;top:0;left:0;max-width:400px;max-height:190px;overflow:hidden;z-index:9999;pointer-events:none;background:#000b;color:#aef;font:11px monospace;padding:6px;white-space:pre-wrap';
    document.body.append(panel);
    setInterval(()=>{
      state.lastSecondStarts=state.starts-previous;previous=state.starts;
      panel.textContent='MUTED AUDIO REGRESSION PROBE\n'+JSON.stringify(state,null,2);
    },1000);
  });
})();
