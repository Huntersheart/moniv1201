/*
 * Signara Support Vest — Sensor Test
 * Board  : ESP32-S3 Feather (Adafruit)
 * Sensors: LSM6DSOX | TMP117 | BME280 | MAX30101
 * Output : Serial @ 115200 — CSV line every 5s
 *
 * CSV columns:
 *   timestamp_ms, hr_bpm, hr_avg, spo2, ir_raw,
 *   temp_c, hum_pct, pres_hpa,
 *   ax, ay, az, gx, gy, gz
 */

#include <Wire.h>
#include <Adafruit_LSM6DSOX.h>
#include <Adafruit_TMP117.h>
#include <Adafruit_BME280.h>
#include "MAX30105.h"          // SparkFun MAX3010x library
#include "heartRate.h"         // SparkFun beat-detection helper
#include "spo2_algorithm.h"    // SparkFun SpO2 algorithm

// ── I2C ──────────────────────────────────────────────────────────────────────
// ESP32-S3 Feather: default SDA=3, SCL=4 (STEMMA QT)
// If your board is different, call Wire.begin(SDA, SCL) in setup()

// ── HR / SpO2 ─────────────────────────────────────────────────────────────────
MAX30105 particleSensor;

#define RATE_SIZE 8
byte    rates[RATE_SIZE];
byte    rateSpot   = 0;
long    lastBeat   = 0;
float   beatsPerMinute = 0;
int     beatAvg    = 0;

// SpO2 algo needs 100-sample buffers
#define SPO2_BUF_LEN 100
uint32_t irBuffer[SPO2_BUF_LEN];
uint32_t redBuffer[SPO2_BUF_LEN];
int32_t  spo2       = -1;
int8_t   spo2Valid  = 0;
int32_t  heartRate  = 0;   // from SpO2 algo (cross-check)
int8_t   hrValid    = 0;

bool spo2Ready = false;    // true after first full buffer

// ── Other sensors ────────────────────────────────────────────────────────────
Adafruit_LSM6DSOX lsm;
Adafruit_TMP117   tmp;
Adafruit_BME280   bme;

bool lsmOK = false, tmpOK = false, bmeOK = false, maxOK = false;

