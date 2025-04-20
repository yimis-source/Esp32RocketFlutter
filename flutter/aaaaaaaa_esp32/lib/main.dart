import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'motor_control_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Motores Bluetooth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothScanScreen(),
    );
  }
}

class BluetoothScanScreen extends StatefulWidget {
  @override
  _BluetoothScanScreenState createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  final FlutterBlueClassic bluetooth = FlutterBlueClassic();
  
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? _adapterStateSubscription;
  
  final Set<BluetoothDevice> _scanResults = {};
  StreamSubscription? _scanSubscription;
  
  bool _isScanning = false;
  int? _connectingToIndex;
  StreamSubscription? _scanningStateSubscription;
  
  String _statusMessage = "Preparando...";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _statusMessage = "Solicitando permisos...";
    });
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        print("Permiso no concedido: $permission");
      }
    });

    if (allGranted) {
      setState(() {
        _statusMessage = "Permisos concedidos";
      });
      _initBluetooth();
    } else {
      setState(() {
        _statusMessage = "Permisos denegados. No se puede continuar.";
      });
    }
  }

  Future<void> _initBluetooth() async {
    try {
      _adapterState = await bluetooth.adapterStateNow;
      
      _adapterStateSubscription = bluetooth.adapterState.listen((current) {
        if (mounted) setState(() => _adapterState = current);
      });
      
      _scanSubscription = bluetooth.scanResults.listen((device) {
        if (mounted) setState(() => _scanResults.add(device));
      });
      
      _scanningStateSubscription = bluetooth.isScanning.listen((isScanning) {
        if (mounted) setState(() => _isScanning = isScanning);
      });
      
      setState(() {
        _statusMessage = _adapterState == BluetoothAdapterState.on 
            ? "Bluetooth activado. Listo para buscar dispositivos." 
            : "Bluetooth está desactivado. Por favor, actívalo.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error al inicializar Bluetooth: $e";
      });
    }
  }

  void _startScan() {
    if (_isScanning) {
      bluetooth.stopScan();
    } else {
      setState(() {
        _scanResults.clear();
        _statusMessage = "Buscando dispositivos...";
      });
      bluetooth.startScan();
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, int index) async {
    setState(() {
      _connectingToIndex = index;
      _statusMessage = "Conectando a ${device.name ?? 'dispositivo'}...";
    });

    try {
      BluetoothConnection? connection = await bluetooth.connect(device.address);
      
      if (connection != null && connection.isConnected) {
        if (mounted) {
          setState(() => _connectingToIndex = null);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MotorControlScreen(
                device: device,
                connection: connection,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectingToIndex = null;
          _statusMessage = "Error de conexión: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al conectar con ${device.name ?? 'el dispositivo'}")),
        );
      }
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDevice> devices = _scanResults.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Control de Motores Bluetooth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text("Estado del Bluetooth"),
              subtitle: const Text("Toca para activar"),
              trailing: Text(_adapterState.name),
              leading: const Icon(Icons.settings_bluetooth),
              onTap: () => bluetooth.turnOn(),
            ),
            SizedBox(height: 10),
            Text(_statusMessage, 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text('Dispositivos disponibles:'),
            Expanded(
              child: devices.isEmpty 
                  ? Center(child: Text('No se encontraron dispositivos')) 
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return ListTile(
                          title: Text("${device.name ?? "Sin nombre"} (${device.address})"),
                          subtitle: Text("Estado: ${device.bondState.name}, Tipo: ${device.type.name}"),
                          trailing: index == _connectingToIndex
                              ? CircularProgressIndicator()
                              : Text("${device.rssi} dBm"),
                          onTap: () => _connectToDevice(device, index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startScan,
        label: Text(_isScanning ? "Escaneando..." : "Buscar dispositivos"),
        icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
      ),
    );
  }
}