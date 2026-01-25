const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = 8080;


const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'pogodynka',
  password: 'postgres',
  port: 5432,
});

app.use(cors());
app.use(express.json());

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query(
      'SELECT id, rola_id, email FROM uzytkownicy WHERE email = $1 AND haslo_hash = $2',
      [email, password]
    );

    if (result.rows.length > 0) {
      const user = result.rows[0];
      res.json({
        success: true,
        user: { id: user.id, email: user.email, roleId: user.rola_id }
      });
    } else {
      res.status(401).json({ success: false, message: 'Błędny login lub hasło' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Błąd serwera' });
  }
});

app.get('/stations', async (req, res) => {
  const userId = parseInt(req.query.userId || 0);
  const roleId = parseInt(req.query.roleId || 2);

  try {
    let query = `
      SELECT s.id, s.nazwa, s.opis, t.kod as typ, s.czy_publiczna, s.wlasciciel_id
      FROM stacje s
      JOIN typy_stacji t ON s.typ_id = t.id
    `;
    const params = [];

    if (roleId !== 1) {
      query += ` WHERE s.czy_publiczna = TRUE OR s.wlasciciel_id = $1`;
      params.push(userId);
    }
    query += ` ORDER BY s.id DESC`;

    const result = await pool.query(query, params);
    
    const stations = result.rows.map(row => ({
      id: row.id,
      name: row.nazwa,
      description: row.opis,
      type: row.typ === 'ruchoma' ? 'mobile' : 'staticStation',
      isPublic: row.czy_publiczna,
      ownerId: row.wlasciciel_id
    }));

    res.json(stations);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Błąd pobierania stacji' });
  }
});


app.post('/stations', async (req, res) => {
  const { name, description, type, userId, isPublic, withData } = req.body;

  console.log(`\n NOWE ŻĄDANIE: Dodaj stację "${name}"`);
  console.log(`   -> Demo (withData): ${withData}`);

  try {
    const typeId = (type === 'ruchoma') ? 2 : 1;
    
  
    const result = await pool.query(
      'INSERT INTO stacje (wlasciciel_id, typ_id, nazwa, opis, czy_publiczna) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [userId, typeId, name, description, isPublic]
    );
    const stationId = result.rows[0].id;

    if (withData === true) {
      try {
        const externalId = 'demo_' + stationId; 
        
        const sensorRes = await pool.query(
          "INSERT INTO sensory (stacja_id, typ_sensor_id, id_zewnetrzne) VALUES ($1, 1, $2) RETURNING id",
          [stationId, externalId] 
        );
        const sensorId = sensorRes.rows[0].id;
        for (let i = 0; i < 24; i++) {
          const temp = 15 + (5 * Math.sin(i)) + (Math.random() * 2); 
          await pool.query(
            "INSERT INTO pomiary (stacja_id, sensor_id, czas_pomiaru, wartosc) VALUES ($1, $2, NOW() - ($3 * INTERVAL '1 hour'), $4)",
            [stationId, sensorId, i, temp.toFixed(2)]
          );
        }

        if (typeId === 2) {
          const trasaRes = await pool.query(
            "INSERT INTO trasy_ruchome (stacja_id, nazwa, rozpoczeto) VALUES ($1, 'Trasa Demo', NOW() - INTERVAL '5 hours') RETURNING id",
            [stationId]
          );
          const trasaId = trasaRes.rows[0].id;

          const startLat = 51.9; 
          const startLon = 19.5;

          for (let k = 0; k < 10; k++) {
            const lat = startLat + (k * 0.05);
            const lon = startLon + (Math.sin(k) * 0.05);
            
            await pool.query(
              "INSERT INTO punkty_trasy (trasa_id, kolejnosc, czas_zapisania, szerokosc, dlugosc) VALUES ($1, $2, NOW() - ($3 * INTERVAL '15 minutes'), $4, $5)",
              [trasaId, k + 1, (10 - k), lat, lon]
            );
          }

        }

      } catch (innerErr) {
        console.error(` BŁĄD PODCZAS GENEROWANIA DANYCH:`, innerErr.message);
      }
    }

    res.json({ status: 'success', id: stationId });
  } catch (err) {
    res.status(500).json({ error: 'Błąd: ' + err.message });
  }
});


app.delete('/stations/:id', async (req, res) => {
  const stationId = req.params.id;
  const userId = parseInt(req.query.userId);
  const roleId = parseInt(req.query.roleId);

  try {
    const check = await pool.query('SELECT wlasciciel_id FROM stacje WHERE id = $1', [stationId]);
    if (check.rows.length === 0) return res.status(404).json({error: 'Nie znaleziono stacji'});

    const ownerId = check.rows[0].wlasciciel_id;

    if (roleId === 1 || userId === ownerId) {
      await pool.query('DELETE FROM stacje WHERE id = $1', [stationId]);
      res.json({ status: 'deleted' });
    } else {
      res.status(403).json({ error: 'Brak uprawnień' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Błąd usuwania' });
  }
});

app.patch('/stations/:id/toggle', async (req, res) => {
  const stationId = req.params.id;
  try {
    await pool.query(
      'UPDATE stacje SET czy_publiczna = NOT COALESCE(czy_publiczna, true) WHERE id = $1',
      [stationId]
    );
    res.json({ status: 'toggled' });
  } catch (err) {
    res.status(500).json({ error: 'Błąd' });
  }
});

app.get('/measurements/:stationId', async (req, res) => {
  const { stationId } = req.params;
  try {
    const result = await pool.query(`
      SELECT m.czas_pomiaru, m.wartosc, ts.kod as typ_sensora
      FROM pomiary m
      JOIN sensory s ON m.sensor_id = s.id
      JOIN typy_sensorow ts ON s.typ_sensor_id = ts.id
      WHERE m.stacja_id = $1
      ORDER BY m.czas_pomiaru DESC
      LIMIT 50
    `, [stationId]);

    const history = result.rows.map(row => ({
      timestamp: row.czas_pomiaru,
      value: row.wartosc,
      type: row.typ_sensora
    }));

    res.json(history);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Błąd pobierania historii' });
  }
});


app.get('/route/:stationId', async (req, res) => {
  const { stationId } = req.params;
  try {
    const result = await pool.query(`
      SELECT pt.szerokosc, pt.dlugosc, pt.czas_zapisania
      FROM punkty_trasy pt
      JOIN trasy_ruchome tr ON pt.trasa_id = tr.id
      WHERE tr.stacja_id = $1
      ORDER BY tr.rozpoczeto DESC, pt.kolejnosc ASC
      LIMIT 100
    `, [stationId]);

    const points = result.rows.map(row => ({
      lat: row.szerokosc,
      lon: row.dlugosc,
      timestamp: row.czas_zapisania
    }));

    res.json(points);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Błąd pobierania trasy' });
  }
});

app.listen(port, () => {
  console.log(` Serwer działa na porcie ${port}`);
});