import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'database_helper.dart';
import 'package:flutter/services.dart';  // Import adicionado aqui
import 'package:permission_handler/permission_handler.dart';

// 🔹 Configuração MQTT
const String mqttServer = "URL";
const int mqttPort = 8883;
const String mqttUser = "USER";
const String mqttPassword = "PASSWORD";
const String mqttTopicRegistros = "atividades/registro";
const String mqttTopicAlertas = "atividades/alerta";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.request();  // Solicita permissão para notificações
  await DatabaseHelper.instance.initDB();
  await NotificacaoHelper.initNotificacoes();
  await conectarMQTT();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _registros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistros();
  }

  Future<void> _loadRegistros() async {
    final registros = await DatabaseHelper.instance.getRegistros();
    setState(() {
      _registros = registros;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Life Vault')),
        body: _currentIndex == 0 ? _buildHistoricoScreen() : _buildBoasVindasScreen(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Boas-Vindas'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricoScreen() {
    return RefreshIndicator(
      onRefresh: _loadRegistros,
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _registros.isEmpty
              ? Center(child: Text('Nenhum registro encontrado.'))
              : ListView.builder(
                  itemCount: _registros.length,
                  itemBuilder: (context, index) {
                    final registro = _registros[index];
                    return ListTile(
                      title: Text('Acesso: ${registro['acesso_autorizado'] == 1 ? 'Autorizado' : 'Negado'}'),
                      subtitle: Text('Data: ${registro['data']} - Hora: ${registro['hora']}'),
                    );
                  },
                ),
    );
  }

  Widget _buildBoasVindasScreen() {
    return Center(child: Text('Bem-vindo ao sistema! 🚀', style: TextStyle(fontSize: 20)));
  }
}

// 🔹 Configuração MQTT
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

    // 🔹 Inscrever-se nos tópicos
    client.subscribe(mqttTopicRegistros, MqttQos.atLeastOnce);
    client.subscribe(mqttTopicAlertas, MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
      if (event != null && event.isNotEmpty) {
        final recMessage = event[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

        print('📩 Mensagem recebida no tópico ${event[0].topic}: $payload');

        if (event[0].topic == mqttTopicRegistros) {
          salvarNoSQLite(payload);
        } else if (event[0].topic == mqttTopicAlertas) {
          print('🔔 Notificação será exibida!');
          NotificacaoHelper.mostrarNotificacao("🚨 Alerta Recebido!", payload);
        }
      }
    });
  } catch (e) {
    print('❌ Erro na conexão MQTT: $e');
    client.disconnect();
    // Aqui podemos adicionar uma lógica de reconexão ou apenas tentar novamente após alguns segundos
    await Future.delayed(Duration(seconds: 5));
    await conectarMQTT();  // Tentando reconectar
  }
}

// 🔹 Salvar registros no SQLite
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

// 🔔 Configuração de Notificações
class NotificacaoHelper {
  static final FlutterLocalNotificationsPlugin _notificacoes =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotificacoes() async {
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: androidSettings, iOS: null);
    await _notificacoes.initialize(settings);
  }

  static Future<void> mostrarNotificacao(String titulo, String mensagem) async {
    final androidDetails = AndroidNotificationDetails(
      'canal_alertas',
      'Alertas MQTT',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(mensagem),  // Passando a mensagem
    );

    final detalhes = NotificationDetails(android: androidDetails, iOS: null);

    await _notificacoes.show(0, titulo, mensagem, detalhes);
  }
}