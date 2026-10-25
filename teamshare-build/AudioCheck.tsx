// Local-only audio audition. No network or filesystem path API is used.
import { useEffect, useRef, useState } from 'react'
import Modal from '../primitives/Modal.js'

type Props = { isOpen: boolean; onClose: () => void }
const AUDIO_FILE = /\.(mp3|wav|flac|ogg|oga|m4a|aac)$/i
function size(bytes: number): string {
  return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + ' MB' : (bytes / 1024).toFixed(0) + ' KB'
}
function clock(seconds: number): string {
  if (!Number.isFinite(seconds)) return 'unbekannt'
  return Math.floor(seconds / 60) + ':' + String(Math.floor(seconds % 60)).padStart(2, '0')
}
export default function AudioCheck({ isOpen, onClose }: Props) {
  const [files, setFiles] = useState<File[]>([])
  const [selected, setSelected] = useState(0)
  const [source, setSource] = useState<string | null>(null)
  const [duration, setDuration] = useState<number | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const player = useRef<HTMLAudioElement>(null)
  const current = files[selected]
  // Blob URLs are scoped to this renderer and revoked on every switch or dismissal.
  useEffect(() => {
    if (!isOpen || !current) {
      setSource(null)
      return
    }
    const url = URL.createObjectURL(current)
    setSource(url)
    setDuration(null)
    return () => URL.revokeObjectURL(url)
  }, [isOpen, current])
  function load(list: FileList | null) {
    if (!list) return
    const items = Array.from(list)
    const accepted = items.filter(f => AUDIO_FILE.test(f.name))
    setMessage(accepted.length < items.length ? 'Nicht unterstützte Dateitypen wurden übersprungen.' : null)
    setFiles(accepted)
    setSelected(0)
    setDuration(null)
    // A subsequent selection of identical files must still fire onChange.
  }
  return (
    <Modal isOpen={isOpen} onClose={onClose} ariaLabel="Radio Diabolus Audio-Check"
      panelClassName="glass-modal w-full max-w-2xl rounded-2xl relative p-6 max-h-[85vh] overflow-y-auto">
      <div className="space-y-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="font-headline text-2xl font-bold text-accent">Radio Diabolus Audio-Check</h2>
            <p className="text-sm text-on-surface-variant mt-2">Musik und Jingles direkt von deinem Rechner anhören. Dateien werden dafür nicht hochgeladen.</p>
          </div>
          <button type="button" onClick={onClose} className="bg-surface-control hover:bg-surface-control-hover px-3 py-2 rounded-lg focus-ring" aria-label="Audio-Check schließen">Schließen</button>
        </div>
        <label className="block space-y-2">
          <span className="text-sm font-semibold text-on-surface">Audiodateien auswählen</span>
          <input className="block w-full text-sm text-on-surface focus-ring rounded-lg p-2 bg-surface-container-highest"
            type="file" multiple accept=".mp3,.flac,.wav,.ogg,.oga,.m4a,.aac,audio/*"
            onChange={e => { load(e.currentTarget.files); e.currentTarget.value = '' }} />
        </label>
        {message && <p className="text-sm text-on-surface-variant" role="status">{message}</p>}
        {current ? (
          <div className="space-y-4 rounded-xl bg-surface-container-low p-4">
            <div>
              <p className="break-all font-semibold text-on-surface">{current.name}</p>
              <p className="text-xs text-on-surface-variant mt-1">{size(current.size)} · Laufzeit {duration == null ? 'wird ermittelt' : clock(duration)}</p>
            </div>
            <audio ref={player} key={source ?? 'empty'} src={source ?? undefined}
              controls preload="metadata" className="w-full" aria-label="Audiowiedergabe"
              onLoadedMetadata={e => setDuration(e.currentTarget.duration)}
              onError={() => setMessage('Die Datei konnte nicht wiedergegeben werden. Das Format wird möglicherweise nicht unterstützt.')}
              onEnded={() => setSelected(i => i + 1 < files.length ? i + 1 : i)} />
            <div className="flex gap-3 items-center">
              <button className="px-4 py-2 rounded-lg bg-surface-control disabled:opacity-40 focus-ring" type="button" disabled={selected <= 0} onClick={() => setSelected(i => Math.max(0, i - 1))}>Vorheriger Titel</button>
              <button className="px-4 py-2 rounded-lg bg-primary text-on-primary disabled:opacity-40 focus-ring" type="button" disabled={selected + 1 >= files.length} onClick={() => setSelected(i => Math.min(files.length - 1, i + 1))}>Nächster Titel</button>
              <span className="text-xs text-on-surface-variant">{selected + 1} / {files.length}</span>
            </div>
            <ul className="max-h-48 overflow-y-auto space-y-1" aria-label="Audio-Playlist">
              {files.map((file, i) => (
                <li key={i}><button type="button" onClick={() => setSelected(i)} aria-current={selected === i ? 'true' : undefined}
                  className="w-full text-left break-all px-3 py-2 rounded-md hover:bg-surface-container-high focus-ring text-sm">
                  {selected === i ? '▶ ' : ''}{file.name}</button></li>
              ))}
            </ul>
          </div>
        ) : <p className="text-sm text-on-surface-variant">Unterstützt: MP3, FLAC, WAV, OGG, M4A und AAC, sofern ein passender Audiocodec vorhanden ist.</p>}
      </div>
    </Modal>
  )
}
