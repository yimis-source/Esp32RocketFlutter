import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class MotorControlScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothConnection connection;

  const MotorControlScreen({super.key, 
    required this.device,
    required this.connection,
  });

  @override
  _MotorControlScreenState createState() => _MotorControlScreenState();
}

class _MotorControlScreenState extends State<MotorControlScreen> {
  int _panAngle = 90;
  int _tiltAngle = 90;
  int _panTempAngle = 90;
  int _tiltTempAngle = 90;
  
  bool _directMotorControl = false;
  int _motor1Angle = 90;
  int _motor2Angle = 90;
  
  bool _triggerArmed = false;
  bool _triggerFired = false;
  String _triggerStatus = "Desarmado";
  
  String _statusMessage = "Conectado";
  String? _receivedData;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _setupDataListening();
    
    _sendPanTiltCommand(_panAngle, _tiltAngle);
  }

  void _setupDataListening() {
    _dataSubscription = widget.connection.input?.listen((data) {
      String message = utf8.decode(data);
      setState(() {
        _receivedData = message;
        
        if (message.startsWith("POS:")) {
          List<String> parts = message.substring(4).split(',');
          if (parts.length == 2) {
            try {
              int reportedPan = int.parse(parts[0]);
              int reportedTilt = int.parse(parts[1]);
              _statusMessage = "Posición actual: Pan: $reportedPan°, Tilt: $reportedTilt°";
            } catch (e) {
              _statusMessage = "Error al procesar datos: $e";
            }
          }
        } 
        else if (message.startsWith("TRIGGER:")) {
          if (message.contains("ARMED")) {
            _triggerArmed = true;
            _triggerFired = false;
            _triggerStatus = "Armado";
          } 
          else if (message.contains("FIRED")) {
            _triggerFired = true;
            _triggerStatus = "Accionado";
          }
          else if (message.contains("RESET")) {
            _triggerArmed = false;
            _triggerFired = false;
            _triggerStatus = "Desarmado";
          }
          else if (message.contains("ERROR")) {
            _triggerStatus = "Error: " + message.substring(14);
          }
          else if (message.contains("COMPLETED")) {
            _triggerStatus = "Ciclo completo";
            _triggerArmed = false;
            _triggerFired = false;
          }
        } 
        else {
          _statusMessage = "Mensaje recibido: $message";
        }
      });
    }, onDone: () {
      if (mounted) {
        setState(() {
          _statusMessage = "Desconectado";
        });
        Navigator.pop(context);
      }
    }, onError: (error) {
      setState(() {
        _statusMessage = "Error: $error";
      });
    });
  }

  void _sendPanTiltCommand(int pan, int tilt) {
    String command = "PT:$pan,$tilt\n";
    widget.connection.writeString(command);
    
    setState(() {
      _statusMessage = "Enviando Pan: $pan°, Tilt: $tilt°";
    });
  }
  
  void _sendMotor1Command(int angle) {
    String command = "M1:$angle\n";
    widget.connection.writeString(command);
  }
  
  void _sendMotor2Command(int angle) {
    String command = "M2:$angle\n";
    widget.connection.writeString(command);
  }

  void _armTrigger() {
    String command = "TRIGGER:ARM\n";
    widget.connection.writeString(command);
    
    setState(() {
      _triggerStatus = "Armando...";
    });
  }
  
  void _fireTrigger() {
    if (!_triggerArmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("El gatillo debe estar armado primero"))
      );
      return;
    }
    
    String command = "TRIGGER:FIRE\n";
    widget.connection.writeString(command);
    
    setState(() {
      _triggerStatus = "Accionando...";
    });
  }
  
  void _resetTrigger() {
    String command = "TRIGGER:RESET\n";
    widget.connection.writeString(command);
    
    setState(() {
      _triggerStatus = "Reseteando...";
    });
  }

  void _disconnectDevice() {
    widget.connection.dispose();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    widget.connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control de Motores (Diferencial)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Conectado a: ${widget.device.name ?? "dispositivo"}', 
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _disconnectDevice,
                  child: Text('Desconectar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(_statusMessage, style: TextStyle(fontSize: 14)),
            if (_receivedData != null)
              Text('Último mensaje: $_receivedData', style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 10),
            
            SwitchListTile(
              title: Text('Modo de control'),
              subtitle: Text(_directMotorControl ? 
                'Control directo de motores' : 
                'Control de Pan/Tilt (compensado)'),
              value: _directMotorControl,
              onChanged: (value) {
                setState(() {
                  _directMotorControl = value;
                });
              },
            ),
            
            SizedBox(height: 20),
            
            if (!_directMotorControl) 
              Column(
                children: [
                  Text('Pan (Azimut): $_panTempAngle°', style: TextStyle(fontSize: 16)),
                  Slider(
                    value: _panTempAngle.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 180,
                    label: '$_panTempAngle°',
                    onChanged: (value) {
                      setState(() {
                        _panTempAngle = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      setState(() {
                        _panAngle = value.toInt();
                      });
                      _sendPanTiltCommand(_panAngle, _tiltAngle);
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Tilt (Elevación): $_tiltTempAngle°', style: TextStyle(fontSize: 16)),
                  Slider(
                    value: _tiltTempAngle.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 180,
                    label: '$_tiltTempAngle°',
                    onChanged: (value) {
                      setState(() {
                        _tiltTempAngle = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      setState(() {
                        _tiltAngle = value.toInt();
                      });
                      _sendPanTiltCommand(_panAngle, _tiltAngle);
                    },
                  ),
                ],
              )
            else
              Column(
                children: [
                  Text('Motor 1: $_motor1Angle°', style: TextStyle(fontSize: 16)),
                  Slider(
                    value: _motor1Angle.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 180,
                    label: '$_motor1Angle°',
                    onChanged: (value) {
                      setState(() {
                        _motor1Angle = value.toInt();
                      });
                      _sendMotor1Command(_motor1Angle);
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Motor 2: $_motor2Angle°', style: TextStyle(fontSize: 16)),
                  Slider(
                    value: _motor2Angle.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 180,
                    label: '$_motor2Angle°',
                    onChanged: (value) {
                      setState(() {
                        _motor2Angle = value.toInt();
                      });
                      _sendMotor2Command(_motor2Angle);
                    },
                  ),
                ],
              ),
            
            SizedBox(height: 20),
          
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_directMotorControl) {
                      setState(() {
                        _motor1Angle = 0;
                        _motor2Angle = 0;
                      });
                      _sendMotor1Command(0);
                      _sendMotor2Command(0);
                    } else {
                      setState(() {
                        _panAngle = 0;
                        _tiltAngle = 0;
                        _panTempAngle = 0;
                        _tiltTempAngle = 0;
                      });
                      _sendPanTiltCommand(0, 0);
                    }
                  },
                  child: Text('Mínimo (0°)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_directMotorControl) {
                      setState(() {
                        _motor1Angle = 90;
                        _motor2Angle = 90;
                      });
                      _sendMotor1Command(90);
                      _sendMotor2Command(90);
                    } else {
                      setState(() {
                        _panAngle = 90;
                        _tiltAngle = 90;
                        _panTempAngle = 90;
                        _tiltTempAngle = 90;
                      });
                      _sendPanTiltCommand(90, 90);
                    }
                  },
                  child: Text('Centro (90°)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_directMotorControl) {
                      setState(() {
                        _motor1Angle = 180;
                        _motor2Angle = 180;
                      });
                      _sendMotor1Command(180);
                      _sendMotor2Command(180);
                    } else {
                      setState(() {
                        _panAngle = 180;
                        _tiltAngle = 180;
                        _panTempAngle = 180;
                        _tiltTempAngle = 180;
                      });
                      _sendPanTiltCommand(180, 180);
                    }
                  },
                  child: Text('Máximo (180°)'),
                ),
              ],
            ),
            
            SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Control de Gatillo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text('Estado: $_triggerStatus', 
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _armTrigger,
                          icon: Icon(Icons.lock_outline),
                          label: Text('Armar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _triggerArmed ? _fireTrigger : null,
                          icon: Icon(Icons.flash_on),
                          label: Text('Disparar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetTrigger,
                          icon: Icon(Icons.restart_alt),
                          label: Text('Reset'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}