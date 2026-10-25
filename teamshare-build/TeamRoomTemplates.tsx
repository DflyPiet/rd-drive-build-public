// Optional shortcuts. Creating a space is always an explicit user action.
import { useState } from 'react'

type Room = { name: string; icon: string; description: string }
const ROOMS: Room[] = [
  { name: 'Radio Diabolus · Sendungen', icon: 'movie', description: 'Mitschnitte und fertig produzierte Shows' },
  { name: 'Radio Diabolus · Jingles', icon: 'music_note', description: 'Station-IDs, Promos und Trenner' },
  { name: 'Radio Diabolus · Bemusterungen', icon: 'folder', description: 'Neue Musik der Labels und Bands' },
  { name: 'Radio Diabolus · Artwork', icon: 'palette', description: 'Cover, Social-Media-Motive und Grafiken' },
  { name: 'Radio Diabolus · Team', icon: 'work', description: 'Redaktionelle Unterlagen und Abstimmung' },
]
type Props = {
  existingNames: string[]
  enabled: boolean
  createSpace: (name: string, icon: string) => Promise<{ spaceId: string }>
  onCreated: (spaceId: string) => void
}
export default function TeamRoomTemplates({ existingNames, enabled, createSpace, onCreated }: Props) {
  const [expanded, setExpanded] = useState(false)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const existing = new Set(existingNames.map(n => n.trim().toLocaleLowerCase()))
  async function add(room: Room) {
    if (!enabled || busy || existing.has(room.name.toLocaleLowerCase())) return
    setBusy(room.name)
    setError(null)
    try {
      const created = await createSpace(room.name, room.icon)
      onCreated(created.spaceId)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Teamraum konnte nicht erstellt werden.')
    } finally {
      setBusy(null)
    }
  }
  return (
    <section className="my-3 rounded-xl bg-surface-container-low text-on-surface">
      <button type="button" aria-expanded={expanded} onClick={() => setExpanded(v => !v)}
        className="w-full flex justify-between items-center text-left p-4 focus-ring rounded-xl">
        <span className="font-semibold">Vorschläge für Radio-Diabolus-Teamräume</span>
        <span className="text-sm text-on-surface-variant">{expanded ? 'Schließen' : 'Anzeigen'}</span>
      </button>
      {expanded && <div className="px-4 pb-4 space-y-2">
        <p className="text-sm text-on-surface-variant">Räume werden erst durch einen Klick erstellt. Jeder Raum hat eigene Freigaben und Einladungen.</p>
        {ROOMS.map(room => {
          const present = existing.has(room.name.toLocaleLowerCase())
          return <div key={room.name} className="flex gap-3 items-center justify-between bg-surface-container-lowest p-3 rounded-lg">
            <div><p className="font-medium text-sm">{room.name}</p><p className="text-xs text-on-surface-variant">{room.description}</p></div>
            <button type="button" onClick={() => void add(room)} disabled={!enabled || !!busy || present}
              className="shrink-0 px-4 py-2 text-sm rounded-lg bg-primary text-on-primary disabled:opacity-40 focus-ring">
              {present ? 'Vorhanden' : busy === room.name ? 'Erstelle…' : 'Anlegen'}</button>
          </div>
        })}
        {error && <p role="alert" className="text-on-error-container bg-error-container rounded-lg p-3 text-sm">{error}</p>}
      </div>}
    </section>
  )
}
