const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = 8080;

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'pogodynka',
  password: 'postgres', // <--- TWOJE HASŁO
  port: 5432,
});

app.use(cors());
app.use(express.json());

// ==========================================
// UŻYTKOWNICY
// ==========================================

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query(
      'SELECT id, rola_id, email FROM uzytkownicy WHERE email = $1 AND haslo_hash = $2',
      [email, password]
    );
    if (result.rows.length > 0) {
      const user = result.rows[0];
      res.json({ success: true, user: { id: user.id, email: user.email, roleId: user.rola_id } });
    } else {
      res.status(401).json({ success: false, message: 'Błędny login lub hasło' });
    }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  try {
    const check = await pool.query('SELECT id FROM uzytkownicy WHERE email = $1', [email]);
    if (check.rows.length > 0) return res.status(400).json({ success: false, message: 'Email zajęty!' });
    await pool.query('INSERT INTO uzytkownicy (email, haslo_hash, rola_id) VALUES ($1, $2, 2)', [email, password]);
    res.json({ success: true, message: 'Konto utworzone' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/delete-account', async (req, res) => {
  const { userId } = req.body;
  try {
    const stations = await pool.query('SELECT id FROM stacje WHERE wlasciciel_id = $1', [userId]);
    for (let row of stations.rows) {
      await pool.query('DELETE FROM pomiary WHERE stacja_id = $1', [row.id]);
      await pool.query('DELETE FROM punkty_trasy WHERE trasa_id IN (SELECT id FROM trasy_ruchome WHERE stacja_id = $1)', [row.id]);
      await pool.query('DELETE FROM trasy_ruchome WHERE stacja_id = $1', [row.id]);
      await pool.query('DELETE FROM sensory WHERE stacja_id = $1', [row.id]);
    }
    await pool.query('DELETE FROM stacje WHERE wlasciciel_id = $1', [userId]);
    await pool.query('DELETE FROM uzytkownicy WHERE id = $1', [userId]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ==========================================
// STACJE I GENERATOR
// ==========================================

app.get('/stations', async (req, res) => {
  const userId = parseInt(req.query.userId || 0);
  const roleId = parseInt(req.query.roleId || 2);
  try {
    let query = `SELECT s.id, s.nazwa, s.opis, t.kod as typ, s.czy_publiczna, s.wlasciciel_id FROM stacje s JOIN typy_stacji t ON s.typ_id = t.id`;
    const params = [];
    if (roleId !== 1) { query += ` WHERE s.czy_publiczna = TRUE OR s.wlasciciel_id = $1`; params.push(userId); }
    query += ` ORDER BY s.id DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows.map(row => ({
      id: row.id, name: row.nazwa, description: row.opis, type: row.typ === 'ruchoma' ? 'mobile' : 'staticStation', isPublic: row.czy_publiczna, ownerId: row.wlasciciel_id
    })));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// --- POPRAWIONE GENEROWANIE DANYCH ---
app.post('/stations', async (req, res) => {
  const { name, description, type, userId, isPublic, withData } = req.body;
  try {
    const typeId = (type === 'ruchoma') ? 2 : 1;
    const result = await pool.query(
      'INSERT INTO stacje (wlasciciel_id, typ_id, nazwa, opis, czy_publiczna) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [userId, typeId, name, description, isPublic]
    );
    const stationId = result.rows[0].id;

    if (withData === true) {
      // 1. Tworzymy sensory
      const sensorsConfig = [
          { id: 1, code: 'temp' }, { id: 2, code: 'wind' }, 
          { id: 3, code: 'hum' }, { id: 4, code: 'press' }
      ];
      const createdSensors = {};
      for(let s of sensorsConfig) {
           const res = await pool.query("INSERT INTO sensory (stacja_id, typ_sensor_id, id_zewnetrzne) VALUES ($1, $2, $3) RETURNING id", [stationId, s.id, `demo_${s.code}_${stationId}`]);
           createdSensors[s.code] = res.rows[0].id;
      }

      // 2. Generujemy dane (Pętla 24h)
      for (let i = 0; i < 24; i++) {
        // WAŻNE: Obliczamy datę RAZ dla całej pętli, żeby GROUP BY działało
        const dateRes = await pool.query(`SELECT NOW() - ($1 * INTERVAL '1 hour') as data`, [i]);
        const measurementDate = dateRes.rows[0].data;

        // Matematyka: -10 do +30 stopni
        // Sinusoida dobowa + losowy szum
        const temp = -5 + (15 * Math.sin(i * 0.5)) + (Math.random() * 4 - 2); 
        
        // Wiatr: 0 do 30 m/s (nie może być ujemny)
        const wind = Math.abs(5 + (10 * Math.sin(i)) + (Math.random() * 10));
        
        // Wilgotność: 30 do 99%
        let hum = 60 + (20 * Math.cos(i)) + (Math.random() * 10);
        if (hum > 100) hum = 100; if (hum < 0) hum = 0;

        const press = 1013 + (10 * Math.sin(i/3));

        const insertSQL = "INSERT INTO pomiary (stacja_id, sensor_id, czas_pomiaru, wartosc) VALUES ($1, $2, $3, $4)";
        
        // Wstawiamy wszystkie 4 wartości z TĄ SAMĄ datą
        await pool.query(insertSQL, [stationId, createdSensors['temp'], measurementDate, temp.toFixed(1)]);
        await pool.query(insertSQL, [stationId, createdSensors['wind'], measurementDate, wind.toFixed(1)]);
        await pool.query(insertSQL, [stationId, createdSensors['hum'], measurementDate, hum.toFixed(0)]);
        await pool.query(insertSQL, [stationId, createdSensors['press'], measurementDate, press.toFixed(0)]);
      }

      // 3. Trasa (jeśli ruchoma)
      if (typeId === 2) {
        const trasaRes = await pool.query("INSERT INTO trasy_ruchome (stacja_id, nazwa, rozpoczeto) VALUES ($1, 'Trasa Demo', NOW() - INTERVAL '5 hours') RETURNING id", [stationId]);
        const trasaId = trasaRes.rows[0].id;
        const startLat = 52.0; const startLon = 20.0;
        for (let k = 0; k < 10; k++) {
          await pool.query("INSERT INTO punkty_trasy (trasa_id, kolejnosc, czas_zapisania, szerokosc, dlugosc) VALUES ($1, $2, NOW() - ($3 * INTERVAL '15 minutes'), $4, $5)",
            [trasaId, k + 1, (10 - k), startLat + (k * 0.02), startLon + (Math.sin(k) * 0.02)]);
        }
      }
    }
    res.json({ status: 'success', id: stationId });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/stations/:id', async (req, res) => {
  const stationId = req.params.id;
  const userId = parseInt(req.query.userId);
  const roleId = parseInt(req.query.roleId);
  try {
    const check = await pool.query('SELECT wlasciciel_id FROM stacje WHERE id = $1', [stationId]);
    if (check.rows.length === 0) return res.status(404).json({error: 'Nie znaleziono'});
    if (roleId === 1 || userId === check.rows[0].wlasciciel_id) {
      await pool.query('DELETE FROM pomiary WHERE stacja_id = $1', [stationId]);
      await pool.query('DELETE FROM sensory WHERE stacja_id = $1', [stationId]);
      await pool.query('DELETE FROM stacje WHERE id = $1', [stationId]);
      res.json({ status: 'deleted' });
    } else { res.status(403).json({ error: 'Brak uprawnień' }); }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/stations/:id/toggle', async (req, res) => {
  try {
    await pool.query('UPDATE stacje SET czy_publiczna = NOT COALESCE(czy_publiczna, true) WHERE id = $1', [req.params.id]);
    res.json({ status: 'toggled' });
  } catch (err) { res.status(500).json({ error: 'Błąd' }); }
});

app.get('/measurements/:stationId', async (req, res) => {
  const { stationId } = req.params;
  try {
    // PIVOT TABLE: Grupowanie po czasie (do minuty)
    const result = await pool.query(`
      SELECT 
        to_char(m.czas_pomiaru, 'YYYY-MM-DD HH24:MI') as czas,
        MAX(CASE WHEN ts.kod = 'temperatura' THEN m.wartosc END) as temp,
        MAX(CASE WHEN ts.kod = 'wiatr' THEN m.wartosc END) as wind,
        MAX(CASE WHEN ts.kod = 'wilgotnosc' THEN m.wartosc END) as hum,
        MAX(CASE WHEN ts.kod = 'cisnienie' THEN m.wartosc END) as press
      FROM pomiary m
      JOIN sensory s ON m.sensor_id = s.id
      JOIN typy_sensorow ts ON s.typ_sensor_id = ts.id
      WHERE m.stacja_id = $1
      GROUP BY to_char(m.czas_pomiaru, 'YYYY-MM-DD HH24:MI')
      ORDER BY czas DESC
      LIMIT 50
    `, [stationId]);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Błąd historii' }); }
});

app.get('/route/:stationId', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT pt.szerokosc, pt.dlugosc, pt.czas_zapisania
      FROM punkty_trasy pt
      JOIN trasy_ruchome tr ON pt.trasa_id = tr.id
      WHERE tr.stacja_id = $1
      ORDER BY tr.rozpoczeto DESC, pt.kolejnosc ASC
      LIMIT 100
    `, [req.params.stationId]);
    res.json(result.rows.map(r => ({ lat: r.szerokosc, lon: r.dlugosc, timestamp: r.czas_zapisania })));
  } catch (err) { res.status(500).json({ error: 'Błąd trasy' }); }
});
// Pobieranie progów (dla historii i panelu admina)
app.get('/progi', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM progi_alertow');
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Aktualizacja progów przez admina
app.post('/progi', async (req, res) => {
  const { kod_parametru, wartosc_min, wartosc_max } = req.body;
  try {
    await pool.query(
      'UPDATE progi_alertow SET wartosc_min = $1, wartosc_max = $2 WHERE kod_parametru = $3',
      [wartosc_min, wartosc_max, kod_parametru]
    );
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Pobieranie stacji z informacją o aktywnym alercie
app.get('/stations', async (req, res) => {
  const { userId, roleId } = req.query;
  try {
    const result = await pool.query(`
      SELECT s.*, 
      EXISTS (
        SELECT 1 FROM pomiary p
        JOIN sensory sen ON p.sensor_id = sen.id
        JOIN typy_sensorow ts ON sen.typ_sensor_id = ts.id
        JOIN progi_alertow pa ON ts.kod = pa.kod_parametru
        WHERE p.stacja_id = s.id 
        AND p.czas_pomiaru > NOW() - INTERVAL '1 hour'
        AND (p.wartosc < pa.wartosc_min OR p.wartosc > pa.wartosc_max)
      ) as ma_alert
      FROM stacje s
      WHERE s.is_public = true OR s.uzytkownik_id = $1 OR $2 = 1
    `, [userId, roleId]);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.listen(port, () => { console.log(`🚀 Serwer działa na porcie ${port}`); });