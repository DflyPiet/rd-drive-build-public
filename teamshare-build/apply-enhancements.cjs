// Applies feature-isolated Radio Diabolus enhancements to pinned Mirall 1.13.0.
'use strict'
const fs = require('fs')
const path = require('path')
const root = path.resolve(process.argv[2] || 'mirall-src')
function change(file, from, to) {
  const dest = path.join(root, file)
  const before = fs.readFileSync(dest, 'utf8')
  if (!before.includes(from)) throw new Error('Unsupported upstream source: ' + file + ': ' + from.slice(0, 100))
  fs.writeFileSync(dest, before.replace(from, to), 'utf8')
}
function copy(file, dest) {
  const target = path.join(root, dest)
  fs.mkdirSync(path.dirname(target), { recursive: true })
  fs.copyFileSync(path.join(__dirname, file), target)
}
// Only the renderer is extended. Cryptographic code and peer protocol stay unchanged.
copy('AudioCheck.tsx', 'src/renderer/components/team/AudioCheck.tsx')
copy('TeamRoomTemplates.tsx', 'src/renderer/components/team/TeamRoomTemplates.tsx')
change('assets/index.html',
  "object-src 'none'; base-uri 'self';",
  "media-src 'self' blob:; object-src 'none'; base-uri 'self';")
change('src/renderer/screens/SpaceScreen.tsx',
  "import { useDownloadTo } from '../hooks/useDownloadTo.js'",
  "import { useDownloadTo } from '../hooks/useDownloadTo.js'\nimport AudioCheck from '../components/team/AudioCheck.js'")
change('src/renderer/screens/SpaceScreen.tsx',
  "const [dialog, setDialog] = useState<SpaceDialog | null>(null)",
  "const [dialog, setDialog] = useState<SpaceDialog | null>(null)\n  const [audioOpen, setAudioOpen] = useState(false)")
change('src/renderer/screens/SpaceScreen.tsx',
  "      <SpaceCheckingNote spaceId={spaceId} />",
  "      <div className=\"shrink-0 pb-2\"><button type=\"button\" onClick={() => setAudioOpen(true)} className=\"rounded-lg bg-surface-control px-4 py-2 text-sm text-on-surface-variant hover:bg-surface-control-hover focus-ring\">Audio-Check: lokale MP3, FLAC und Jingles anhören</button></div>\n      <AudioCheck isOpen={audioOpen} onClose={() => setAudioOpen(false)} />\n      <SpaceCheckingNote spaceId={spaceId} />")
change('src/renderer/screens/SpacesScreen.tsx',
  "import { spaceDigitAccelerator } from '../keyboard/known-commands.js'",
  "import { spaceDigitAccelerator } from '../keyboard/known-commands.js'\nimport TeamRoomTemplates from '../components/team/TeamRoomTemplates.js'")
change('src/renderer/screens/SpacesScreen.tsx',
  "const { spaces, loading } = useSpaces()",
  "const { spaces, loading, createSpace } = useSpaces()")
change('src/renderer/screens/SpacesScreen.tsx',
  "      <BackupPromptCard />",
  "      <BackupPromptCard />\n      <TeamRoomTemplates existingNames={spaces.map(s => s.name)} enabled={!loading && !createControl.held} createSpace={createSpace} onCreated={onSelectSpace} />")
console.log('Radio Diabolus TeamShare feature patch applied. No transfer protocol changes.')
