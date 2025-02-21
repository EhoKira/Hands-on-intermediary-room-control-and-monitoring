import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_helper.dart'; 

// 🔹 Conexão MQTT
const String mqttServer = "URL";
const int mqttPort = 8883;
const String mqttUser = "USER";
const String mqttPassword = "SENHA";
const String mqttTopic = "atividades/registro";

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante inicialização correta do Flutter antes de chamadas assíncronas
  await DatabaseHelper.instance.initDB();
  await conectarMQTT();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('MQTT + SQLite')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getRegistros(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Nenhum registro encontrado.'));
            } else {
              final registros = snapshot.data!;
              return ListView.builder(
                itemCount: registros.length,
                itemBuilder: (context, index) {
                  final registro = registros[index];
                  return ListTile(
                    title: Text('Acesso: ${registro['acesso_autorizado'] == 1 ? 'Autorizado' : 'Negado'}'),
                    subtitle: Text('Data: ${registro['data']} - Hora: ${registro['hora']}'),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

// 🔹 Conexão MQTT
Future<void> conectarMQTT() async {
  final client = MqttServerClient(mqttServer, 'flutter_client');
  client.port = mqttPort;
  client.secure = true;
  client.setProtocolV311();
  client.logging(on: false);

  final connMessage = MqttConnectMessage()
      .withClientIdentifier('flutter_client')
      .authenticateAs(mqttUser, mqttPassword)
      .startClean();

  client.connectionMessage = connMessage;

  try {
    await client.connect();
    print('✅ Conectado ao MQTT');

    client.subscribe(mqttTopic, MqttQos.atLeastOnce);
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
      if (event != null && event.isNotEmpty) {
        final recMessage = event[0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

        print('📩 Mensagem recebida: $payload');
        salvarNoSQLite(payload);
      }
    });
  } catch (e) {
    print('❌ Erro na conexão MQTT: $e');
    client.disconnect();
  }
}

// 🔹 Salva os dados no SQLite
Future<void> salvarNoSQLite(String mensagem) async {
  try {
    final Map<String, dynamic> jsonData = jsonDecode(mensagem);
    final acessoAutorizado = jsonData['acesso_autorizado'] == true ? 1 : 0;
    final data = jsonData['data'];
    final hora = jsonData['hora'];

    await DatabaseHelper.instance.insertRegistro({
      'acesso_autorizado': acessoAutorizado,
      'data': data,
      'hora': hora,
    });
    print('✅ Registro salvo no SQLite');
  } catch (e) {
    print('❌ Erro ao salvar no SQLite: $e');
  }
}