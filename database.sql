CREATE EXTENSION IF NOT EXISTS plpgsql;

CREATE TABLE "role" (
  "id" SERIAL PRIMARY KEY,
  "nazwa" TEXT NOT NULL UNIQUE
);

CREATE TABLE "uzytkownicy" (
  "id" SERIAL PRIMARY KEY,
  "rola_id" INTEGER NOT NULL REFERENCES "role"("id"),
  "email" TEXT UNIQUE,
  "haslo_hash" TEXT,
  "aktywny" BOOLEAN DEFAULT TRUE,
  "utworzono" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO "role" (id, nazwa) VALUES (1, 'administrator');
INSERT INTO "role" (id, nazwa) VALUES (2, 'uzytkownik');
INSERT INTO "role" (id, nazwa) VALUES (3, 'gosc');

INSERT INTO uzytkownicy (rola_id, email, haslo_hash)
VALUES (1, 'admin@pogodynka.pl', 'admin123');
INSERT INTO uzytkownicy (rola_id, email, haslo_hash)
VALUES (2, 'uzyt1@pogodynka.pl', 'maslo');
INSERT INTO uzytkownicy (rola_id, email, haslo_hash)
VALUES (2, 'uzyt2@pogodynka.pl', 'kielbasa');

CREATE TABLE "profile_uzytkownikow" (
  "uzytkownik_id" INTEGER PRIMARY KEY REFERENCES "uzytkownicy"("id") ON DELETE CASCADE,
  "nick" TEXT,
  "strefa_czasowa" TEXT DEFAULT 'Europe/Warsaw',
  "bio" TEXT
);

CREATE TABLE "typy_stacji" (
  "id" SMALLINT PRIMARY KEY,
  "kod" TEXT NOT NULL UNIQUE,
  "opis" TEXT
);

INSERT INTO "typy_stacji" (id, kod, opis)
VALUES (1,'stacjonarna','Stacja stacjonarna'),
       (2,'ruchoma','Stacja ruchoma')
ON CONFLICT DO NOTHING;

CREATE TABLE "stacje" (
  "id" BIGSERIAL PRIMARY KEY,
  "wlasciciel_id" INTEGER REFERENCES "uzytkownicy"("id") ON DELETE SET NULL,
  "typ_id" SMALLINT NOT NULL REFERENCES "typy_stacji"("id"),
  "nazwa" TEXT NOT NULL,
  "opis" TEXT,
  "utworzono" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  "ostatni_pomiar" TIMESTAMP WITH TIME ZONE
);

ALTER TABLE "stacje"
ADD COLUMN "czy_publiczna" BOOLEAN DEFAULT TRUE;

CREATE TABLE "typy_sensorow" (
  "id" SMALLINT PRIMARY KEY,
  "kod" TEXT NOT NULL UNIQUE,
  "jednostka" TEXT
);

INSERT INTO "typy_sensorow" (id, kod, jednostka) VALUES
 (1,'temperatura','°C'),
 (2,'predkosc_wiatru','m/s'),
 (3,'cisnienie','hPa'),
 (4,'wilgotnosc','%'),
 (5,'kierunek_wiatru','deg')
ON CONFLICT DO NOTHING;

CREATE TABLE "sensory" (
  "id" BIGSERIAL PRIMARY KEY,
  "stacja_id" BIGINT NOT NULL REFERENCES "stacje"("id") ON DELETE CASCADE,
  "typ_sensor_id" SMALLINT NOT NULL REFERENCES "typy_sensorow"("id"),
  "id_zewnetrzne" TEXT,
  "zainstalowano" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE ("stacja_id", "typ_sensor_id", "id_zewnetrzne")
);

CREATE TABLE "pomiary" (
  "id" BIGSERIAL PRIMARY KEY,
  "stacja_id" BIGINT NOT NULL REFERENCES "stacje"("id") ON DELETE CASCADE,
  "sensor_id" BIGINT REFERENCES "sensory"("id") ON DELETE SET NULL,
  "czas_pomiaru" TIMESTAMP WITH TIME ZONE NOT NULL,
  "wartosc" DOUBLE PRECISION NOT NULL,
  "jakosc" SMALLINT DEFAULT 0,
  "utworzono" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_pomiary_stacja
ON "pomiary" ("stacja_id", "czas_pomiaru" DESC);

CREATE INDEX idx_pomiary_sensor
ON "pomiary" ("sensor_id", "czas_pomiaru" DESC);

CREATE TABLE "trasy_ruchome" (
  "id" BIGSERIAL PRIMARY KEY,
  "stacja_id" BIGINT NOT NULL REFERENCES "stacje"("id") ON DELETE CASCADE,
  "nazwa" TEXT,
  "rozpoczeto" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  "zakonczono" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE "punkty_trasy" (
  "id" BIGSERIAL PRIMARY KEY,
  "trasa_id" BIGINT NOT NULL REFERENCES "trasy_ruchome"("id") ON DELETE CASCADE,
  "kolejnosc" INTEGER NOT NULL,
  "czas_zapisania" TIMESTAMP WITH TIME ZONE NOT NULL,
  "szerokosc" DOUBLE PRECISION NOT NULL,
  "dlugosc" DOUBLE PRECISION NOT NULL,
  "wysokosc" DOUBLE PRECISION,
  "notatki" TEXT,
  UNIQUE ("trasa_id", "kolejnosc")
);

CREATE INDEX idx_punkty_trasy_trasa
ON "punkty_trasy" ("trasa_id", "kolejnosc");

CREATE TABLE "ulubione_uzytkownikow" (
  "uzytkownik_id" INTEGER NOT NULL REFERENCES "uzytkownicy"("id") ON DELETE CASCADE,
  "stacja_id" BIGINT NOT NULL REFERENCES "stacje"("id") ON DELETE CASCADE,
  "utworzono" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY ("uzytkownik_id", "stacja_id")
);

CREATE TABLE "przypisanie_sensorow" (
  "stacja_id" BIGINT NOT NULL REFERENCES "stacje"("id") ON DELETE CASCADE,
  "sensor_id" BIGINT NOT NULL REFERENCES "sensory"("id") ON DELETE CASCADE,
  "przypisano" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY ("stacja_id", "sensor_id")
);

CREATE OR REPLACE VIEW "v_ostatnie_24h" AS
SELECT
  s."id" AS "stacja_id",
  s."nazwa" AS "nazwa_stacji",
  m."sensor_id",
  st."kod" AS "typ_sensora",
  m."czas_pomiaru",
  m."wartosc"
FROM "stacje" s
JOIN "pomiary" m ON m."stacja_id" = s."id"
LEFT JOIN "sensory" sen ON sen."id" = m."sensor_id"
LEFT JOIN "typy_sensorow" st ON st."id" = sen."typ_sensor_id"
WHERE m."czas_pomiaru" >= now() - interval '24 hours';

CREATE OR REPLACE FUNCTION fn_aktualizuj_ostatni_pomiar()
RETURNS trigger AS $$
BEGIN
  IF (NEW."czas_pomiaru" IS NOT NULL) THEN
    UPDATE "stacje"
    SET "ostatni_pomiar" =
      GREATEST(COALESCE("ostatni_pomiar", '1970-01-01'::timestamptz),
               NEW."czas_pomiaru")
    WHERE "id" = NEW."stacja_id";
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pomiary_after_insert
AFTER INSERT ON "pomiary"
FOR EACH ROW
EXECUTE FUNCTION fn_aktualizuj_ostatni_pomiar();

CREATE OR REPLACE FUNCTION fn_srednia_temperatura_24h(p_stacja_id BIGINT)
RETURNS double precision AS $$
DECLARE
  wynik double precision;
BEGIN
  SELECT AVG(m."wartosc") INTO wynik
  FROM "pomiary" m
  JOIN "sensory" s ON s."id" = m."sensor_id"
  JOIN "typy_sensorow" st ON st."id" = s."typ_sensor_id"
  WHERE m."stacja_id" = p_stacja_id
    AND st."kod" = 'temperatura'
    AND m."czas_pomiaru" >= now() - interval '24 hours';
  RETURN wynik;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE PROCEDURE sp_dodaj_trase_ruchomej(
  p_stacja_id BIGINT,
  p_nazwa TEXT,
  p_punkty JSON
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_trasa_id BIGINT;
  v_punkt JSON;
  v_kolejnosc INTEGER := 0;
BEGIN
  INSERT INTO "trasy_ruchome" ("stacja_id", "nazwa", "rozpoczeto")
  VALUES (p_stacja_id, p_nazwa, now())
  RETURNING "id" INTO v_trasa_id;

  FOR v_punkt IN SELECT * FROM json_array_elements(p_punkty)
  LOOP
    v_kolejnosc := v_kolejnosc + 1;
    INSERT INTO "punkty_trasy"
      ("trasa_id", "kolejnosc", "czas_zapisania",
       "szerokosc", "dlugosc", "wysokosc", "notatki")
    VALUES (
      v_trasa_id,
      v_kolejnosc,
      (v_punkt->>'recorded_at')::timestamptz,
      (v_punkt->>'lat')::double precision,
      (v_punkt->>'lon')::double precision,
      (v_punkt->>'alt')::double precision,
      v_punkt->>'notes'
    );
  END LOOP;

  IF v_kolejnosc = 0 THEN
    UPDATE "trasy_ruchome"
    SET "zakonczono" = now()
    WHERE "id" = v_trasa_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_utworz_stacje_ruchoma_z_pomiarem(
  p_wlasciciel INTEGER,
  p_nazwa TEXT,
  p_opis TEXT,
  p_typ_sensor SMALLINT,
  p_id_zew TEXT,
  p_czas TIMESTAMPTZ,
  p_wartosc DOUBLE PRECISION
)
RETURNS BIGINT AS $$
DECLARE
  v_stacja_id BIGINT;
  v_sensor_id BIGINT;
BEGIN
  PERFORM pg_advisory_xact_lock(1);

  INSERT INTO "stacje" ("wlasciciel_id", "typ_id", "nazwa", "opis")
  VALUES (p_wlasciciel, 2, p_nazwa, p_opis)
  RETURNING "id" INTO v_stacja_id;

  INSERT INTO "sensory" ("stacja_id", "typ_sensor_id", "id_zewnetrzne")
  VALUES (v_stacja_id, p_typ_sensor, p_id_zew)
  RETURNING "id" INTO v_sensor_id;

  INSERT INTO "przypisanie_sensorow" ("stacja_id", "sensor_id")
  VALUES (v_stacja_id, v_sensor_id);

  INSERT INTO "pomiary"
    ("stacja_id", "sensor_id", "czas_pomiaru", "wartosc")
  VALUES (v_stacja_id, v_sensor_id, p_czas, p_wartosc);

  RETURN v_stacja_id;
END;
$$ LANGUAGE plpgsql;

INSERT INTO "uzytkownicy" (id, rola_id, email, haslo_hash, aktywny)
VALUES (4, 1, 'admin@pogodynka.pl', 'admin123', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO "uzytkownicy" (id, rola_id, email, haslo_hash, aktywny)
VALUES (5, 2, 'uzyt1@pogodynka.pl', 'maslo', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO "uzytkownicy" (id, rola_id, email, haslo_hash, aktywny)
VALUES (6, 2, 'uzyt2@pogodynka.pl', 'kielbasa', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO stacje
(id, wlasciciel_id, typ_id, nazwa, opis, czy_publiczna, ostatni_pomiar)
VALUES
(10, 4, 1, 'Centrum Meteo', 'Główna stacja publiczna.', true, now()),
(20, 5, 1, 'Tajny Balkon', 'Moja prywatna stacja.', false, now()),
(30, 6, 2, 'Łódź Rybacka', 'Stacja mobilna na jeziorze.', true, now());

INSERT INTO sensory (id, stacja_id, typ_sensor_id, id_zewnetrzne)
VALUES (100, 10, 1, 'sensor_temp_centrum');

INSERT INTO pomiary (stacja_id, sensor_id, czas_pomiaru, wartosc)
SELECT
  10,
  100,
  NOW() - (n || ' hours')::interval,
  15 + 10 * sin(n)
FROM generate_series(0, 23) AS n;

INSERT INTO trasy_ruchome (id, stacja_id, nazwa, rozpoczeto)
VALUES (500, 30, 'Rejs Poranny', NOW() - interval '5 hours');

INSERT INTO punkty_trasy
(trasa_id, kolejnosc, czas_zapisania, szerokosc, dlugosc)
VALUES
(500, 1, NOW() - interval '4 hours', 54.10, 21.50),
(500, 2, NOW() - interval '3 hours', 54.12, 21.55),
(500, 3, NOW() - interval '2 hours', 54.15, 21.60),
(500, 4, NOW() - interval '1 hours', 54.18, 21.58);

INSERT INTO typy_stacji (id, kod, opis)
VALUES (1, 'stacjonarna', 'Stacja stacjonarna')
ON CONFLICT (id) DO NOTHING;

INSERT INTO typy_stacji (id, kod, opis)
VALUES (2, 'ruchoma', 'Stacja ruchoma')
ON CONFLICT (id) DO NOTHING;

INSERT INTO typy_sensorow (id, kod, jednostka)
VALUES (1, 'temperatura', '°C')
ON CONFLICT (id) DO NOTHING;

INSERT INTO typy_sensorow (id, kod, jednostka)
VALUES (2, 'predkosc_wiatru', 'm/s')
ON CONFLICT (id) DO NOTHING;
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (2, 'wiatr', 'km/h') ON CONFLICT (id) DO NOTHING;
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (3, 'wilgotnosc', '%') ON CONFLICT (id) DO NOTHING;
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (4, 'cisnienie', 'hPa') ON CONFLICT (id) DO NOTHING;
DELETE FROM pomiary WHERE id > 0;
DELETE FROM sensory WHERE id > 0;
DELETE FROM typy_sensorow WHERE id > 0;


INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (1, 'temperatura', '°C');
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (2, 'wiatr', 'm/s');
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (3, 'wilgotnosc', '%');
INSERT INTO typy_sensorow (id, kod, jednostka) VALUES (4, 'cisnienie', 'hPa');


CREATE TABLE ustawienia_alertow (
    user_id INT NOT NULL,
    typ_alertu VARCHAR(50) NOT NULL,
    wlaczone BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, typ_alertu)
);

CREATE TABLE IF NOT EXISTS progi_alertow (
    kod_parametru VARCHAR(50) PRIMARY KEY,
    wartosc_min FLOAT,
    wartosc_max FLOAT,
    nazwa_wyswietlana VARCHAR(100)
);


INSERT INTO progi_alertow (kod_parametru, wartosc_min, wartosc_max, nazwa_wyswietlana) VALUES
('temperatura', -10.0, 35.0, 'Temperatura'),
('wiatr', 0.0, 15.0, 'Prędkość wiatru'),
('cisnienie', 980.0, 1030.0, 'Ciśnienie atmosferyczne')
ON CONFLICT (kod_parametru) DO UPDATE SET wartosc_min = EXCLUDED.wartosc_min, wartosc_max = EXCLUDED.wartosc_max;
