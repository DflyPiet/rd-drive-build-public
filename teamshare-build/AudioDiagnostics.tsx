// Local, opt-in PCM sampling; not an EBU R128/LUFS measurement or broadcast certification.
import { useEffect, useRef, useState } from 'react'
type Result = {
  sampleRate: number
  channels: number
  duration: number
  peakDbfs: number
  rmsDbfs: number
  nearFullScalePercent: number
  nearSilencePercent: number
  samples: number
}
function asDb(value: number) {
  return value > 0 ? (20 * Math.log10(value)).toFixed(1) + ' dBFS' : '−∞ dBFS'
}
function analyzeAudio(buffer: AudioBuffer): Result {
  let peak = 0, squares = 0, count = 0, loud = 0, silent = 0
  const targetSamplesPerChannel = 200000
  const stride = Math.max(1, Math.ceil(buffer.length / targetSamplesPerChannel))
  for (let ch = 0; ch < buffer.numberOfChannels; ch++) {
    const samples = buffer.getChannelData(ch)
    for (let i = 0; i < samples.length; i += stride) {
      const absolute = Math.abs(samples[i])
      if (absolute > peak) peak = absolute
      squares += samples[i] * samples[i]
      if (absolute >= 0.999) loud++
      if (absolute <= 0.001) silent++
      count++
    }
  }
  return {
    sampleRate: buffer.sampleRate, channels: buffer.numberOfChannels,
    duration: buffer.duration, peakDbfs: peak, rmsDbfs: Math.sqrt(squares / Math.max(1, count)),
    nearFullScalePercent: 100 * loud / Math.max(1,count),
    nearSilencePercent: 100 * silent / Math.max(1,count), samples: count,
  }
}
export default function AudioDiagnostics({ file }: { file: File }) {
  const [busy,setBusy]=useState(false)
  const [result,setResult]=useState<Result|null>(null)
  const [error,setError]=useState<string|null>(null)
  const request = useRef(0)
  useEffect(() => {
    request.current += 1
    setResult(null)
    setError(null)
    setBusy(false)
    return () => { request.current += 1 }
  }, [file])
  async function inspect() {
    const id=++request.current
    setError(null)
    setBusy(true)
    if (file.size > 48 * 1024 * 1024) {
      setError('Für eine lokale Qualitätsanalyse bitte eine Audiodatei bis 48 MB auswählen. Größere Aufnahmen lassen sich weiterhin abspielen.')
      setBusy(false)
      return
    }
    let context: AudioContext | undefined
    try {
      context = new AudioContext()
      const raw=await file.arrayBuffer()
      const audio=await context.decodeAudioData(raw)
      const values=analyzeAudio(audio)
      if(id===request.current) setResult(values)
    } catch {
      if(id===request.current) setError('Die Datei konnte nicht decodiert werden. Die Wiedergabe kann trotzdem funktionieren.')
    } finally {
      if (context) {
        try { await context.close() }
        catch {
          if (id === request.current) setError('Die Audio-Ressourcen konnten nicht vollständig freigegeben werden.')
        }
      }
      if(id===request.current) setBusy(false)
    }
  }
  return (
    <div className="rounded-xl bg-surface-container-lowest p-4 space-y-2">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div><p className="font-semibold text-sm">Audioanalyse</p>
          <p className="text-xs text-on-surface-variant">Lokal und freiwillig, mit stichprobenartiger PCM-Messung.</p></div>
        <button type="button" disabled={busy} onClick={() => { inspect().catch(() => setError('Analyse fehlgeschlagen.')) }}
          className="bg-surface-control hover:bg-surface-control-hover text-on-surface rounded-lg px-3 py-2 text-sm focus-ring disabled:opacity-40">
          {busy ? 'Analysiere…' : 'Audio analysieren'}
        </button>
      </div>
      {error && <p role="alert" className="text-sm text-on-surface-variant">{error}</p>}
      {result && <div className="grid grid-cols-2 gap-3 text-sm" role="status">
        <div>Abtastrate: <strong>{(result.sampleRate/1000).toFixed(1)} kHz</strong></div>
        <div>Kanäle: <strong>{result.channels}</strong></div>
        <div>Sample-Peak: <strong>{asDb(result.peakDbfs)}</strong></div>
        <div>RMS: <strong>{asDb(result.rmsDbfs)}</strong></div>
        <div>Nahe Vollaussteuerung: <strong>{result.nearFullScalePercent.toFixed(2)} %</strong></div>
        <div>Nahe Stille: <strong>{result.nearSilencePercent.toFixed(2)} %</strong></div>
        <p className="col-span-2 text-xs text-on-surface-variant">Auswertung von {result.samples.toLocaleString('de-DE')} Samples aus {result.duration.toFixed(1)} s. Keine True-Peak-Messung, keine EBU-R128-Lautheit und keine verbindliche Clipping-Erkennung.</p>
      </div>}
    </div>
  )
}
