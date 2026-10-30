import 'package:flutter/material.dart';
import 'dart:math';

class InfluxDataView extends StatelessWidget {
  const InfluxDataView({super.key});

  @override
  Widget build(BuildContext context) {
    final Random random = Random();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        title: const Text('Visor de Telemetría (InfluxDB) - San Antonio', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Registros Series de Tiempo (Últimas 24 hrs)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(5)),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[300]), // Fondo gris claro para destacar el texto negro
                    columns: const [
                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16))),
                      DataColumn(label: Text('Dispositivo (IoT)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16))),
                      DataColumn(label: Text('Métrica', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16))),
                      DataColumn(label: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16))),
                    ],
                    rows: List.generate(150, (index) {
                      final time = DateTime.now().subtract(Duration(minutes: index * 2));
                      final dispositivos = ['Antena_RFID_Norte', 'Sensor_Temp_Reefer', 'Telemetria_Grua_04', 'Camara_IP_Acceso'];
                      final metricas = ['tag_leido', 'temperatura_c', 'rpm_motor', 'ancho_banda_mbps'];
                      int randIndex = random.nextInt(4);
                      
                      String valor;
                      if (randIndex == 0) valor = "TAG-ABCD${random.nextInt(99)}";
                      else if (randIndex == 1) valor = "-${random.nextInt(18) + 2} °C";
                      else if (randIndex == 2) valor = "${random.nextInt(1500) + 500} RPM";
                      else valor = "${random.nextInt(100)} Mbps";

                      // TODOS los textos en color negro puro para contraste máximo
                      return DataRow(cells: [
                        DataCell(Text(time.toString().substring(0, 19), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                        DataCell(Text(dispositivos[randIndex], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                        DataCell(Text(metricas[randIndex], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                        DataCell(Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15))),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}