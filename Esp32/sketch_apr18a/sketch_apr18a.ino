#include <BluetoothSerial.h>
#include <ESP32Servo.h>

// Comprobación si Bluetooth está habilitado
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth no está habilitado! Por favor habilítalo en menuconfig
#endif

// Definición de pines para los servos
#define MOTOR1_PIN 14
#define MOTOR2_PIN 27

// Objetos para los servomotores
Servo motor1;
Servo motor2;

// Objeto BluetoothSerial
BluetoothSerial SerialBT;

// Buffer para recibir comandos
String commandBuffer = "";

void setup() {
  Serial.begin(115200);
  
  // Inicializar servomotores
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  motor1.setPeriodHertz(50);
  motor2.setPeriodHertz(50);
  motor1.attach(MOTOR1_PIN, 500, 2400);
  motor2.attach(MOTOR2_PIN, 500, 2400);
  motor1.write(90);
  motor2.write(90);
  Serial.println("Servomotores inicializados en posición 90°");

  // Iniciar Bluetooth Serial
  String deviceName = "ESP32_MotorControl";
  SerialBT.begin(deviceName);
  Serial.println("Bluetooth Serial iniciado con nombre: " + deviceName);
  Serial.println("Ahora puedes emparejar tu dispositivo!");
  Serial.println("Para cambiar el ángulo de los motores, envía:");
  Serial.println("  M1:ángulo - para el motor 1 (ángulo de 0 a 180)");
  Serial.println("  M2:ángulo - para el motor 2 (ángulo de 0 a 180)");
}

void loop() {
  // Verificar si hay datos disponibles por Bluetooth
  if (SerialBT.available()) {
    char inChar = SerialBT.read();
    
    // Si es un salto de línea, procesar el comando
    if (inChar == '\n') {
      processCommand(commandBuffer);
      commandBuffer = "";
    } else {
      // Añadir el carácter al buffer
      commandBuffer += inChar;
    }
  }
  
  // Verificar si hay datos disponibles por Serial (para depuración)
  if (Serial.available()) {
    char inChar = Serial.read();
    
    // Si es un salto de línea, procesar el comando
    if (inChar == '\n') {
      processCommand(commandBuffer);
      commandBuffer = "";
    } else {
      // Añadir el carácter al buffer
      commandBuffer += inChar;
    }
  }
  
  // Para evitar bloqueos en el bucle principal
  delay(20);
}

void processCommand(String command) {
  Serial.print("Comando recibido: ");
  Serial.println(command);
  
  // Verificar formato: M1:ángulo o M2:ángulo
  if (command.startsWith("M1:")) {
    // Obtener el ángulo después de "M1:"
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    motor1.write(angle);
    Serial.print("Motor 1 ajustado a: ");
    Serial.println(angle);
    
    // Responder al cliente (opcional)
    SerialBT.print("Motor 1 ajustado a: ");
    SerialBT.println(angle);
  } 
  else if (command.startsWith("M2:")) {
    // Obtener el ángulo después de "M2:"
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    motor2.write(angle);
    Serial.print("Motor 2 ajustado a: ");
    Serial.println(angle);
    
    // Responder al cliente (opcional)
    SerialBT.print("Motor 2 ajustado a: ");
    SerialBT.println(angle);
  }
  else {
    Serial.println("Comando no reconocido");
    SerialBT.println("Comando no reconocido. Use M1:ángulo o M2:ángulo");
  }
}