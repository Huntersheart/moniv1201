/**
 * SIGNARA™ SUPPORT VEST — Sensores + BLE
 * Board: ESP32-S3 (QT Py o Feather)
 *
 * Sensores:
 *   ✔ LSM6DSOX  — movimiento / aceleración / giro
 *   ✔ BME280    — temperatura ambiente / humedad / presión
 *   ✔ TMP117    — temperatura corporal
 *   ✔ MAX30101  — SpO2 / frecuencia cardíaca
 *   ✔ BLE       — notifica datos a app Signara
 *
 * ── BLE ──────────────────────────────────────────────────────
 *   Nombre:       SIGNARA_VEST
 *   Service UUID: A1240001-ABCD-1234-5678-A12400000000
 *   CMD_UUID:     A1240002-ABCD-1234-5678-A12400000000  (Write)
 *   STATUS_UUID:  A1240003-ABCD-1234-5678-A12400000000  (Notify)
 *
 * ── Comandos (CMD_UUID, byte 0) ──────────────────────────────
 *   0x01  CMD_PING   — app confirma conexión (sin acción)
 *   0x02  CMD_OFF    — reservado para V1.1
 *
 * ── JSON notificado en STATUS_UUID cada 2s ───────────────────
 *   {
 *     "hr":   75,      // BPM  (-1 = sin contacto)
 *     "spo2": 98,      // %    (-1 = sin contacto)
 *     "hrv":  1,       // hr válido (0/1)
 *     "spo2v":1,       // spo2 válido (0/1)
 *     "tc":   37.2,    // temp corporal °C (TMP117)
 *     "ta":   22.1,    // temp ambiente °C (BME280)
 *     "hum":  60,      // humedad %
 *     "ax":   0.12,    // accel X m/s²
 *     "ay": -0.05,     // accel Y m/s²
 *     "az":  -9.79,    // accel Z m/s²
 *     "gx":   0.01,    // gyro X rad/s
 *     "gy":   0.00,    // gyro Y rad/s
 *     "gz":   0.00     // gyro Z rad/s
 *   }
 *
 * ── Notas ────────────────────────────────────────────────────
 *   - UUIDs DISTINTOS al collar (A123... → A124...) — crítico
 *   - Wire1.begin(SDA, SCL) requerido en ESP32-S3 bare boards
 *     Solo QT Py / Feather tienen STEMMA QT con pines fijos
 *   - MAX30101 requiere contacto con piel para lecturas válidas
 *     ir_raw > 50000 → hay contacto
 */

#include <Wire.h>
#include <Adafruit_LSM6DSOX.h>
#include <Adafruit_BME280.h>
#include <Adafruit_TMP117.h>
#include <MAX30105.h>         // SparkFun MAX3010x library
#include <heartRate.h>        // SparkFun beat-detection
#include <spo2_algorithm.h>   // SparkFun SpO2
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── Sensores ──────────────────────────────────────────────────
Adafruit_LSM6DSOX lsm;
Adafruit_BME280   bme;
Adafruit_TMP117   tmp;
MAX30105          maxSensor;

bool lsmOK = false, bmeOK = false, tmpOK = false, maxOK = false;

// ── MAX30101 — buffers SpO2 ───────────────────────────────────
#define MAX_BUF_LEN 100
uint32_t irBuffer[MAX_BUF_LEN];
uint32_t redBuffer[MAX_BUF_LEN];
int32_t  spo2Value      = -1;
int8_t   spo2Valid      = 0;
int32_t  heartRateValue = -1;
int8_t   hrValid        = 0;
bool     maxReady       = false;
unsigned long lastMaxRead = 0;
#define MAX_SAMPLE_INTERVAL 40UL   // ~25 Hz

// ── BLE — UUIDs (distintos al collar A123→A124) ───────────────
#define BLE_DEVICE_NAME  "SIGNARA_VEST"
#define SERVICE_UUID     "A1240001-ABCD-1234-5678-A12400000000"
#define CMD_UUID         "A1240002-ABCD-1234-5678-A12400000000"
#define STATUS_UUID      "A1240003-ABCD-1234-5678-A12400000000"

// ── BLE — Comandos ────────────────────────────────────────────
#define CMD_PING  0x01
#define CMD_OFF   0x02

// ── BLE — Estado ──────────────────────────────────────────────
BLEServer*         pServer = nullptr;
BLECharacteristic* pCmd    = nullptr;
BLECharacteristic* pStatus = nullptr;
bool               bleConnected = false;

