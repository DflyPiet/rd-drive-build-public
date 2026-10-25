// Radio Diabolus TeamShare legal information. Readable offline; no network request.
import { useTranslation } from 'react-i18next'
import Modal from '../primitives/Modal.js'
import Button from '../primitives/Button.js'

export type LegalKind = 'privacy' | 'imprint' | 'license'
type Section = { title: string; text: string }
type Document = { title: string; intro: string; sections: Section[] }
const officialImprint = 'https://radio-diabolus.dk/site/about-us/'
const projectCode = 'https://github.com/DflyPiet/rd-drive-build-public/tree/build/radio-diabolus-teamshare-win'
const licenseText = 'https://www.gnu.org/licenses/agpl-3.0.html'

const de: Record<LegalKind, Document> = {
  imprint: {
    title: 'Impressum',
    intro: 'Radio Diabolus · www.radio-diabolus.rocks',
    sections: [
      { title: 'Anbieterkennzeichnung', text: 'Radio Diabolus\nwww.radio-diabolus.rocks' },
      { title: 'Vollständige Angaben', text: 'Die vollständige Anbieterkennzeichnung mit den veröffentlichten Kontakt- und Vertretungsangaben befindet sich auf der offiziellen Radio-Diabolus-Website. Der Link unten öffnet sie im Browser.' },
    ],
  },
  privacy: {
    title: 'Datenschutzerklärung für Radio Diabolus TeamShare',
    intro: 'Stand: 25. Oktober 2026. Diese Hinweise beziehen sich auf die Desktop-Anwendung Radio Diabolus TeamShare und nicht auf die Radio-Diabolus-Websites.',
    sections: [
      { title: '1. Verantwortlicher und Kontakt', text: 'Radio Diabolus · www.radio-diabolus.rocks. Die vollständigen Anbieter- und Kontaktangaben sind über das Impressum erreichbar. Datenschutzanfragen können an webmaster@radio-diabolus.eu gerichtet werden.' },
      { title: '2. Zweck der Verarbeitung', text: 'TeamShare ermöglicht den freiwilligen, verschlüsselten Dateiaustausch in privaten Gruppen zwischen Teammitgliedern. Hierzu verarbeitet die Anwendung lokale Profilangaben, kryptographische Identitäten, Raumzugehörigkeiten, ausgewählte Dateiinformationen und Transferstatus.' },
      { title: '3. Welche Daten anfallen', text: 'Lokal können Anzeigename, Profilbild, Schlüsselmaterial, Einstellungen, Freigaben, Dateinamen, Dateigrößen, Ordnerzuordnungen und Übertragungsprotokolle verarbeitet werden. Beim Verbinden können andere beteiligte Peers und für die Vernetzung genutzte Dienste technische Verbindungsdaten wie öffentliche IP-Adressen und Verbindungszeitpunkte sehen. Berechtigte Raummitglieder erhalten die zum Dateiaustausch erforderlichen Informationen.' },
      { title: '4. Art der Übertragung', text: 'Die eigentlichen Dateiinhalte werden grundsätzlich direkt zwischen berechtigten Geräten über verschlüsselte Verbindungen übertragen. Die Peer-Suche verwendet ein dezentrales Netzwerk. Je nach Netzwerkbedingungen können Vermittlungsdienste erforderlich sein. Es gibt für den regulären Dateiaustausch kein zentrales Radio-Diabolus-Dateiarchiv. Andere Mitglieder können heruntergeladene Dateien auf ihren eigenen Geräten behalten.' },
      { title: '5. Audio-Check und zusätzliche Werkzeuge', text: 'Der integrierte Audio-Check verarbeitet ausdrücklich ausgewählte lokale Dateien innerhalb der Anwendung. Für die Vorschau wird kein zusätzlicher Upload an Radio Diabolus ausgelöst. Eine lokal gestartete Qualitätsprüfung wertet nur die ausgewählte Audiodatei aus. Das Öffnen externer Websites erfolgt erst nach Auswahl eines entsprechenden Links.' },
      { title: '6. Rechtsgrundlagen', text: 'Soweit Radio Diabolus im Rahmen der Teamarbeit personenbezogene Daten verarbeitet, kommen je nach konkretem Einsatz die Durchführung vereinbarter Teamaufgaben (Art. 6 Abs. 1 Buchst. b DSGVO) und berechtigte Interessen an einem sicheren internen Dateiaustausch (Art. 6 Abs. 1 Buchst. f DSGVO) in Betracht. Sonstige Verarbeitungen bedürfen einer eigenständigen Rechtsgrundlage. Diese Einordnung ist vor dem produktiven Einsatz anhand der tatsächlichen Verantwortlichkeiten zu prüfen.' },
      { title: '7. Speicherdauer und Löschung', text: 'Lokale Profildaten und heruntergeladene Dateien bleiben grundsätzlich auf den jeweiligen Geräten, bis sie dort gelöscht werden. Eine Freigabe zu widerrufen, löscht nicht automatisch bereits heruntergeladene Kopien anderer Mitglieder. Lokale Backups sind gesondert zu löschen. Die Löschung von Netzwerkverbindungsdaten bei beteiligten Netzwerkteilnehmern oder Dienstleistern kann Radio Diabolus nicht allein steuern.' },
      { title: '8. Empfänger und Drittstaaten', text: 'Empfänger können ausdrücklich zugelassene Teammitglieder sowie technisch notwendige Netzwerkteilnehmer sein. Bei Verbindungen über das Internet kann die Kommunikation auch Netze und Systeme außerhalb der EU durchlaufen. Der Standort aller dezentralen Netzwerkteilnehmer lässt sich nicht pauschal bestimmen. Für den konkreten Einsatz sind etwaige Drittlandübermittlungen gesondert zu prüfen.' },
      { title: '9. Rechte betroffener Personen', text: 'Nach Maßgabe der DSGVO bestehen insbesondere Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit und Widerspruch. Anfragen sind über die oben genannte Kontaktadresse möglich. Außerdem besteht das Recht, sich bei einer zuständigen Datenschutzaufsichtsbehörde zu beschweren.' },
      { title: '10. Keine automatische Aktualisierung dieser Version', text: 'Diese Radio-Diabolus-Ausgabe besitzt derzeit keinen eigenen aktivierten automatischen Updatekanal. Für neue Builds und heruntergeladene Versionen kann GitHub als externer Dienst genutzt werden. Die Datenschutzhinweise von GitHub gelten bei dessen Aufruf zusätzlich.' },
      { title: '11. Datensicherheit', text: 'Die Übertragung verwendet das Verschlüsselungs- und Mitgliedschaftssystem des Mirall-Projekts. Ein bereits ausgeschiedenes Mitglied kann Daten und bestimmte Informationen behalten, für die es zuvor Zugriff hatte. Die vollständige Schlüsselrotation nach dem Ausscheiden von Mitgliedern ist noch in Entwicklung. Vertrauliche Inhalte sollten erst nach entsprechender Prüfung freigegeben werden.' },
    ],
  },
  license: {
    title: 'Lizenz und Urheberrechte',
    intro: 'Radio Diabolus TeamShare ist die für Radio Diabolus angepasste Version von Mirall.',
    sections: [
      { title: 'Radio-Diabolus-Anpassungen', text: 'Anpassung und Produktkennzeichnung: Radio Diabolus · www.radio-diabolus.rocks. Dazu gehören das eigene Design und die ergänzten Oberflächenfunktionen.' },
      { title: 'Lizenz der Anwendung', text: 'Die Anwendung basiert auf Mirall von Oliver Kohl (Zsapping Software) und steht weiterhin unter den Bedingungen der GNU Affero General Public License, Version 3 oder später (AGPL-3.0-or-later). Vorhandene Urheberrechts- und Lizenzvermerke bleiben bestehen. Die Lizenz wird durch das Radio-Diabolus-Branding nicht in eine exklusive Eigenlizenz umgewandelt.' },
      { title: 'Lizenztext und entsprechender Quellcode', text: 'Das Windows-Buildpaket enthält den Lizenztext, die Originalquellen und einen Patch mit den Radio-Diabolus-Änderungen. Der GitHub-Entwicklungszweig stellt die Anpassungsskripte bereit. Diese Angaben sind Teil der gesetzlich und lizenzrechtlich erforderlichen Hinweise.' },
    ],
  },
}
const en: Record<LegalKind, Document> = {
  imprint: {
    title: 'Legal notice',
    intro: 'Radio Diabolus · www.radio-diabolus.rocks',
    sections: [
      { title: 'Provider', text: 'Radio Diabolus\nwww.radio-diabolus.rocks' },
      { title: 'Full contact and legal details', text: 'The complete published provider identification and contact details can be found on the official Radio Diabolus website via the link below.' },
    ],
  },
  privacy: {
    title: 'Radio Diabolus TeamShare privacy notice',
    intro: '25 October 2026. This notice covers the TeamShare desktop application, not Radio Diabolus websites.',
    sections: [
      { title: 'Controller and contact', text: 'Radio Diabolus · www.radio-diabolus.rocks. Full provider details are linked below. Privacy inquiries: webmaster@radio-diabolus.eu.' },
      { title: 'Purpose and data', text: 'The application enables voluntary encrypted file sharing in private teams. It may process local display names, avatars, identities and keys, membership data, file names and sizes, settings and transfer status.' },
      { title: 'Peer-to-peer network', text: 'Files are normally exchanged between approved devices using encrypted connections. The decentralized network can expose technical connection data such as public IP addresses to participating peers and network services. Authorized members can see shared metadata and files. Copies downloaded by other members remain on their devices.' },
      { title: 'Local audio tools', text: 'Audio preview and optional analysis operate on locally selected files. No additional upload to Radio Diabolus is initiated by these tools.' },
      { title: 'Legal basis', text: 'Depending on the team relationship, processing may be based on performance of agreed team duties (GDPR Article 6(1)(b)) or legitimate interests in secure collaboration (Article 6(1)(f)). The actual legal basis must be checked for the particular deployment.' },
      { title: 'Storage and deletion', text: 'Local profiles and downloads remain on each device until deleted. Revoking access cannot erase copies already obtained by other members. Local backups must be deleted separately. External network participants may have their own retention policies.' },
      { title: 'Recipients and international transfers', text: 'Recipients may include invited team members and infrastructure required for decentralized connectivity. Internet routing or participating peers may involve locations outside the EEA. Transfer safeguards require a separate deployment-specific assessment.' },
      { title: 'Your rights', text: 'Subject to applicable law, you may request access, correction, deletion, restriction, data portability or object to processing, and lodge a complaint with a competent supervisory authority.' },
      { title: 'Updates and security', text: 'This build has no active automatic update channel. GitHub may be used to download releases; its own privacy terms then apply. TeamShare uses Mirall encryption; complete key rotation after departure is not yet implemented and previously received data cannot be withdrawn.' },
    ],
  },
  license: {
    title: 'License and attribution',
    intro: 'Radio Diabolus TeamShare is a Radio Diabolus adaptation of Mirall.',
    sections: [
      { title: 'Branding', text: 'Adaptation and product branding: Radio Diabolus · www.radio-diabolus.rocks.' },
      { title: 'Original software', text: 'Based on Mirall by Oliver Kohl (Zsapping Software), licensed under GNU Affero General Public License version 3 or later (AGPL-3.0-or-later). Copyright notices and the original license are preserved.' },
      { title: 'Corresponding source', text: 'The Windows build package includes the original source code, a patch for this adaptation and the original license text. The build scripts are available on the linked GitHub repository.' },
    ],
  },
}

