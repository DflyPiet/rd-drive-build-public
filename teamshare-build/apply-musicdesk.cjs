// Add an offline IndexedDB desk and M3U8/CSV exports to the existing Radio Diabolus UI.
'use strict'
const fs=require('fs')
const path=require('path')
const root=path.resolve(process.argv[2]||'mirall-src')
const desk=path.join(root,'src/renderer/components/space/MusicDesk.tsx')
fs.copyFileSync(path.join(__dirname,'MusicDesk.tsx'),desk)
const target=path.join(root,'src/renderer/screens/SpacesScreen.tsx')
let s=fs.readFileSync(target,'utf8')
function substitute(oldText,newText){
 if(!s.includes(oldText))throw Error('Music Desk upstream anchor missing: '+oldText.slice(0,95))
 s=s.replace(oldText,newText)
}
substitute("import TeamRoomTemplates from '../components/space/TeamRoomTemplates.js'",
  "import TeamRoomTemplates from '../components/space/TeamRoomTemplates.js'\nimport MusicDesk from '../components/space/MusicDesk.js'")
substitute("  const [filter, setFilter] = useState<'all' | 'favorites'>('all')",
  "  const [filter, setFilter] = useState<'all' | 'favorites'>('all')\n  const [musicDeskOpen,setMusicDeskOpen] = useState(false)")
substitute("      <BackupPromptCard />",
  "      <div className=\"pb-3\"><button type=\"button\" className=\"rounded-xl bg-surface-control text-on-surface px-5 py-3 text-sm font-semibold hover:bg-surface-control-hover focus-ring\" onClick={() => setMusicDeskOpen(true)}>Musikbemusterungen & RadioBOSS</button></div>\n      <MusicDesk isOpen={musicDeskOpen} onClose={() => setMusicDeskOpen(false)} />\n      <BackupPromptCard />")
fs.writeFileSync(target,s,'utf8')
console.log('Local music promotions desk and RadioBOSS playlist export integrated.')
