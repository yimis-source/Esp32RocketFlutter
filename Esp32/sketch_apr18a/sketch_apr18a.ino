#include <BluetoothSerial.h>
#include <ESP32Servo.h>

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth no está habilitado! Por favor habilítalo en menuconfig
#endif

#define MOTOR1_PIN 14
#define MOTOR2_PIN 27
#define TRIGGER_PIN 12

Servo motor1;
Servo motor2;
Servo triggerMotor;

BluetoothSerial SerialBT;

String commandBuffer = "";

int currentMotor1Angle = 90;
int currentMotor2Angle = 90;
int currentTriggerAngle = 0;

int currentPanAngle = 90;
int currentTiltAngle = 90;

bool triggerArmed = false;
bool triggerFired = false;

void setup() {
  Serial.begin(115200);
  
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  
  motor1.setPeriodHertz(50);
  motor2.setPeriodHertz(50);
  triggerMotor.setPeriodHertz(50);
  
  motor1.attach(MOTOR1_PIN, 500, 2400);
  motor2.attach(MOTOR2_PIN, 500, 2400);
  triggerMotor.attach(TRIGGER_PIN, 500, 2400);
  
  motor1.write(90);
  motor2.write(90);
  triggerMotor.write(0);
  currentTriggerAngle = 0;

  SerialBT.begin("ESP32_PanTilt");
  Serial.println("Bluetooth iniciado, listo para emparejar");
}

void loop() {
  if (SerialBT.available()) {
    char inChar = SerialBT.read();
    
    if (inChar == '\n') {
      processCommand(commandBuffer);
      commandBuffer = "";
    } else {
      commandBuffer += inChar;
    }
  }
  
  if (Serial.available()) {
    char inChar = Serial.read();
    
    if (inChar == '\n') {
      processCommand(commandBuffer);
      commandBuffer = "";
    } else {
      commandBuffer += inChar;
    }
  }
  
  delay(20);
}

void processCommand(String command) {
  Serial.print("Comando recibido: ");
  Serial.println(command);
  
  if (command.startsWith("M1:")) {
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    currentMotor1Angle = angle;
    motor1.write(angle);
    
    calculatePanTiltFromMotors();
    sendFeedback();
  } 
  else if (command.startsWith("M2:")) {
    int angle = command.substring(3).toInt();
    angle = constrain(angle, 0, 180);
    currentMotor2Angle = angle;
    motor2.write(angle);
    
    calculatePanTiltFromMotors();
    sendFeedback();
  }
  else if (command.startsWith("PT:")) {
    int commaIndex = command.indexOf(',', 3);
    if (commaIndex > 0) {
      int panAngle = command.substring(3, commaIndex).toInt();
      int tiltAngle = command.substring(commaIndex + 1).toInt();
      
      panAngle = constrain(panAngle, 0, 180);
      tiltAngle = constrain(tiltAngle, 0, 180);
      
      currentPanAngle = panAngle;
      currentTiltAngle = tiltAngle;
      
      calculateMotorsFromPanTilt();
      
      motor1.write(currentMotor1Angle);
      motor2.write(currentMotor2Angle);
      
      sendFeedback();
    }
  }
  else if (command.startsWith("TRIGGER:")) {
    if (command.indexOf("ARM") > 0) {
      triggerArmed = true;
      triggerFired = false;
      triggerMotor.write(45);
      currentTriggerAngle = 45;
      
      SerialBT.println("TRIGGER:ARMED");
      Serial.println("Gatillo armado");
    } 
    else if (command.indexOf("FIRE") > 0) {
      if (triggerArmed) {
        triggerMotor.write(180);
        currentTriggerAngle = 180;
        triggerFired = true;
        
        SerialBT.println("TRIGGER:FIRED");
        Serial.println("Gatillo accionado");
        
        delay(500);
        
        triggerMotor.write(0);
        currentTriggerAngle = 0;
        triggerArmed = false;
        
        SerialBT.println("TRIGGER:COMPLETED");
      } else {
        SerialBT.println("TRIGGER:ERROR_NOT_ARMED");
      }
    }
    else if (command.indexOf("RESET") > 0) {
      triggerArmed = false;
      triggerFired = false;
      triggerMotor.write(0);
      currentTriggerAngle = 0;
      
      SerialBT.println("TRIGGER:RESET");
      Serial.println("Gatillo reseteado");
    }
    else if (command.startsWith("TRIGGER:POS:")) {
      int angle = command.substring(12).toInt();
      angle = constrain(angle, 0, 180);
      triggerMotor.write(angle);
      currentTriggerAngle = angle;
      
      SerialBT.println("TRIGGER:POS:" + String(angle));
    }
  }
}

void calculateMotorsFromPanTilt() {
  currentMotor1Angle = (currentPanAngle + currentTiltAngle) / 2;
  currentMotor2Angle = (currentPanAngle - currentTiltAngle) / 2 + 90;
  
  currentMotor1Angle = constrain(currentMotor1Angle, 0, 180);
  currentMotor2Angle = constrain(currentMotor2Angle, 0, 180);
  
  Serial.print("Motor 1: ");
  Serial.print(currentMotor1Angle);
  Serial.print(", Motor 2: ");
  Serial.println(currentMotor2Angle);
}

void calculatePanTiltFromMotors() {
  int panAngle = currentMotor1Angle - currentMotor2Angle + 90;
  int tiltAngle = 2 * currentMotor1Angle - panAngle;
  
  currentPanAngle = constrain(panAngle, 0, 180);
  currentTiltAngle = constrain(tiltAngle, 0, 180);
}

void sendFeedback() {
  String feedback = "POS:";
  feedback += String(currentPanAngle);
  feedback += ",";
  feedback += String(currentTiltAngle);
  
  Serial.println(feedback);
  SerialBT.println(feedback);
}