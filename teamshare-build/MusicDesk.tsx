// Local-first Radio Diabolus music promotions desk.
// Records are local IndexedDB metadata; no P2P transfer or server sync is claimed.
import { useEffect, useMemo, useState } from 'react'
import Modal from '../primitives/Modal.js'
type Status = 'Neu' | 'In Prüfung' | 'Freigegeben' | 'Erledigt'
type Track = {
  id: string; title: string; artist: string; album: string; label: string;
  releaseDate: string; status: Status; path: string; fileName: string;
  fileSize: number; notes: string; addedAt: number
}
const statuses: Status[] = ['Neu', 'In Prüfung', 'Freigegeben', 'Erledigt']
const AUDIO=/\.(mp3|flac|wav|aiff?|ogg|m4a|aac)$/i
const dbName='rd-teamshare-musicdesk-v1'
const storeName='bemusterungen'
function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve,reject)=>{
    const request=indexedDB.open(dbName,1)
    request.onupgradeneeded=()=>{
      if(!request.result.objectStoreNames.contains(storeName))request.result.createObjectStore(storeName,{keyPath:'id'})
    }
    request.onerror=()=>reject(request.error??Error('Datenbank konnte nicht geöffnet werden'))
    request.onsuccess=()=>resolve(request.result)
  })
}
async function readAll(): Promise<Track[]> {
  const db=await openDB()
  try {
    return await new Promise<Track[]>((resolve,reject)=>{
      const t=db.transaction(storeName,'readonly')
      const req=t.objectStore(storeName).getAll()
      req.onerror=()=>reject(req.error??Error('Lesen fehlgeschlagen'))
      req.onsuccess=()=>resolve(req.result as Track[])
    })
  }finally{db.close()}
}
async function storeTrack(track:Track): Promise<void> {
  const db=await openDB()
  try {
    await new Promise<void>((resolve,reject)=>{
      const tx=db.transaction(storeName,'readwrite')
      tx.objectStore(storeName).put(track)
      tx.oncomplete=()=>resolve()
      tx.onerror=()=>reject(tx.error??Error('Speichern fehlgeschlagen'))
      tx.onabort=()=>reject(tx.error??Error('Speichern abgebrochen'))
    })
  }finally{db.close()}
}
async function dropTrack(id:string): Promise<void> {
  const db=await openDB()
  try {
    await new Promise<void>((resolve,reject)=>{
      const tx=db.transaction(storeName,'readwrite')
      tx.objectStore(storeName).delete(id)
      tx.oncomplete=()=>resolve()
      tx.onerror=()=>reject(tx.error??Error('Löschen fehlgeschlagen'))
      tx.onabort=()=>reject(tx.error??Error('Löschen abgebrochen'))
    })
  }finally{db.close()}
}
function downloadText(text:string,filename:string,type:string) {
  const url=URL.createObjectURL(new Blob([text],{type}))
  const link=document.createElement('a')
  link.href=url
  link.download=filename
  link.style.display='none'
  document.body.appendChild(link)
  link.click()
  link.remove()
  window.setTimeout(()=>URL.revokeObjectURL(url),30000)
}
function csvCell(value:string|number) {
  const text=String(value)
  // Prevent Excel formula injection if the exported CSV is opened in a spreadsheet.
  const safe=/^[\s]*[=+\-@\t\r]/.test(text)?"'"+text:text
  return '"'+safe.replaceAll('"','""')+'"'
}
function exportCsv(tracks:Track[]) {
  const head=['Artist','Title','Album','Label','Release','Status','Notes','File name','Local path']
  const body=tracks.map(t=>[t.artist,t.title,t.album,t.label,t.releaseDate,t.status,t.notes,t.fileName,t.path].map(csvCell).join(';'))
  downloadText('\uFEFF'+[head.map(csvCell).join(';'),...body].join('\r\n'),'Radio-Diabolus-Bemusterungen.csv','text/csv;charset=utf-8')
}
function exportM3u(tracks:Track[]) {
  const valid=tracks.filter(t=>/^[A-Za-z]:\\/.test(t.path)||t.path.startsWith('\\\\'))
  if(valid.length===0)throw Error('Für eine RadioBOSS-Playlist sind ausgewählte lokale Dateien mit Windows-Dateipfad nötig.')
  const clean=(s:string)=>s.replaceAll(/\r|\n/g,' ').replaceAll('\0','')
  const content=['#EXTM3U',...valid.flatMap(t=>['#EXTINF:-1,'+clean((t.artist ? t.artist+' - ':'')+t.title),clean(t.path)])].join('\r\n')+'\r\n'
  downloadText('\uFEFF'+content,'Radio-Diabolus-RadioBOSS-Playlist.m3u8','audio/x-mpegurl;charset=utf-8')
}
function exportBackup(tracks:Track[]) {
  // JSON preserves all fields, unlike the reduced CSV export.
  const payload={format:'radio-diabolus-teamshare-musicdesk',schemaVersion:1,exportedAt:new Date().toISOString(),tracks}
  downloadText(JSON.stringify(payload,null,2),'Radio-Diabolus-Bemusterungen-Backup.json','application/json;charset=utf-8')
}
async function importBackup(file:File):Promise<Track[]> {
  if(file.size>8*1024*1024)throw Error('Backup ist zu groß (maximal 8 MB).')
  const data:unknown=JSON.parse(await file.text())
  if(!data||typeof data!=='object')throw Error('Ungültiges Backup.')
  const v=data as {format?:unknown;schemaVersion?:unknown;tracks?:unknown}
  if(v.format!=='radio-diabolus-teamshare-musicdesk'||v.schemaVersion!==1||!Array.isArray(v.tracks)||v.tracks.length>3000)throw Error('Unbekanntes oder beschädigtes Backup.')
  const keys=['id','title','artist','album','label','releaseDate','status','path','fileName','notes']
  const ids=new Set<string>()
  const records:Track[]=[]
  for(const item of v.tracks){
    if(!item||typeof item!=='object')throw Error('Ungültiger Datensatz.')
    const t=item as Record<string,unknown>
    if(keys.some(k=>typeof t[k]!=='string'||(t[k] as string).length>10000)||typeof t.fileSize!=='number'||!Number.isFinite(t.fileSize)||t.fileSize<0||typeof t.addedAt!=='number'||!Number.isFinite(t.addedAt)||!statuses.includes(t.status as Status))throw Error('Ungültiger Datensatz.')
    if(!(t.id as string)||ids.has(t.id as string))throw Error('Doppelte oder leere Datensatz-ID.')
    ids.add(t.id as string)
    records.push(t as Track)
  }
  return records
}
async function restoreBackup(file:File):Promise<Track[]> {
  const records=await importBackup(file)
  const existing=await readAll()
  const byId=new Map(existing.map(t=>[t.id,t]))
  for(const track of records)byId.set(track.id,track)
  if(byId.size>3000)throw Error('Maximal 3000 Datensätze möglich.')
  for(const track of records)await storeTrack(track)
  return [...byId.values()]
}
const formatBytes=(n:number)=>(n/(1024*1024)).toFixed(1)+' MB'
function stripName(name:string) {return name.replace(/\.[^.]+$/,'').replace(/[_]+/g,' ').trim()}
export default function MusicDesk({isOpen,onClose}:{isOpen:boolean;onClose:()=>void}) {
  const [all,setAll]=useState<Track[]>([])
  const [search,setSearch]=useState('')
  const [filter,setFilter]=useState<Status|'Alle'>('Alle')
  const [error,setError]=useState<string|null>(null)
  const [selected,setSelected]=useState<string|null>(null)
  const [busy,setBusy]=useState(false)
  useEffect(()=>{
    if(!isOpen)return
    let active=true
    readAll().then(t=>{if(active)setAll(t)}).catch(e=>{if(active)setError(String(e))})
    return()=>{active=false}
  },[isOpen])
  const visible=useMemo(()=>all
    .filter(t=>(filter==='Alle'||filter===t.status)&&[t.title,t.artist,t.album,t.label,t.notes,t.fileName].join(' ').toLocaleLowerCase().includes(search.toLocaleLowerCase()))
    .sort((a,b)=>b.addedAt-a.addedAt),[all,filter,search])
  const selectedTrack=all.find(t=>t.id===selected)
  function revise(track:Track,field:keyof Track,value:string){
    setAll(prev=>prev.map(t=>t.id===track.id?{...t,[field]:value}:t))
  }
  async function importFiles(files:FileList|null) {
    if(!files)return
    const supported=Array.from(files).filter(f=>AUDIO.test(f.name)).slice(0,250)
    if(!supported.length){setError('Keine unterstützten Audiodateien ausgewählt.');return}
    setBusy(true);setError(null)
    try{
      const current=await readAll()
      const known=new Set(current.map(t=>t.path+'|'+t.fileName+'|'+t.fileSize))
      let added=0
      for(const f of supported){
        if(current.length+added>=3000)throw Error('Das Limit von 3000 lokalen Datensätzen ist erreicht.')
        const path=window.bridge.getPathForFile(f)||''
        const key=path+'|'+f.name+'|'+f.size
        if(known.has(key))continue
        known.add(key)
        const name=stripName(f.name)
        const parts=name.split(' - ')
        const t:Track={id:crypto.randomUUID(),artist:parts.length>1?parts[0].trim():'',title:parts.length>1?parts.slice(1).join(' - ').trim():name,album:'',label:'',releaseDate:'',status:'Neu',path,fileName:f.name,fileSize:f.size,notes:'',addedAt:Date.now()+added}
        await storeTrack(t);current.push(t);added++
      }
      setAll(current)
      if(added===0)setError('Die ausgewählten Dateien sind bereits in der lokalen Bibliothek.')
    }catch(e){setError(e instanceof Error?e.message:'Import fehlgeschlagen');setAll(await readAll().catch(()=>[]))}
    finally{setBusy(false)}
  }
  async function save(t:Track) {try{await storeTrack(t)}catch(e){setError(String(e))}}
  async function remove(t:Track) {
    try{await dropTrack(t.id);setAll(prev=>prev.filter(x=>x.id!==t.id));setSelected(null)}
    catch(e){setError(String(e))}
  }
  function m3u() {
    try{exportM3u(visible.filter(t=>t.status==='Freigegeben'||t.status==='Erledigt'));setError(null)}
    catch(e){setError(e instanceof Error?e.message:'Export fehlgeschlagen')}
  }
  const field=(label:string,key:'title'|'artist'|'album'|'label'|'notes',multi=false)=>{
    if(!selectedTrack)return null
    return <label className="block space-y-1 text-sm text-on-surface">
      <span>{label}</span>
      {multi
        ? <textarea rows={2} value={selectedTrack[key]} onChange={e=>revise(selectedTrack,key,e.currentTarget.value)} onBlur={()=>{const latest=all.find(t=>t.id===selectedTrack.id);if(latest)save(latest).catch(e=>setError(String(e)))}} className="w-full rounded-lg bg-surface-control p-2 focus-ring"/>
        : <input value={selectedTrack[key]} onChange={e=>revise(selectedTrack,key,e.currentTarget.value)} onBlur={()=>{const latest=all.find(t=>t.id===selectedTrack.id);if(latest)save(latest).catch(e=>setError(String(e)))}} className="w-full rounded-lg bg-surface-control p-2 focus-ring" />}
    </label>
  }
  return <Modal isOpen={isOpen} onClose={onClose} ariaLabel="Radio Diabolus Musikbemusterungen"
    panelClassName="glass-modal w-full max-w-4xl rounded-2xl p-6 max-h-[86vh] overflow-y-auto">
    <div className="space-y-4 text-on-surface">
      <div className="flex items-start justify-between gap-3">
        <div><h2 className="font-headline text-2xl font-bold">Musikbemusterungen & RadioBOSS</h2>
          <p className="text-xs text-on-surface-variant mt-2">Lokale Verwaltung auf diesem Rechner. Es werden keine Metadaten automatisch mit anderen Teammitgliedern synchronisiert.</p>
        </div>
        <button type="button" onClick={onClose} className="px-4 py-2 bg-surface-control rounded-lg focus-ring">Schließen</button>
      </div>
      <div className="flex gap-3 flex-wrap">
        <label className="cursor-pointer px-4 py-2 bg-primary text-on-primary rounded-lg text-sm font-semibold">
          {busy?'Importiere…':'Musikdateien einlesen'}
          <input type="file" multiple accept="audio/*,.mp3,.flac,.wav,.aiff,.ogg,.m4a,.aac" disabled={busy} className="sr-only" onChange={e=>{importFiles(e.currentTarget.files).catch(err=>setError(String(err)));e.currentTarget.value=''}} />
        </label>
        <label className="cursor-pointer bg-surface-control px-4 py-2 rounded-lg text-sm">
          JSON-Backup importieren
          <input type="file" accept=".json,application/json" className="sr-only" disabled={busy} onChange={e=>{const file=e.currentTarget.files?.[0];e.currentTarget.value='';if(!file)return;setBusy(true);setError(null);restoreBackup(file).then(setAll).catch(err=>setError(err instanceof Error?err.message:String(err))).finally(()=>setBusy(false))}} />
        </label>
        <button type="button" onClick={()=>exportBackup(all)} className="bg-surface-control px-4 py-2 rounded-lg text-sm focus-ring">Vollständiges JSON-Backup</button>
        <button type="button" onClick={()=>exportCsv(visible)} className="bg-surface-control px-4 py-2 rounded-lg text-sm focus-ring">CSV exportieren</button>
        <button type="button" onClick={m3u} className="bg-surface-control px-4 py-2 rounded-lg text-sm focus-ring">RadioBOSS-M3U8 exportieren</button>
      </div>
      <p className="text-xs text-on-surface-variant">Der RadioBOSS-Export enthält freigegebene Dateien mit lokalem Windows-Pfad. Playlist in RadioBOSS importieren. Dateien dürfen danach nicht verschoben werden.</p>
      {error&&<p role="alert" className="rounded-lg bg-error-container p-3 text-on-error-container text-sm">{error}</p>}
      <div className="flex flex-wrap gap-3">
        <input value={search} onChange={e=>setSearch(e.currentTarget.value)} aria-label="Musik durchsuchen" placeholder="Suche Interpret, Titel, Label…" className="bg-surface-control rounded-lg p-2 flex-1 min-w-40 text-sm focus-ring"/>
        <select value={filter} onChange={e=>setFilter(e.currentTarget.value as Status|'Alle')} aria-label="Bearbeitungsstatus" className="bg-surface-control rounded-lg p-2 text-sm focus-ring">
          <option>Alle</option>{statuses.map(s=><option key={s}>{s}</option>)}
        </select>
      </div>
      <p className="text-xs text-on-surface-variant">{visible.length} von {all.length} Einträgen</p>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
        <div className="max-h-96 overflow-y-auto space-y-2">
          {visible.slice(0,250).map(t=><div key={t.id} className="rounded-lg bg-surface-container-low p-3 flex items-center gap-3">
            <button type="button" onClick={()=>setSelected(t.id)} aria-pressed={selected===t.id} className="flex-1 text-left min-w-0 focus-ring rounded">
              <p className="text-sm font-semibold truncate">{t.artist? t.artist+' · ':''}{t.title}</p>
              <p className="text-xs text-on-surface-variant truncate">{t.label||'Ohne Label'} · {formatBytes(t.fileSize)}</p>
            </button>
            <span className="text-xs text-on-surface-variant shrink-0">{t.status}</span>
          </div>)}
          {visible.length>250&&<p className="text-xs text-on-surface-variant">Die ersten 250 Treffer werden angezeigt. Nutze die Suche für weitere Einträge.</p>}
        </div>
        <div className="bg-surface-container-low rounded-xl p-4 space-y-3">
          {selectedTrack? <>
            <p className="font-semibold">Details bearbeiten</p>
            <div className="grid grid-cols-2 gap-3">
              {field('Interpret','artist')}{field('Titel','title')}{field('Album','album')}{field('Label','label')}
            </div>
            <label className="block text-sm space-y-1">Veröffentlichung
              <input type="date" value={selectedTrack.releaseDate} onChange={e=>{const next={...selectedTrack,releaseDate:e.currentTarget.value};setAll(prev=>prev.map(t=>t.id===next.id?next:t));save(next).catch(err=>setError(String(err)))}} className="block rounded-lg bg-surface-control p-2 focus-ring"/>
            </label>
            <label className="block text-sm space-y-1">Status
              <select value={selectedTrack.status} onChange={e=>{const next={...selectedTrack,status:e.currentTarget.value as Status};setAll(prev=>prev.map(t=>t.id===next.id?next:t));save(next).catch(err=>setError(String(err)))}} className="block rounded-lg bg-surface-control p-2 focus-ring">
                {statuses.map(x=><option key={x}>{x}</option>)}
              </select>
            </label>
            {field('Anmerkungen','notes',true)}
            <p className="text-xs text-on-surface-variant break-all">Lokaler Pfad: {selectedTrack.path||'Nicht verfügbar'}</p>
            <button type="button" onClick={()=>{remove(selectedTrack).catch(err=>setError(String(err)))}} className="rounded-lg bg-error-container text-on-error-container px-3 py-2 text-sm focus-ring">Aus der lokalen Liste entfernen</button>
          </>:<p className="text-sm text-on-surface-variant">Wähle links einen Musiktitel aus, um seine Angaben zu bearbeiten.</p>}
        </div>
      </div>
    </div>
  </Modal>
}
