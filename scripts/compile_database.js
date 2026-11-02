/**
 * compile_database.js
 * Ingests, normalizes, and compiles MSRTC timetable data into a clean, pre-indexed SQLite database.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Master dictionary of English -> Marathi place names
const stationMarathiMapPath = path.join(__dirname, 'station_marathi_map.json');
const STATION_MARATHI_MAP = fs.existsSync(stationMarathiMapPath)
  ? JSON.parse(fs.readFileSync(stationMarathiMapPath, 'utf8'))
  : {};

const MARATHI_NAMES = {
  ...STATION_MARATHI_MAP,
  'Ahmednagar': 'अहिल्यानगर',
  'Ahilyanagar': 'अहिल्यानगर',
  'Ajara': 'आजरा',
  'Akkalkot': 'अक्कलकोट',
  'Akluj': 'अकलूज',
  'Akola': 'अकोला',
  'Akot': 'आकोट',
  'Alibag': 'अलिबाग',
  'Amalner': 'अमळनेर',
  'Amravati': 'अमरावती',
  'Ashti': 'आष्टी',
  'Aurangabad': 'छत्रपती संभाजीनगर',
  'Chhatrapati Sambhajinagar': 'छत्रपती संभाजीनगर',
  'Badnera': 'बडनेरा',
  'Ballarpur': 'बल्लारपूर',
  'Baramati': 'बारामती',
  'Barshi': 'बार्शी',
  'Beed': 'बीड',
  'Belgaon': 'बेळगाव',
  'Belgaum': 'बेळगाव',
  'Bhadravati': 'भद्रावती',
  'Bhandara': 'भंडारा',
  'Bhor': 'भोर',
  'Bhusawal': 'भुसावळ',
  'Bhiwandi': 'भिवंडी',
  'Boisar': 'बोईसर',
  'Borivali': 'बोरिवली',
  'Buldhana': 'बुलढाणा',
  'Chandrapur': 'चंद्रपूर',
  'Chandur Bazar': 'चांदूर बाजार',
  'Chandur Railway': 'चांदूर रेल्वे',
  'Chikhli': 'चिखली',
  'Chimur': 'चिमूर',
  'Chiplun': 'चिपळूण',
  'Dadar': 'दादर',
  'Dapoli': 'दापोली',
  'Darwha': 'दारव्हा',
  'Deoli': 'देवळी',
  'Devgad': 'देवगड',
  'Devrukh': 'देवरूख',
  'Dhamangaon Railway': 'धामणगाव रेल्वे',
  'Dharni': 'धारणी',
  'Dhule': 'धुळे',
  'Digras': 'दिग्रस',
  'Gadchiroli': 'गडचिरोली',
  'Gadhinglaj': 'गडहिंग्लज',
  'Ganpatipule': 'गणपतीपुळे',
  'Ghuggus': 'घुग्गुस',
  'Gondia': 'गोंदिया',
  'Guhagar': 'गुहागर',
  'Hinganghat': 'हिंगणघाट',
  'Hingoli': 'हिंगोली',
  'Ichalkaranji': 'इचलकरंजी',
  'Islampur': 'इस्लामपूर',
  'Jalgaon': 'जळगाव',
  'Jalna': 'जालना',
  'Jalalkheda': 'जलालखेडा',
  'Jamb': 'जांब',
  'Kalyan': 'कल्याण',
  'Kankavli': 'कणकवली',
  'Karad': 'कराड',
  'Katol': 'काटोल',
  'Khed': 'खेड',
  'Kolhapur': 'कोल्हापूर',
  'Kondhali': 'कोंढाळी',
  'Kudal': 'कुडाळ',
  'Kurha': 'कुर्हा',
  'Kurundwad': 'कुरुंदवाड',
  'Latur': 'लातूर',
  'Mahabaleshwar': 'महाबळेश्वर',
  'Mahad': 'महाड',
  'Malvan': 'मालवण',
  'Manchar': 'मंचर',
  'Miraj': 'मिरज',
  'Mouda': 'मौदा',
  'Mor Bhavan (Nagpur)': 'मोर भवन (नागपूर)',
  'Muktainagar': 'मुक्ताईनगर',
  'Mul': 'मूल',
  'Mumbai': 'मुंबई',
  'Mumbai Central': 'मुंबई सेंट्रल',
  'Nagpur': 'नागपूर',
  'Nagpur Imamwada': 'नागपूर इमामवाडा',
  'Nanded': 'नांदेड',
  'Nandurbar': 'नंदुरबार',
  'Nashik': 'नाशिक',
  'Osmanabad': 'धाराशिव',
  'Dharashiv': 'धाराशिव',
  'Paithan': 'पैठण',
  'Palghar': 'पालघर',
  'Panchgani': 'पाचगणी',
  'Pandharkawda': 'पांढरकवडा',
  'Pandharpur': 'पंढरपूर',
  'Panvel': 'पनवेल',
  'Paratwada': 'परतवाडा',
  'Parbhani': 'परभणी',
  'Pauni': 'पवनी',
  'Phaltan': 'फलटण',
  'Pulgaon': 'पुलगाव',
  'Pune': 'पुणे',
  'Pune Swargate': 'पुणे स्वारगेट',
  'Pune Station': 'पुणे स्टेशन',
  'Pusad': 'पुसद',
  'Radhanagari': 'राधानगरी',
  'Rajapur': 'राजापूर',
  'Rajura': 'राजुरा',
  'Ralegaon': 'राळेगाव',
  'Ratnagiri': 'रत्नागिरी',
  'Sakoli': 'साकोली',
  'Sangli': 'सांगली',
  'Satara': 'सातारा',
  'Sawantwadi': 'सावंतवाडी',
  'Seloo': 'सेलू',
  'Shegaon': 'शेगाव',
  'Shirdi': 'शिर्डी',
  'Shirpur': 'शिरपूर',
  'Shrivardhan': 'श्रीवर्धन',
  'Sitabuldi (Nagpur)': 'सीताबर्डी (नागपूर)',
  'Solapur': 'सोलापूर',
  'Thane': 'ठाणे',
  'Trimbakeshwar': 'त्र्यंबकेश्वर',
  'Tuljapur': 'तुळजापूर',
  'Tumsar': 'तुमसर',
  'Vengurla': 'वेंगुर्ला',
  'Wai': 'वाई',
  'Wani': 'वणी',
  'Wardha': 'वर्धा',
  'Warora': 'वरोरा',
  'Washim': 'वाशिम',
  'Yavatmal': 'यवतमाळ'
};

const DEPOT_DISPLAY_NAMES = {
  'akola_bus_stand_depot': { en: 'Akola', mr: 'अकोला' },
  'akot_bus_stand_depot': { en: 'Akot', mr: 'आकोट' },
  'amravati_bus_stand_depot': { en: 'Amravati', mr: 'अमरावती' },
  'amravati_depot': { en: 'Amravati', mr: 'अमरावती' },
  'ashti_bus_stand_depot': { en: 'Ashti', mr: 'आष्टी' },
  'badnera_bus_stand_depot': { en: 'Badnera', mr: 'बडनेरा' },
  'ballarpur_bus_stand_depot': { en: 'Ballarpur', mr: 'बल्लारपूर' },
  'beed_bus_stand_depot': { en: 'Beed', mr: 'बीड' },
  'bhadravati_bus_stand_depot': { en: 'Bhadravati', mr: 'भद्रावती' },
  'bhusawal_bus_stand_depot': { en: 'Bhusawal', mr: 'भुसावळ' },
  'chandrapur_bus_stand_depot': { en: 'Chandrapur', mr: 'चंद्रपूर' },
  'chandur_bazar_bust_stand_depot': { en: 'Chandur Bazar', mr: 'चांदूर बाजार' },
  'chandur_railway_bus_stand_depot': { en: 'Chandur Railway', mr: 'चांदूर रेल्वे' },
  'chimur_bus_stand_depot': { en: 'Chimur', mr: 'चिमूर' },
  'darwha_bus_stand_depot': { en: 'Darwha', mr: 'दारव्हा' },
  'deoli_bus_stand_depot': { en: 'Deoli', mr: 'देवळी' },
  'dhamangoan_railway_bus_stand_depot': { en: 'Dhamangaon Railway', mr: 'धामणगाव रेल्वे' },
  'dharni_bus_stand_depot': { en: 'Dharni', mr: 'धारणी' },
  'digras_bus_stand_depot': { en: 'Digras', mr: 'दिग्रस' },
  'ghuggus_bus_stand_depot': { en: 'Ghuggus', mr: 'घुग्गुस' },
  'hinganghat_bus_stand_depot': { en: 'Hinganghat', mr: 'हिंगणघाट' },
  'jalalkhed_bus_stand_depot': { en: 'Jalalkheda', mr: 'जलालखेडा' },
  'jalgaon_bus_stand_depot': { en: 'Jalgaon', mr: 'जळगाव' },
  'jamb_bus_stand_depot': { en: 'Jamb', mr: 'जांब' },
  'katol_bus_stand_depot': { en: 'Katol', mr: 'काटोल' },
  'kondhali_bus_stand_depot': { en: 'Kondhali', mr: 'कोंढाळी' },
  'kurha_bus_stand_depot': { en: 'Kurha', mr: 'कुर्हा' },
  'mauda_bus_stand_depot': { en: 'Mouda', mr: 'मौदा' },
  'mor_bhavan_depot': { en: 'Mor Bhavan (Nagpur)', mr: 'मोर भवन (नागपूर)' },
  'muktainagar_bus_stand_depot': { en: 'Muktainagar', mr: 'मुक्ताईनगर' },
  'mul_bus_stand_depot': { en: 'Mul', mr: 'मूल' },
  'nagpur_imamwada_bus_stand_depot': { en: 'Nagpur Imamwada', mr: 'नागपूर इमामवाडा' },
  'pandharkawda_bus_stand_depot': { en: 'Pandharkawda', mr: 'पांढरकवडा' },
  'paratwada_bus_stand_depot': { en: 'Paratwada', mr: 'परतवाडा' },
  'pauni_bus_stand_depot': { en: 'Pauni', mr: 'पवनी' },
  'pulgaon_bus_stand_depot': { en: 'Pulgaon', mr: 'पुलगाव' },
  'pusad_bus_stand_depot': { en: 'Pusad', mr: 'पुसद' },
  'rajura_bus_stand_depot': { en: 'Rajura', mr: 'राजुरा' },
  'ralegaon_bus_stand_depot': { en: 'Ralegaon', mr: 'राळेगाव' },
  'sakoli_bus_stand_depot': { en: 'Sakoli', mr: 'साकोली' },
  'seloo_bus_stand_depot': { en: 'Seloo', mr: 'सेलू' },
  'sitabuldi_depot': { en: 'Sitabuldi (Nagpur)', mr: 'सीताबर्डी (नागपूर)' },
  'tumsar_bus_stand_depot': { en: 'Tumsar', mr: 'तुमसर' },
  'wani_bus_stand_depot': { en: 'Wani', mr: 'वणी' },
  'wardha_bus_stand_depot': { en: 'Wardha', mr: 'वर्धा' },
  'warora_bus_stand_depot': { en: 'Warora', mr: 'वरोरा' },
  'yavatmal_bus_stand_depot': { en: 'Yavatmal', mr: 'यवतमाळ' }
};

// cp1252 byte decoder for restoring double-encoded UTF-8 strings
const cp1252Map = {
  0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85,
  0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
  0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
  0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
  0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
  0x017E: 0x9E, 0x0178: 0x9F
};

function fixMojibake(str) {
  if (!str) return '';
  str = str.replace(/â€“|â€”/g, '–');
  if (!str.includes('à') && !str.includes('¤') && !str.includes('¥')) return str;
  const bytes = [];
  for (let i = 0; i < str.length; i++) {
    const code = str.charCodeAt(i);
    if (code <= 0xFF) bytes.push(code);
    else if (cp1252Map[code]) bytes.push(cp1252Map[code]);
    else bytes.push(code & 0xFF);
  }
  try { return Buffer.from(bytes).toString('utf8'); } catch (e) { return str; }
}

// Normalize station name
function cleanName(raw) {
  if (!raw) return '';
  let s = raw.replace(/\s+/g, ' ').trim();
  if (s === s.toLowerCase() && s.length > 2) {
    s = s.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  }
  return s;
}

// Convert "HH:MM" or "H:MM am/pm" into total minutes from midnight
function parseMinutes(timeStr) {
  if (!timeStr) return null;
  timeStr = timeStr.trim().toLowerCase();
  
  let isPm = timeStr.includes('pm');
  let isAm = timeStr.includes('am');
  timeStr = timeStr.replace(/[apm\s]/g, '');
  
  const parts = timeStr.split(':');
  if (parts.length < 2) return null;
  
  let h = parseInt(parts[0], 10);
  let m = parseInt(parts[1], 10);
  if (isNaN(h) || isNaN(m)) return null;
  
  if (isPm && h < 12) h += 12;
  if (isAm && h === 12) h = 0;
  
  return h * 60 + m;
}

function formatTime(minutes) {
  const h = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

async function main() {
  console.log('--- Starting ST Saathi Database Compilation ---');
  
  const stationsMap = new Map(); // en_name_lower -> { id, en, mr, isDepot }
  const services = []; // Array of service objects
  let stationIdCounter = 1;

  function getOrCreateStation(enName, mrName = null, isDepot = false) {
    const cleanEn = cleanName(enName);
    const key = cleanEn.toLowerCase();
    
    // Check master dictionary first
    let resolvedMr = MARATHI_NAMES[cleanEn] || STATION_MARATHI_MAP[cleanEn];
    if (!resolvedMr) {
      for (const k in MARATHI_NAMES) {
        if (k.toLowerCase() === key) {
          resolvedMr = MARATHI_NAMES[k];
          break;
        }
      }
    }
    if (!resolvedMr && mrName) {
      const fixed = fixMojibake(mrName);
      if (/^[\u0900-\u097F\s\(\)\-\.,\/–]+$/.test(fixed)) {
        resolvedMr = fixed;
      }
    }
    if (!resolvedMr) resolvedMr = cleanEn;

    if (stationsMap.has(key)) {
      const existing = stationsMap.get(key);
      if (resolvedMr && resolvedMr !== cleanEn && (!existing.mr || existing.mr === existing.en || existing.mr.includes('à'))) {
        existing.mr = resolvedMr;
      }
      if (isDepot) existing.isDepot = true;
      return existing.id;
    }
    
    const newStation = {
      id: stationIdCounter++,
      en: cleanEn,
      mr: resolvedMr,
      isDepot: isDepot
    };
    stationsMap.set(key, newStation);
    return newStation.id;
  }

  // 1. Ingest Vaibhav's packed routes (Western & Konkan routes + bilingual stations)
  const vaibhavPath = path.join(__dirname, '../data_source/vaibhav/packed_routes.json');
  if (fs.existsSync(vaibhavPath)) {
    console.log('Loading Western routes and bilingual stations from vaibhav/packed_routes.json...');
    let raw = fs.readFileSync(vaibhavPath, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
    const packed = JSON.parse(raw);
    
    // Register all stations
    const stationIdLookup = [];
    for (let i = 0; i < packed.s.length; i++) {
      const [en, mr] = packed.s[i];
      const id = getOrCreateStation(en, mr);
      stationIdLookup.push(id);
    }
    
    // Classes and Via mappings
    const classes = packed.c || ['Ordinary', 'Hirkani', 'Shivshahi', 'Shivneri', 'Sleeper'];
    const viaList = packed.v || [];
    
    // Routes: [fromIdx, toIdx, depMinutes, durMinutes, clsIdx, fare, distKm, platform, delayMinutes, seats, viaIdx]
    let vaibhavRoutesCount = 0;
    for (const r of packed.r) {
      const fromId = stationIdLookup[r[0]];
      const toId = stationIdLookup[r[1]];
      const depMin = r[2];
      const cls = classes[r[4]] || 'Ordinary';
      const via = (r[10] !== undefined && viaList[r[10]]) ? viaList[r[10]].replace(/\|/g, ', ') : '';
      
      if (fromId && toId && depMin !== undefined) {
        services.push({
          origin_id: fromId,
          destination_id: toId,
          dep_minutes: depMin,
          dep_time: formatTime(depMin),
          bus_type: cls.charAt(0).toUpperCase() + cls.slice(1),
          via_stops: via,
          source_depot: 'Depot Sheet (Western Maharashtra)',
          verified: 1
        });
        vaibhavRoutesCount++;
      }
    }
    console.log(`Ingested ${vaibhavRoutesCount} services from Western Maharashtra.`);
  }

  // 2. Ingest 45 CookingConverter Depots (Vidarbha, Khandesh, Marathwada)
  const depotsDir = path.join(__dirname, '../data_source/cookingconverter/depots');
  if (fs.existsSync(depotsDir)) {
    const depotFiles = fs.readdirSync(depotsDir);
    console.log(`Loading 45 depot schedules from cookingconverter/depots/ (${depotFiles.length} files)...`);
    let depotServicesCount = 0;

    for (const file of depotFiles) {
      if (!file.endsWith('.json')) continue;
      const data = JSON.parse(fs.readFileSync(path.join(depotsDir, file), 'utf8'));
      
      const depotMeta = DEPOT_DISPLAY_NAMES[data.id] || { en: cleanName(data.id.replace(/_bus_stand_depot|_depot|_bust_stand_depot/g, '').replace(/_/g, ' ')), mr: null };
      const originId = getOrCreateStation(depotMeta.en, depotMeta.mr, true);
      
      if (data.villages) {
        for (const letter in data.villages) {
          for (const item of data.villages[letter]) {
            if (!item.name || !item.schedule || !item.schedule.length) continue;
            
            // Destination parsing: e.g. "Anjangaon via Khallar" -> dest="Anjangaon", via="Khallar"
            let rawDest = item.name.trim();
            let via = '';
            if (rawDest.toLowerCase().includes(' via ')) {
              const parts = rawDest.split(/\s+via\s+/i);
              rawDest = parts[0].trim();
              via = parts[1].trim();
            }
            const viaParenMatch = rawDest.match(/^(.*?)\s*\(\s*via\s+(.*?)\s*\)$/i);
            if (viaParenMatch) {
              rawDest = viaParenMatch[1].trim();
              via = via ? `${via}, ${viaParenMatch[2].trim()}` : viaParenMatch[2].trim();
            }
            
            const destId = getOrCreateStation(rawDest);
            
            for (const timeStr of item.schedule) {
              const depMin = parseMinutes(timeStr);
              if (depMin === null) continue;
              
              let cleanDepot = (data.name || '').split('|')[0]
                .replace(/timetable.*$/i, '')
                .replace(/\b202\d\b/g, '')
                .replace(/msrtc.*$/i, '')
                .trim();
              if (!cleanDepot || cleanDepot.length < 3) cleanDepot = `${depotMeta.en} Bus Stand`;

              services.push({
                origin_id: originId,
                destination_id: destId,
                dep_minutes: depMin,
                dep_time: formatTime(depMin),
                bus_type: 'Ordinary',
                via_stops: via,
                source_depot: cleanDepot,
                verified: 1
              });
              depotServicesCount++;
            }
          }
        }
      }
    }
    console.log(`Ingested ${depotServicesCount} services from Vidarbha/Marathwada/Khandesh depots.`);
  }

  console.log(`Total unique stations collected: ${stationsMap.size}`);
  console.log(`Total departures collected: ${services.length}`);

  // 3. Deduplicate Services
  const uniqueKeySet = new Set();
  const dedupedServices = [];
  for (const s of services) {
    const key = `${s.origin_id}-${s.destination_id}-${s.dep_minutes}-${s.via_stops}`;
    if (!uniqueKeySet.has(key)) {
      uniqueKeySet.add(key);
      dedupedServices.push(s);
    }
  }
  console.log(`Deduplicated services count: ${dedupedServices.length}`);

  // 4. Generate SQL Script
  const sqlPath = path.join(__dirname, 'import_data.sql');
  const dbDir = path.join(__dirname, '../assets/database');
  if (!fs.existsSync(dbDir)) fs.mkdirSync(dbDir, { recursive: true });
  const dbPath = path.join(dbDir, 'st_timetable.db');
  
  if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);

  const sqlStream = fs.createWriteStream(sqlPath, { encoding: 'utf8' });

  sqlStream.write(`
PRAGMA foreign_keys = OFF;
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;

BEGIN TRANSACTION;

CREATE TABLE stations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_en TEXT NOT NULL,
    name_mr TEXT NOT NULL,
    is_depot INTEGER DEFAULT 0
);

CREATE TABLE services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    origin_id INTEGER NOT NULL REFERENCES stations(id),
    destination_id INTEGER NOT NULL REFERENCES stations(id),
    departure_time TEXT NOT NULL,
    dep_minutes INTEGER NOT NULL,
    bus_type TEXT,
    via_stops TEXT,
    source_depot TEXT,
    verified INTEGER DEFAULT 1
);

`);

  // Write stations
  for (const st of stationsMap.values()) {
    const en = st.en.replace(/'/g, "''");
    const mr = st.mr.replace(/'/g, "''");
    const isDepot = st.isDepot ? 1 : 0;
    sqlStream.write(`INSERT INTO stations (id, name_en, name_mr, is_depot) VALUES (${st.id}, '${en}', '${mr}', ${isDepot});\n`);
  }

  // Write services
  for (const s of dedupedServices) {
    const busType = s.bus_type ? `'${s.bus_type.replace(/'/g, "''")}'` : 'NULL';
    const via = s.via_stops ? `'${s.via_stops.replace(/'/g, "''")}'` : 'NULL';
    const source = s.source_depot ? `'${s.source_depot.replace(/'/g, "''")}'` : 'NULL';
    sqlStream.write(`INSERT INTO services (origin_id, destination_id, departure_time, dep_minutes, bus_type, via_stops, source_depot, verified) VALUES (${s.origin_id}, ${s.destination_id}, '${s.dep_time}', ${s.dep_minutes}, ${busType}, ${via}, ${source}, 1);\n`);
  }

  // Indexes
  sqlStream.write(`
CREATE INDEX idx_stations_name_en ON stations(name_en COLLATE NOCASE);
CREATE INDEX idx_stations_name_mr ON stations(name_mr);
CREATE INDEX idx_services_pair ON services(origin_id, destination_id);
CREATE INDEX idx_services_origin ON services(origin_id);
CREATE INDEX idx_services_dest ON services(destination_id);
CREATE INDEX idx_services_dep_min ON services(dep_minutes);

COMMIT;
VACUUM;
ANALYZE;
`);

  sqlStream.end();

  await new Promise(resolve => sqlStream.on('finish', resolve));
  console.log(`Generated ${sqlPath}. Now compiling into SQLite database at ${dbPath}...`);

  // Run sqlite3 to build database
  try {
    execSync(`sqlite3 "${dbPath}" < "${sqlPath}"`);
    console.log('SQLite compilation completed successfully!');
    const stats = fs.statSync(dbPath);
    console.log(`Compiled Database Size: ${(stats.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Clean up temporary SQL file
    fs.unlinkSync(sqlPath);
  } catch (err) {
    console.error('Failed to compile SQLite database:', err.message);
    process.exit(1);
  }
}

main().catch(console.error);
