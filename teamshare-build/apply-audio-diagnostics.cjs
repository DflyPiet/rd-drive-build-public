// Feature-scoped local Audio Diagnostics; does not open remote peer files.
'use strict'
const fs=require('fs')
const path=require('path')
const root=path.resolve(process.argv[2]||'mirall-src')
const source=path.join(__dirname,'AudioDiagnostics.tsx')
const target=path.join(root,'src/renderer/components/space/AudioDiagnostics.tsx')
fs.copyFileSync(source,target)
const p=path.join(root,'src/renderer/components/space/AudioCheck.tsx')
let s=fs.readFileSync(p,'utf8')
const old="import Modal from '../primitives/Modal.js'"
const after="import Modal from '../primitives/Modal.js'\nimport AudioDiagnostics from './AudioDiagnostics.js'"
if(!s.includes(old))throw Error('AudioCheck import changed')
s=s.replace(old,after)
const marker="            <div className=\"flex gap-3 items-center\">"
if(!s.includes(marker))throw Error('AudioCheck controls changed')
s=s.replace(marker,"            <AudioDiagnostics file={current} />\n"+marker)
fs.writeFileSync(p,s,'utf8')
console.log('Audio-Qualitätsprüfung ohne neue Netzwerkberechtigungen eingebaut.')
