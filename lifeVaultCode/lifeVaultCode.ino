#include <Wire.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>  // Certifique-se de incluir a biblioteca para conexão segura
#include <Adafruit_PN532.h>
#include <PubSubClient.h>
#include "DHT.h"
#include <ESP32Servo.h>


// Configuração do Wi-Fi
const char* ssid = "SSID";
const char* password = "PASSWORD";

#define SERVO_MOTOR 27 
// Configuração do sensor PN532 via I2C
#define led_vermelho 33 
#define led_verde 32
#define SDA_PIN 21
#define SCL_PIN 22
#define DHT_PIN 4
#define DHTTYPE DHT11
DHT dht(DHT_PIN, DHTTYPE);
Adafruit_PN532 nfc(SDA_PIN, SCL_PIN);
Servo servo1;

// Configuração do Broker MQTT
const char* mqtt_server = "URL SERVER";  // Broker MQTT
const int mqtt_port = 8883;  // Porta MQTT com SSL/TLS
const char* mqtt_username = "USERNAME_MQTT";  // Nome de usuário MQTT
const char* mqtt_password = "PASSWORD_MQTT";  // Senha do MQTT
const char* mqtt_registro_movimento = "atividades/registro";  // Tópico para cadastro
const char* mqtt_temperatura = "atividades/temperatura";  // Tópico para cadastro

WiFiClientSecure espClient;  // Conexão segura com o MQTT
PubSubClient client(espClient);  // Cliente MQTT

// Função para conectar ao MQTT
void reconnect() {
  while (!client.connected()) {
    Serial.print("Tentando conectar ao MQTT...");
    if (client.connect("ESP32Client", mqtt_username, mqtt_password)) {
      Serial.println("Conectado ao Broker MQTT!");
    } else {
      Serial.print("Falha na conexão. Status: ");
      Serial.println(client.state());
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(led_vermelho, OUTPUT);
  pinMode(led_verde, OUTPUT);
  digitalWrite(led_vermelho, HIGH);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Conectando ao WiFi...");
  }
  Serial.print("IP_Address: ");
  Serial.println(WiFi.localIP());

  // Inicializa PN532
  nfc.begin();
  if (!nfc.getFirmwareVersion()) {
    Serial.println("PN532 nao detectado");
    while (1);
  }
  nfc.SAMConfig();

  // Configuração MQTT
  espClient.setInsecure();  // Usa conexão sem verificação de certificado (se necessário, configure o certificado)
  client.setServer(mqtt_server, mqtt_port);
  dht.begin();
  Serial.println(F("DHT11 Iniciado!"));
  servo1.attach(SERVO_MOTOR);
}

void cartao_valido_aproximado(){
  digitalWrite(led_vermelho, LOW);
  digitalWrite(led_verde, HIGH);
  delay(2000);
  digitalWrite(led_verde, LOW);
  digitalWrite(led_vermelho, HIGH);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  delay(2000);

  uint8_t success = nfc.inListPassiveTarget();

  if(success > 0){
    uint8_t uid[7];
    uint8_t uidLength;

    if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength)) {
      String tag = "";
      for (uint8_t i = 0; i < uidLength; i++) {
        tag += String(uid[i], HEX);
      }
      Serial.println("Tag detectada: " + tag);

      // Preparar os dados em formato JSON para enviar ao MQTT
      String postData;
      if (tag == "b31c5510") {
        cartao_valido_aproximado();
        abrirPorta();
        postData = "{\"tag\":\"" + tag + "\", \"descricao\":\"Registro\",}";
      } 

      // Enviar os dados para o broker MQTT
      Serial.println("Enviando para o MQTT: " + postData);
      client.publish(mqtt_registro_movimento, postData.c_str());

      delay(2000);  // Aguarde antes de nova leitura
    }
  }

  // Leitura do DHT11
  float temperatura = dht.readTemperature();  // Celsius
  float umidade = dht.readHumidity();

  // Verifica se a leitura falhou
  if (isnan(temperatura) || isnan(umidade)) {
    Serial.println(F("Falha na leitura do DHT!"));
    return;
  }

  // Exibe os dados no Serial Monitor
  Serial.printf("Temperatura: %.2f°C / Umidade: %.2f%%\n", temperatura, umidade);

}

void abrirPorta(){
  servo1.write(0);    // Move o servo para a posição 0
  delay(1000);          // Espera 1 segundo
  servo1.write(90);   // Move o servo para a posição 90
  delay(1000);          // Espera 1 segundo
}