// ── Timing ───────────────────────────────────────────────────
unsigned long lastStatusNotify = 0;
#define STATUS_INTERVAL 2000UL


// ════════════════════════════════════════════════════════════
//  BLE CALLBACKS
// ════════════════════════════════════════════════════════════

class VestServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    bleConnected = true;
    Serial.println("BLE: App conectada ✔");
  }
  void onDisconnect(BLEServer*) override {
    bleConnected = false;
    BLEDevice::startAdvertising();
    Serial.println("BLE: Desconectado — advertising reiniciado");
  }
};

class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String val = pChar->getValue();
    if (val.length() == 0) return;
    uint8_t cmd = (uint8_t)val[0];
    Serial.printf("BLE CMD recibido: 0x%02X\n", cmd);
    // CMD_PING — sin acción (solo confirma conexión)
    // CMD_OFF  — reservado V1.1
  }
};


// ════════════════════════════════════════════════════════════
//  BLE SETUP
// ════════════════════════════════════════════════════════════

void setupBLE() {
  BLEDevice::init(BLE_DEVICE_NAME);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new VestServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Característica de comandos — Write
  pCmd = pService->createCharacteristic(
    CMD_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pCmd->setCallbacks(new CmdCallbacks());

  // Característica de status — Notify
  pStatus = pService->createCharacteristic(
    STATUS_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatus->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID);
  pAdv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE: Advertising → " BLE_DEVICE_NAME);
}


// ════════════════════════════════════════════════════════════
//  SETUP
// ════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("─── SIGNARA VEST BOOT ───");

  // ── I2C ──────────────────────────────────────────────────
  // QT Py / Feather ESP32-S3: STEMMA QT = Wire por default
  // Si usas un ESP32-S3 bare board, cambia a: Wire1.begin(SDA_PIN, SCL_PIN)
  Wire.begin();

  // ── LSM6DSOX ─────────────────────────────────────────────
  if (lsm.begin_I2C()) {
    lsmOK = true;
    lsm.setAccelRange(LSM6DS_ACCEL_RANGE_2_G);
    lsm.setGyroRange(LSM6DS_GYRO_RANGE_250_DPS);
    lsm.setAccelDataRate(LSM6DS_RATE_104_HZ);
    lsm.setGyroDataRate(LSM6DS_RATE_104_HZ);
    Serial.println("LSM6DSOX  OK");
  } else {
    Serial.println("[!] LSM6DSOX no detectado");
  }

  // ── BME280 ───────────────────────────────────────────────
  if (bme.begin(0x76) || bme.begin(0x77)) {
    bmeOK = true;
    Serial.println("BME280    OK");
  } else {
    Serial.println("[!] BME280 no detectado");
  }

  // ── TMP117 ───────────────────────────────────────────────
  if (tmp.begin()) {
    tmpOK = true;
    Serial.println("TMP117    OK");
  } else {
    Serial.println("[!] TMP117 no detectado");
  }

  // ── MAX30101 ─────────────────────────────────────────────
  if (maxSensor.begin(Wire, I2C_SPEED_FAST)) {
    byte ledBrightness = 60;
    byte sampleAverage = 4;
    byte ledMode       = 2;   // IR + Rojo (necesario para SpO2)
    int  sampleRate    = 100;
    int  pulseWidth    = 411;
    int  adcRange      = 4096;
    maxSensor.setup(ledBrightness, sampleAverage, ledMode,
                    sampleRate, pulseWidth, adcRange);
    maxSensor.setPulseAmplitudeRed(0x0A);
    maxSensor.setPulseAmplitudeGreen(0);

    // Pre-llenar buffer para inicializar algoritmo SpO2
    Serial.println("MAX30101  inicializando buffer...");
    for (byte i = 0; i < MAX_BUF_LEN; i++) {
      while (!maxSensor.available()) maxSensor.check();
      redBuffer[i] = maxSensor.getRed();
      irBuffer[i]  = maxSensor.getIR();
      maxSensor.nextSample();
    }
    maxim_heart_rate_and_oxygen_saturation(
      irBuffer, MAX_BUF_LEN, redBuffer,
      &spo2Value, &spo2Valid, &heartRateValue, &hrValid
    );
    maxOK    = true;
    maxReady = true;
    Serial.println("MAX30101  OK");
  } else {
    Serial.println("[!] MAX30101 no detectado");
  }

  // ── BLE ──────────────────────────────────────────────────
  setupBLE();

  Serial.println("─── Sistema listo ───\n");
}


