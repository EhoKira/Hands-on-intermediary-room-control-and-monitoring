import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String server = '6b855318cbf249028a44d6a8610f73e9.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'hivemq.webclient.1739023622070';
  final String password = 'Fuj0h:W>T*s;A5BOqf37';
  final String clientId = 'Lucas87';

  late MqttServerClient client;

  Future<void> connect() async {
    client = MqttServerClient.withPort(server, clientId, port);
    client.secure = true; // Ativar SSL/TLS
    client.securityContext = SecurityContext.defaultContext; // Definir o contexto de segurança

    client.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
      print('Conectado ao MQTT!');

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('Recebido: $payload');
      });

    } on NoConnectionException catch (e) {
      print('Erro de conexão: $e');
      client.disconnect();
    } on SocketException catch (e) {
      print('Erro de socket: $e');
      client.disconnect();
    }
  }

  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    client.disconnect();
  }
}