// Hide requested navigation entries. Preserve mandatory license files and provenance.
'use strict'
const fs=require('fs')
const path=require('path')
const root=path.resolve(process.argv[2]||'mirall-src')
const full=p=>path.join(root,p)
function change(p,oldValue,newValue) {
  const s=fs.readFileSync(full(p),'utf8')
  if(!s.includes(oldValue))throw Error('Unexpected pinned Mirall source: '+p+' | '+oldValue.slice(0,80))
  fs.writeFileSync(full(p),s.replace(oldValue,newValue),'utf8')
}
const about='src/renderer/screens/AboutScreen.tsx'
change(about,"import LegalDocuments, { type LegalKind } from '../components/about/LegalDocuments.js'\n","")
let s=fs.readFileSync(full(about),'utf8')
const start=s.indexOf('function LegalSection() {')
const end=s.indexOf('// Only while an organization manages this install',start)
if(start<0||end<start)throw Error('Legal section body missing')
s=s.slice(0,start)+s.slice(end)
s=s.replace("          <LegalSection />\n","")
if(s.includes('LegalSection')) throw Error('Leftover LegalSection reference')
fs.writeFileSync(full(about),s,'utf8')
const account='src/renderer/screens/AccountScreen.tsx'
change(account,"import ActionRow, { LinkRow, ROW_GROUP, Tile } from '../components/layout/ActionRow.js'",
 "import ActionRow, { ROW_GROUP, Tile } from '../components/layout/ActionRow.js'")
change(account,"function AppGroup({ onOpenAbout, onFeedback }: Pick<AccountProps, 'onOpenAbout' | 'onFeedback'>) {",
 "function AppGroup({ onOpenAbout }: Pick<AccountProps, 'onOpenAbout'>) {")
const docs=[
 '        <LinkRow',
 '          icon="menu_book"',
 "          label={t('aboutSettings.documentation')}",
 "          desc={t('aboutSettings.documentationDesc')}",
 '          href="https://mirall.app/docs"',
 '        />',
 '        <ActionRow',
 '          icon="feedback"',
 "          label={t('aboutSettings.sendFeedback')}",
 "          desc={t('aboutSettings.sendFeedbackDesc')}",
 '          onClick={onFeedback}',
 '        />',
].join('\n')+'\n'
change(account,docs,'')
change(account," onOpenAbout, onFeedback }: AccountProps) {"," onOpenAbout }: AccountProps) {")
change(account,"<AppGroup onOpenAbout={onOpenAbout} onFeedback={onFeedback} />","<AppGroup onOpenAbout={onOpenAbout} />")
const nav='src/renderer/components/layout/TopNav.tsx'
change(nav,"import Button from '../primitives/Button.js'\n","")
change(nav,", onFeedbackClick, updateVersion, onDismissUpdate, restoreBanner }:",", updateVersion, onDismissUpdate, restoreBanner }:")
change(nav,[
 '            <Button variant="secondary" icon="feedback" onClick={onFeedbackClick}>',
 "              {t('topnav.feedback')}",
 '            </Button>',
].join('\n')+'\n','')
const menu='src/main/menu.js'
change(menu,"    { label: 'Documentation', click: handlers.openDocs },\n","")
change(menu,"    { label: 'Send Feedback…', click: handlers.sendFeedback },\n","")
change(menu,"    { type: 'separator' },\n  ]\n  if (!isMac)", "  ]\n  if (!isMac)")
const spaces='src/renderer/screens/SpacesScreen.tsx'
change(spaces,"import DocsCard from '../components/cards/DocsCard.js'\n","")
const docCards=[
 '            <DocsCard',
 '              icon="school"',
 "              title={t('spaces.emptyDocsTitle')}",
 "              body={t('spaces.emptyDocsBody')}",
 '              className="w-full max-w-md mt-8"',
 '              links={[',
 "                { target: { page: 'tutorials', anchor: 'send-your-first-files' }, label: t('docs.sendFirstFiles') },",
 "                { target: { page: 'guides', anchor: 'create-a-space' }, label: t('docs.createSpace') },",
 "                { target: { page: 'guides', anchor: 'join-a-space' }, label: t('docs.joinSpace') },",
 '              ]}',
 '            />'
].join('\n')+'\n'
change(spaces,docCards,'')
for(const lang of ['de','en','es','fr','it']){
 const p='src/renderer/locales/'+lang+'/common.json'
 const dict=JSON.parse(fs.readFileSync(full(p),'utf8'))
 for(const k of ['groupLegal','privacy','privacyDesc','legalNotice','legalNoticeDesc','license','licenseDesc'])delete dict.about[k]
 for(const k of ['documentation','documentationDesc','sendFeedback','sendFeedbackDesc'])delete dict.aboutSettings[k]
 delete dict.topnav.feedback
 for(const k of ['emptyDocsTitle','emptyDocsBody'])delete dict.spaces[k]
 for(const k of ['sendFirstFiles','createSpace','joinSpace'])delete dict.docs[k]
 fs.writeFileSync(full(p),JSON.stringify(dict,null,2)+'\n')
}
// The native Help menu intentionally omits Documentation and Send Feedback.
const testMenu='test/unit/app-menu.test.js'
change(testMenu,
  "test('Help submenu always carries the cross-platform items', (t) => {",
  "test('Help menu omits documentation and feedback in Radio Diabolus TeamShare', (t) => {")
change(testMenu,
  "t.ok(findInSubmenu(help, 'Documentation'), `${platform}: Documentation present`)",
  "t.absent(findInSubmenu(help, 'Documentation'), `${platform}: no documentation menu link`)")
change(testMenu,
  "t.ok(findInSubmenu(help, 'Send Feedback…'), `${platform}: Send Feedback present`)",
  "t.absent(findInSubmenu(help, 'Send Feedback…'), `${platform}: no feedback menu link`)")
console.log('Requested About/legal, feedback and documentation navigation removed. AGPL stays in distributed source and license files.')
