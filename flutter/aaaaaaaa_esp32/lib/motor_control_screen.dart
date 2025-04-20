import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class MotorControlScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothConnection connection;

  MotorControlScreen({
    required this.device,
    required this.connection,
  });

  @override
  _MotorControlScreenState createState() => _MotorControlScreenState();
}

class _MotorControlScreenState extends State<MotorControlScreen> {
  int _motor1Angle = 90;
  int _motor2Angle = 90;
  String _statusMessage = "Conectado";
  String? _receivedData;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _setupDataListening();
    
    _sendMotor1Angle(_motor1Angle);
    _sendMotor2Angle(_motor2Angle);
  }

  void _setupDataListening() {
    // Escuchar datos entrantes
    _dataSubscription = widget.connection.input?.listen((data) {
      String message = utf8.decode(data);
      setState(() {
        _receivedData = message;
        _statusMessage = "Mensaje recibido: $message";
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

  void _sendMotor1Angle(int angle) {
   
    String command = "M1:$angle\n";
    widget.connection.writeString(command);
  }

  void _sendMotor2Angle(int angle) {
    
    String command = "M2:$angle\n";
    widget.connection.writeString(command);
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
        title: Text('Control de Motores'),
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
            SizedBox(height: 20),
            Text(_statusMessage, style: TextStyle(fontSize: 14)),
            if (_receivedData != null)
              Text('Último mensaje: $_receivedData', style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 20),
            Text('Ángulo Motor 1: $_motor1Angle°', style: TextStyle(fontSize: 16)),
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
                _sendMotor1Angle(_motor1Angle);
              },
            ),
            SizedBox(height: 30),
            Text('Ángulo Motor 2: $_motor2Angle°', style: TextStyle(fontSize: 16)),
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
                _sendMotor2Angle(_motor2Angle);
              },
            ),
            SizedBox(height: 30),
          
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _motor1Angle = 0;
                      _motor2Angle = 0;
                    });
                    _sendMotor1Angle(0);
                    _sendMotor2Angle(0);
                  },
                  child: Text('Mínimo (0°)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _motor1Angle = 90;
                      _motor2Angle = 90;
                    });
                    _sendMotor1Angle(90);
                    _sendMotor2Angle(90);
                  },
                  child: Text('Centro (90°)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _motor1Angle = 180;
                      _motor2Angle = 180;
                    });
                    _sendMotor1Angle(180);
                    _sendMotor2Angle(180);
                  },
                  child: Text('Máximo (180°)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}