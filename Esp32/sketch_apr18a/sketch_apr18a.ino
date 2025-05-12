#include <BluetoothSerial.h>
#include <ESP32Servo.h>

// Comprobación si Bluetooth está habilitado
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth no está habilitado! Por favor habilítalo en menuconfig
#endif

// Definición de pines para los servos
#define MOTOR1_PIN 14  // Motor para control diferencial 1
#define MOTOR2_PIN 27  // Motor para control diferencial 2

// Objetos para los servomotores
Servo motor1;
Servo motor2;

// Objeto BluetoothSerial
BluetoothSerial SerialBT;

// Buffer para recibir comandos
String commandBuffer = "";

// Variables para controlar los ángulos actuales
int currentMotor1Angle = 90;
int currentMotor2Angle = 90;

// Variables para controlar la posición real del sistema
int currentPanAngle = 90;    // Azimut (0-180)
int currentTiltAngle = 90;   // Elevación (0-180)

void setup() {
  Serial.begin(115200);
  
  // Inicializar servomotores
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  motor1.setPeriodHertz(50);
  motor2.setPeriodHertz(50);
  motor1.attach(MOTOR1_PIN, 500, 2400);
  motor2.attach(MOTOR2_PIN, 500, 2400);
  
  // Posición inicial centrada
  motor1.write(90);
  motor2.write(90);

  // Iniciar Bluetooth Serial
  SerialBT.begin("ESP32_PanTilt");
  Serial.println("Bluetooth iniciado, listo para emparejar");
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
  
  // Verificar si hay datos disponibles por Serial
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
  
  delay(20);
}

void processCommand(String command) {
  Serial.print("Comando recibido: ");
  Serial.println(command);
  
  // Procesar comandos directos de motores
  if (command.startsWith("M1:")) {
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    currentMotor1Angle = angle;
    motor1.write(angle);
    
    // Calcula la posición real pan/tilt basada en los ángulos de los motores
    calculatePanTiltFromMotors();
    sendFeedback();
  } 
  else if (command.startsWith("M2:")) {
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    currentMotor2Angle = angle;
    motor2.write(angle);
    
    // Calcula la posición real pan/tilt basada en los ángulos de los motores
    calculatePanTiltFromMotors();
    sendFeedback();
  }
  // Nuevo comando para establecer directamente ángulos pan/tilt
  else if (command.startsWith("PT:")) {
    // Formato esperado: PT:pan,tilt
    int commaIndex = command.indexOf(',', 3);
    if (commaIndex > 0) {
      int panAngle = command.substring(3, commaIndex).toInt();
      int tiltAngle = command.substring(commaIndex + 1).toInt();
      
      // Limitar a rangos válidos
      panAngle = constrain(panAngle, 0, 180);
      tiltAngle = constrain(tiltAngle, 0, 180);
      
      // Actualizar los valores actuales
      currentPanAngle = panAngle;
      currentTiltAngle = tiltAngle;
      
      // Convertir ángulos pan/tilt a posiciones de motor diferencial
      calculateMotorsFromPanTilt();
      
      // Aplicar las posiciones a los motores
      motor1.write(currentMotor1Angle);
      motor2.write(currentMotor2Angle);
      QW
      sendFeedback();
    }
  }
}

// Convierte los ángulos pan/tilt deseados a ángulos de los motores diferenciales
void calculateMotorsFromPanTilt() {
  // Fórmulas del sistema diferencial:
  // M1 = (Pan + Tilt) / 2
  // M2 = (Pan - Tilt) / 2 + 90
  
  currentMotor1Angle = (currentPanAngle + currentTiltAngle) / 2;
  currentMotor2Angle = (currentPanAngle - currentTiltAngle) / 2 + 90;
  
  // Asegurar que los valores estén en el rango permitido
  currentMotor1Angle = constrain(currentMotor1Angle, 0, 180);
  currentMotor2Angle = constrain(currentMotor2Angle, 0, 180);
  
  Serial.print("Motor 1: ");
  Serial.print(currentMotor1Angle);
  Serial.print(", Motor 2: ");
  Serial.println(currentMotor2Angle);
}

// Calcula la posición pan/tilt a partir de las posiciones de los motores
void calculatePanTiltFromMotors() {
  // Inversión de las fórmulas diferenciales:
  // Pan = M1 - M2 + 90
  // Tilt = 2*M1 - Pan
  
  int panAngle = currentMotor1Angle - currentMotor2Angle + 90;
  int tiltAngle = 2 * currentMotor1Angle - panAngle;
  
  // Asegurar valores dentro del rango
  currentPanAngle = constrain(panAngle, 0, 180);
  currentTiltAngle = constrain(tiltAngle, 0, 180);
}

// Envía información de retroalimentación al cliente
void sendFeedback() {
  String feedback = "POS:";
  feedback += String(currentPanAngle);
  feedback += ",";
  feedback += String(currentTiltAngle);
  
  Serial.println(feedback);
  SerialBT.println(feedback);
}