// ════════════════════════════════════════════════════════════
//  LOOP
// ════════════════════════════════════════════════════════════

void loop() {
  unsigned long now = millis();

  // ── MAX30101: lectura no-bloqueante ~25 Hz ────────────────
  if (maxReady && (now - lastMaxRead >= MAX_SAMPLE_INTERVAL)) {
    lastMaxRead = now;
    maxSensor.check();
    if (maxSensor.available()) {
      // Sliding window — descarta muestra más antigua
      for (byte i = 1; i < MAX_BUF_LEN; i++) {
        redBuffer[i - 1] = redBuffer[i];
        irBuffer[i - 1]  = irBuffer[i];
      }
      redBuffer[MAX_BUF_LEN - 1] = maxSensor.getRed();
      irBuffer[MAX_BUF_LEN - 1]  = maxSensor.getIR();
      maxSensor.nextSample();
      maxim_heart_rate_and_oxygen_saturation(
        irBuffer, MAX_BUF_LEN, redBuffer,
        &spo2Value, &spo2Valid, &heartRateValue, &hrValid
      );
    }
  }

  // ── Leer LSM6DSOX ────────────────────────────────────────
  sensors_event_t accel, gyro, tempLsm;
  if (lsmOK) lsm.getEvent(&accel, &gyro, &tempLsm);

  // ── Leer TMP117 ──────────────────────────────────────────
  sensors_event_t tempBody;
  if (tmpOK) tmp.getEvent(&tempBody);

  // ── Leer BME280 ──────────────────────────────────────────
  float tempAmbient = bmeOK ? bme.readTemperature() : -999;
  float humidity    = bmeOK ? bme.readHumidity()    : -999;
  float pressure    = bmeOK ? bme.readPressure() / 100.0F : -999;

  // ── BLE Notify cada 2s ────────────────────────────────────
  if (bleConnected && (now - lastStatusNotify >= STATUS_INTERVAL)) {
    lastStatusNotify = now;

    long irRaw = maxOK ? maxSensor.getIR() : 0;
    bool contact = (irRaw > 50000);  // sin contacto → valores no válidos

    // Filtrar lecturas de HR fuera del rango fisiológico canino (40–220 BPM)
    // El algoritmo SparkFun puede reportar artefactos >220 con contacto pobre
    int hrOut = -1;
    if (contact && hrValid && heartRateValue >= 40 && heartRateValue <= 220) {
      hrOut = (int)heartRateValue;
    } else if (contact && heartRateValue > 0) {
      hrOut = -1;  // contacto presente pero HR fuera de rango → no reportar
    }

    char buf[256];
    snprintf(buf, sizeof(buf),
      "{\"hr\":%d,\"spo2\":%d,\"hrv\":%d,\"spo2v\":%d,"
      "\"tc\":%.1f,\"ta\":%.1f,\"hum\":%.0f,"
      "\"ax\":%.2f,\"ay\":%.2f,\"az\":%.2f,"
      "\"gx\":%.2f,\"gy\":%.2f,\"gz\":%.2f}",
      contact ? hrOut : -1,
      contact ? (int)spo2Value      : -1,
      contact ? (int)hrValid        : 0,
      contact ? (int)spo2Valid      : 0,
      tmpOK  ? tempBody.temperature : -999.0f,
      tempAmbient,
      humidity,
      lsmOK ? accel.acceleration.x : 0.0f,
      lsmOK ? accel.acceleration.y : 0.0f,
      lsmOK ? accel.acceleration.z : 0.0f,
      lsmOK ? gyro.gyro.x          : 0.0f,
      lsmOK ? gyro.gyro.y          : 0.0f,
      lsmOK ? gyro.gyro.z          : 0.0f
    );

    pStatus->setValue((uint8_t*)buf, strlen(buf));
    pStatus->notify();
  }

  // ── Serial debug ──────────────────────────────────────────
  long irDebug = maxOK ? maxSensor.getIR() : 0;
  Serial.printf(
    "BLE:%d | HR:%d(%s) SpO2:%d(%s) IR:%ld | Tc:%.1f Ta:%.1f Hum:%.0f | AccZ:%.2f\n",
    bleConnected,
    (int)heartRateValue, hrValid   ? "OK" : "?",
    (int)spo2Value,      spo2Valid ? "OK" : "?",
    irDebug,
    tmpOK  ? tempBody.temperature   : -999.0f,
    tempAmbient, humidity,
    lsmOK  ? accel.acceleration.z   : 0.0f
  );

  delay(1000);
}