export default function LegalDocuments({ kind, onClose }: { kind: LegalKind | null; onClose: () => void }) {
  const { i18n } = useTranslation()
  const isGerman = i18n.language.toLowerCase().startsWith('de')
  const doc = kind === null ? null : (isGerman ? de : en)[kind]
  return (
    <Modal isOpen={kind !== null} onClose={onClose} ariaLabel={doc?.title ?? 'Legal information'}
      panelClassName="glass-modal w-full max-w-2xl max-h-[85vh] overflow-y-auto rounded-2xl p-7">
      {doc && <div className="space-y-5 text-on-surface">
        <div className="flex items-start justify-between gap-4">
          <div><h2 className="font-headline font-bold text-xl">{doc.title}</h2>
            <p className="mt-2 text-sm text-on-surface-variant whitespace-pre-line">{doc.intro}</p></div>
          <Button variant="secondary" onClick={onClose}>{isGerman ? 'Schließen' : 'Close'}</Button>
        </div>
        <div className="space-y-4">
          {doc.sections.map(section => <section key={section.title}>
            <h3 className="font-semibold text-sm">{section.title}</h3>
            <p className="mt-1 text-sm leading-relaxed text-on-surface-variant whitespace-pre-line">{section.text}</p>
          </section>)}
        </div>
        <div className="border-t border-outline-variant pt-4 flex flex-col items-start gap-2 text-sm">
          {kind !== 'license' && <a className="text-secondary underline focus-ring rounded" target="_blank" rel="noopener noreferrer" href={officialImprint}>{isGerman ? 'Vollständiges Radio-Diabolus-Impressum' : 'Full Radio Diabolus legal notice'}</a>}
          {kind === 'license' && <>
            <a className="text-secondary underline focus-ring rounded" target="_blank" rel="noopener noreferrer" href={projectCode}>{isGerman ? 'Quellcode und Änderungen zur Lizenz' : 'Corresponding source and modifications'}</a>
            <a className="text-secondary underline focus-ring rounded" target="_blank" rel="noopener noreferrer" href={licenseText}>GNU AGPL v3</a>
          </>}
          <span className="text-xs text-on-surface-variant">Radio Diabolus · www.radio-diabolus.rocks</span>
        </div>
      </div>}
    </Modal>
  )
}
