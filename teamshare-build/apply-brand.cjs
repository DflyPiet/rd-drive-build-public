(function patcher() {
  const fs = require('fs');
  const path = require('path');
  const root = path.resolve(process.argv[2] || 'mirall-src');
  const BRAND = 'Radio Diabolus TeamShare';
  const loc = p => path.join(root,p);
  const read = p => fs.readFileSync(loc(p),'utf8');
  const write = (p,data) => {fs.mkdirSync(path.dirname(loc(p)),{recursive:true});fs.writeFileSync(loc(p),data);};
  const update = (p,fn) => {
    if(!fs.existsSync(loc(p)))throw Error('Upstream file missing: '+p);
    const before=read(p), after=fn(before);
    if(after===before)throw Error('Upstream changed or patch failed: '+p);
    write(p,after);
  };
  const swap = (text,a,b) => {
    if(!text.includes(a))throw Error('Missing expected upstream text: '+a.slice(0,100));
    return text.replace(a,b);
  };
  const pkg=JSON.parse(read('package.json'));
  if(pkg.name!=='mirall'||pkg.version!=='1.13.0')throw Error('Unsupported Mirall release. Expected 1.13.0');
  pkg.productName=BRAND;
  pkg.description='Verschluesselter P2P-Dateiaustausch fuer das Radio Diabolus Team. Based on Mirall, AGPL-3.0-or-later.';
  write('package.json',JSON.stringify(pkg,null,2)+'\n');
  update('forge.config.js',s=>swap(s,"appBundleId: 'com.mirall.app'","appBundleId: 'rocks.radio-diabolus.teamshare'"));
  update('src/main/window.js',s=>swap(swap(s,"const BG_DARK = '#282c34'","const BG_DARK = '#0b0b0f'"),"const BG_LIGHT = '#fbf9f5'","const BG_LIGHT = '#f0ece9'"));
  update('src/main/config-store.js',s=>swap(s,"appearance: { theme: 'system', locale: null }","appearance: { theme: 'dark', locale: null }"));
  for(const p of ['test/unit/config-store.test.js','test/unit/backup-settings.test.js']){
    const s=read(p);
    const out=s.replaceAll("t.is(store.get('appearance.theme'), 'system')","t.is(store.get('appearance.theme'), 'dark')")
      .replaceAll("t.is(onDisk.appearance.theme, 'system')","t.is(onDisk.appearance.theme, 'dark')")
      .replaceAll("t.is(snap.appearance.theme, 'system')","t.is(snap.appearance.theme, 'dark')");
    if(out!==s)write(p,out);
  }
  update('assets/theme-bootstrap.js',s=>swap(s,"? saved : 'system'","? saved : 'dark'")
    .replace("document.documentElement.classList.add('light')","document.documentElement.classList.add('dark')")
    .replace("document.documentElement.style.colorScheme = 'light'","document.documentElement.style.colorScheme = 'dark'"));
  update('assets/index.html',s=>swap(s,'<title>Mirall</title>','<title>'+BRAND+'</title><link rel="icon" href="./brand/radio-diabolus-icon.png" type="image/png">')
    .replace('Loading Mirall...','Radio Diabolus TeamShare wird geladen...')
    .replace('lang="en"','lang="de"'));
  const css = '\n/* RADIO DIABOLUS TEAMSHARE WINDOWS THEME */\n.dark {'+
    '\n--color-background:#0b0b0f;--color-surface:#111116;--color-surface-container:#1a1920;'+
    '--color-surface-container-low:#17161c;--color-surface-container-lowest:#101016;'+
    '--color-surface-container-high:#31232d;--color-surface-container-highest:#29252e;'+
    '--color-surface-control:#2b2832;--color-surface-control-hover:#44323f;'+
    '--color-on-surface:#f6f1f3;--color-on-surface-variant:#ccbdc4;'+
    '--color-on-background:#f6f1f3;--color-accent:#fff6f5;'+
    '--color-primary:#d6294b;--color-primary-hover:#ed3a5c;--color-on-primary:#ffffff;'+
    '--color-secondary:#ffa3b4;--color-secondary-container:#4a202e;'+
    '--color-on-secondary:#2b0912;--color-on-secondary-container:#ffd2db;'+
    '--color-outline:#99858e;--color-outline-variant:#423039;'+
    '--color-progress-track:#4b3741;--color-icon-tile:#50212f;--color-on-icon-tile:#ff92a5;'+
    '--color-online:#56c69e;--color-offline:#77717e;}\n'+
    '.dark body{background-image:radial-gradient(ellipse 75% 42% at 53% -21%,rgba(187,34,61,.14),transparent 77%);}\n';
  write('src/renderer/styles/tailwind.css',read('src/renderer/styles/tailwind.css')+css);
  const logo = [
    'interface LogoProps {className?:string;label?:string}',
    'export default function Logo({className="h-7 w-auto",label}:LogoProps){',
    'return <span className={"inline-flex min-w-0 shrink-0 items-center gap-2.5 align-middle "+className} role={label?"img":undefined} aria-label={label} aria-hidden={label?undefined:true}>',
    '<img src="./brand/radio-diabolus-icon.png" alt="" aria-hidden="true" draggable={false} className="block h-full w-auto shrink-0 rounded-[19%]"/>',
    '<span className="flex shrink-0 flex-col justify-center leading-none whitespace-nowrap text-left">',
    '<span className="font-headline text-[13px] tracking-[.06em] font-extrabold text-on-surface">RADIO <span className="text-[#f04454]">DIABOLUS</span></span>',
    '<span className="font-headline text-[10px] tracking-[.2em] font-bold text-on-surface-variant mt-0.5">TEAMSHARE</span></span></span>}',
  ].join('\n');
  write('src/renderer/components/primitives/Logo.tsx',logo+'\n');
  update('src/renderer/screens/OnboardingScreen.tsx',s=>swap(s,'<Logo label="Mirall" />','<Logo label="'+BRAND+'" />'));
  update('src/main/main.js',s=>swap(s,"website: 'https://mirall.app',","website: 'https://www.radio-diabolus.rocks',"));
  update('src/renderer/screens/AboutScreen.tsx',s=>swap(s,"website: 'https://mirall.app',","website: 'https://www.radio-diabolus.rocks',")
    .replace('desc="mirall.app" href={LINKS.website}','desc="radio-diabolus.rocks" href={LINKS.website}')
    .replace('label="Mirall"','label="'+BRAND+'"')
    .replace('`Mirall ${build.label}`','`Radio Diabolus TeamShare ${build.label}`'));
  for(const lang of ['de','en','es','fr','it']){
    const p='src/renderer/locales/'+lang+'/common.json';
    const dict=JSON.parse(read(p));
    const walk=obj=>{
      for(const [k,v] of Object.entries(obj)){
        if(v && typeof v==='object')walk(v);
        else if(typeof v==='string' && !['madeBy','copyright','opensInBrowser','sourceDesc'].includes(k)){
          obj[k]=v.replaceAll('Mirall',BRAND);
        }
      }
    };
    walk(dict);
    if(lang==='de'){
      dict.spaces.title='Deine';
      dict.spaces.titleEmphasis='Teamräume';
      dict.spaces.intro='Teile Sendungen, Jingles und Dateien verschlüsselt mit dem Radio Diabolus Team.';
      dict.onboarding.intro='Richte dein Profil für den Dateiaustausch im Radio Diabolus Team ein.';
    }
    write(p,JSON.stringify(dict,null,2)+'\n');
  }
  update('resources/win32/AppxManifest.xml',s=>swap(s,'Name="Mirall.Mirall"','Name="RadioDiabolus.TeamShare"')
    .replaceAll('<DisplayName>Mirall</DisplayName>','<DisplayName>'+BRAND+'</DisplayName>')
    .replace('<PublisherDisplayName>Mirall</PublisherDisplayName>','<PublisherDisplayName>Radio Diabolus</PublisherDisplayName>')
    .replace('Executable="app\\Mirall.exe"','Executable="app\\'+BRAND+'.exe"')
    .replace('BackgroundColor="#F9F7F3"','BackgroundColor="#0b0b0f"')
    .replace('DisplayName="Mirall"','DisplayName="'+BRAND+'"'));
  console.log('Branded',BRAND,'based on Mirall 1.13.0, transfer engine unchanged.');
})();