// ── Timing ───────────────────────────────────────────────────────────────────
#define LOG_INTERVAL_MS 5000UL
unsigned long lastLog      = 0;
unsigned long spo2BufTimer = 0;
int           spo2BufIdx   = 0;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println(F("Signara Vest Sensor Test"));
  Serial.println(F("========================"));

  Wire.begin();   // default STEMMA QT pins on Feather S3

  // ── LSM6DSOX ────────────────────────────────────────────────────────────────
  if (lsm.begin_I2C()) {
    lsmOK = true;
    lsm.setAccelRange(LSM6DS_ACCEL_RANGE_2_G);
    lsm.setGyroRange(LSM6DS_GYRO_RANGE_250_DPS);
    lsm.setAccelDataRate(LSM6DS_RATE_104_HZ);
    lsm.setGyroDataRate(LSM6DS_RATE_104_HZ);
    Serial.println(F("LSM6DSOX  OK"));
  } else {
    Serial.println(F("LSM6DSOX  FAIL — check wiring"));
  }

  // ── TMP117 ──────────────────────────────────────────────────────────────────
  if (tmp.begin()) {
    tmpOK = true;
    Serial.println(F("TMP117    OK"));
  } else {
    Serial.println(F("TMP117    FAIL — check wiring"));
  }

  // ── BME280 ──────────────────────────────────────────────────────────────────
  // Try 0x76 first, fallback to 0x77
  if (bme.begin(0x76) || bme.begin(0x77)) {
    bmeOK = true;
    Serial.println(F("BME280    OK"));
  } else {
    Serial.println(F("BME280    FAIL — check wiring"));
  }

  // ── MAX30101 ────────────────────────────────────────────────────────────────
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    maxOK = true;
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x1F);   // moderate power
    particleSensor.setPulseAmplitudeIR(0x1F);
    particleSensor.setPulseAmplitudeGreen(0);     // unused
    Serial.println(F("MAX30101  OK"));
  } else {
    Serial.println(F("MAX30101  FAIL — check wiring"));
  }

  // ── CSV header ──────────────────────────────────────────────────────────────
  Serial.println();
  Serial.println(F("timestamp_ms,hr_bpm,hr_avg,spo2,ir_raw,"
                   "temp_c,hum_pct,pres_hpa,"
                   "ax_ms2,ay_ms2,az_ms2,gx_dps,gy_dps,gz_dps"));

  lastLog      = millis();
  spo2BufTimer = millis();
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
  // ── 1. Poll MAX30101 every iteration ─────────────────────────────────────
  if (maxOK) {
    // Beat-detection path (fast, for BPM display)
    long irRaw = particleSensor.getIR();
    if (checkForBeat(irRaw)) {
      long delta = millis() - lastBeat;
      lastBeat   = millis();
      beatsPerMinute = 60.0f / (delta / 1000.0f);
      if (beatsPerMinute > 20 && beatsPerMinute < 255) {
        rates[rateSpot++ % RATE_SIZE] = (byte)beatsPerMinute;
        beatAvg = 0;
        for (byte i = 0; i < RATE_SIZE; i++) beatAvg += rates[i];
        beatAvg /= RATE_SIZE;
      }
    }

    // SpO2 buffer fill path (fills 100 samples, then runs algo once)
    if (!spo2Ready) {
      redBuffer[spo2BufIdx] = particleSensor.getRed();
      irBuffer[spo2BufIdx]  = particleSensor.getIR();
      spo2BufIdx++;
      if (spo2BufIdx >= SPO2_BUF_LEN) {
        // First full buffer — calculate SpO2
        maxim_heart_rate_and_oxygen_saturation(
          irBuffer, SPO2_BUF_LEN, redBuffer,
          &spo2, &spo2Valid, &heartRate, &hrValid
        );
        spo2Ready  = true;
        spo2BufIdx = 0;
      }
    } else {
      // Sliding window: shift 25 samples, add 25 new ones
      static int refreshIdx = 0;
      redBuffer[refreshIdx % SPO2_BUF_LEN] = particleSensor.getRed();
      irBuffer[refreshIdx % SPO2_BUF_LEN]  = particleSensor.getIR();
      refreshIdx++;
      if (refreshIdx % 25 == 0) {
        maxim_heart_rate_and_oxygen_saturation(
          irBuffer, SPO2_BUF_LEN, redBuffer,
          &spo2, &spo2Valid, &heartRate, &hrValid
        );
        refreshIdx = 0;
      }
    }
  }

  // ── 2. Log every LOG_INTERVAL_MS ─────────────────────────────────────────
  if (millis() - lastLog >= LOG_INTERVAL_MS) {
    lastLog = millis();

    // Defaults
    float tempC = -999, humPct = -999, presHpa = -999;
    float ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0;
    long  irDisplay = 0;
    int   spo2Out   = spo2Valid ? (int)spo2 : -1;

    if (tmpOK) {
      sensors_event_t tmpEvent;
      tmp.getEvent(&tmpEvent);
      tempC = tmpEvent.temperature;
    }

    if (bmeOK) {
      humPct  = bme.readHumidity();
      presHpa = bme.readPressure() / 100.0f;
      // BME280 temp is ambient, not body — TMP117 is more accurate for body,
      // but keeping bme temp out of CSV to avoid confusion.
    }

    if (lsmOK) {
      sensors_event_t accel_evt, gyro_evt, temp_evt;
      lsm.getEvent(&accel_evt, &gyro_evt, &temp_evt);
      ax = accel_evt.acceleration.x;
      ay = accel_evt.acceleration.y;
      az = accel_evt.acceleration.z;
      gx = gyro_evt.gyro.x;
      gy = gyro_evt.gyro.y;
      gz = gyro_evt.gyro.z;
    }

    if (maxOK) {
      irDisplay = particleSensor.getIR();
    }

    // ── CSV line ──────────────────────────────────────────────────────────────
    Serial.print(millis());         Serial.print(',');
    Serial.print(beatsPerMinute, 1);Serial.print(',');
    Serial.print(beatAvg);          Serial.print(',');
    Serial.print(spo2Out);          Serial.print(',');
    Serial.print(irDisplay);        Serial.print(',');
    Serial.print(tempC, 2);         Serial.print(',');
    Serial.print(humPct, 1);        Serial.print(',');
    Serial.print(presHpa, 1);       Serial.print(',');
    Serial.print(ax, 3);            Serial.print(',');
    Serial.print(ay, 3);            Serial.print(',');
    Serial.print(az, 3);            Serial.print(',');
    Serial.print(gx, 3);            Serial.print(',');
    Serial.print(gy, 3);            Serial.print(',');
    Serial.println(gz, 3);

    // ── Human-readable status ─────────────────────────────────────────────────
    Serial.print(F("  HR: ")); Serial.print(beatAvg); Serial.print(F(" bpm"));
    if (spo2Valid) { Serial.print(F("  SpO2: ")); Serial.print(spo2); Serial.print('%'); }
    Serial.print(F("  Temp: ")); Serial.print(tempC, 1); Serial.print(F("C"));
    Serial.print(F("  Hum: "));  Serial.print(humPct, 0); Serial.print('%');
    Serial.print(F("  Pres: ")); Serial.print(presHpa, 0); Serial.println(F(" hPa"));
  }
}
