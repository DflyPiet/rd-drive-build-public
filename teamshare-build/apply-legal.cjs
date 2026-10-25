// Apply legal UI and branding without changing the Mirall protocol, cryptography or license.
'use strict'
const fs = require('fs')
const path = require('path')
const root = path.resolve(process.argv[2] || 'mirall-src')
function file(p) { return path.join(root, p) }
function edit(p, before, after) {
  const source = fs.readFileSync(file(p), 'utf8').replace(/\r\n/g, '\n')
  if (!source.includes(before)) throw new Error('Expected upstream source not found: ' + p + ' ' + before.slice(0,100))
  const result = source.replace(before, after)
  if (result === source) throw new Error('Patch failed: ' + p)
  fs.writeFileSync(file(p), result, 'utf8')
}
function copy(src, dest) {
  const to = file(dest)
  fs.mkdirSync(path.dirname(to), { recursive: true })
  fs.copyFileSync(path.join(__dirname, src), to)
}
copy('LegalDocuments.tsx', 'src/renderer/components/about/LegalDocuments.tsx')
const about = 'src/renderer/screens/AboutScreen.tsx'
edit(about, "import { useManaged } from '../hooks/useManaged.js'", "import { useManaged } from '../hooks/useManaged.js'\nimport LegalDocuments, { type LegalKind } from '../components/about/LegalDocuments.js'")
edit(about, "  support: 'https://mirall.app/support',\n", "")
edit(about, "  source: 'https://github.com/ok/mirall',\n", "")
edit(about, "  security: 'https://github.com/ok/mirall/security/policy',\n", "")
edit(about, "  privacy: 'https://mirall.app/privacy',\n", "")
edit(about, "  legalNotice: 'https://mirall.app/impressum',\n", "")
edit(about, "  license: 'https://github.com/ok/mirall/blob/main/LICENSE',\n", "")
edit(about, "        <LinkRow icon=\"feedback\" label={t('about.support')} desc={t('about.supportDesc')} href={LINKS.support} />\n", "")
edit(about, "        <LinkRow icon=\"code\" label={t('about.source')} desc={t('about.sourceDesc')} href={LINKS.source} />\n", "")
edit(about, "        <LinkRow icon=\"shield\" label={t('about.security')} desc={t('about.securityDesc')} href={LINKS.security} />\n", "")
const startMarker = 'function LegalSection() {'
const endMarker = '// Only while an organization manages this install'
const content = fs.readFileSync(file(about), 'utf8')
const start = content.indexOf(startMarker), end = content.indexOf(endMarker)
if (start < 0 || end < start) throw new Error('Legal section markers changed')
const legal = [
  'function LegalSection() {',
  '  const { t } = useTranslation()',
  "  const [kind, setKind] = useState<LegalKind | null>(null)",
  '  return (',
  '    <section>',
  "      <SectionHeading>{t('about.groupLegal')}</SectionHeading>",
  '      <div className={ROW_GROUP}>',
  "        <ActionRow icon=\"lock\" label={t('about.privacy')} desc={t('about.privacyDesc')} onClick={() => setKind('privacy')} />",
  "        <ActionRow icon=\"description\" label={t('about.legalNotice')} desc={t('about.legalNoticeDesc')} onClick={() => setKind('imprint')} />",
  "        <ActionRow icon=\"data_object\" label={t('about.license')} desc={t('about.licenseDesc')} onClick={() => setKind('license')} />",
  '      </div>',
  '      <LegalDocuments kind={kind} onClose={() => setKind(null)} />',
  '    </section>',
  '  )',
  '}',
  '',
  '',
].join('\n')
fs.writeFileSync(file(about), content.slice(0,start) + legal + content.slice(end), 'utf8')
edit(about, "<p className=\"text-sm text-on-surface-variant\">{build.label}</p>", "<p className=\"text-sm text-on-surface-variant\">TeamShare 2.2.0 · Mirall {build.label}</p>")
const langs=['de','en','es','fr','it']
for (const language of langs) {
  const p = 'src/renderer/locales/'+language+'/common.json'
  const dict=JSON.parse(fs.readFileSync(file(p),'utf8'))
  if (!dict.about) throw new Error('Missing translations: '+language)
  // Removed About-page actions must not leave unreferenced locale keys.
  for (const key of ['support','supportDesc','source','sourceDesc','security','securityDesc']) delete dict.about[key]
  const isDE=language==='de'
  dict.about.title = isDE ? 'Über Radio Diabolus TeamShare' : 'About Radio Diabolus TeamShare'
  dict.about.intro = isDE ? 'Version, Datenschutz und rechtliche Angaben.' : 'Version, privacy and legal information.'
  dict.about.groupProject='Radio Diabolus'
  dict.about.website=isDE?'Radio-Diabolus-Website':'Radio Diabolus website'
  dict.about.groupLegal=isDE?'Rechtliches':'Legal'
  dict.about.privacy=isDE?'Datenschutzerklärung':'Privacy notice'
  dict.about.privacyDesc=isDE?'Wie TeamShare Daten lokal und zwischen Peers verarbeitet.':'Local and peer-to-peer data handling.'
  dict.about.legalNotice=isDE?'Impressum':'Legal notice'
  dict.about.legalNoticeDesc='Radio Diabolus · www.radio-diabolus.rocks'
  dict.about.license=isDE?'Radio Diabolus: Lizenzhinweise':'Radio Diabolus: license notices'
  dict.about.licenseDesc=isDE?'GNU AGPL v3 und Urheberrechte der Originalsoftware.':'GNU AGPL v3 and original copyright notices.'
  dict.about.madeBy=isDE?'Radio-Diabolus-Anpassung auf Basis von Mirall (Oliver Kohl).':'Radio Diabolus adaptation based on Mirall (Oliver Kohl).'
  dict.about.copyright=isDE?'© {{year}} Radio Diabolus (Anpassungen). Mirall: © Zsapping Software, GNU AGPL v3.':'© {{year}} Radio Diabolus (modifications). Mirall: © Zsapping Software, GNU AGPL v3.'
  // Show the actual disabled-update state; the German text otherwise implies updater activity.
  dict.about.verdict.offBody=isDE?'Diese Ausgabe erhält keine automatischen Updates. Neue Versionen bitte nur aus der Radio-Diabolus-Veröffentlichung beziehen.':'This build does not update automatically. Install updates only from verified Radio Diabolus releases.'
  fs.writeFileSync(file(p),JSON.stringify(dict,null,2)+'\n','utf8')
}
console.log('Radio Diabolus imprint, GDPR notice and AGPL-compliant license information embedded.')
