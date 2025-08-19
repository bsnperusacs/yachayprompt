import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  // Hacemos la función 'static' para poder llamarla sin crear una instancia de la clase
  static Future<void> descargarPdf({
    required BuildContext context,
    required String promptText,
    String? titulo,
  }) async {
    final pdf = pw.Document();

    // **MOVER ESTO ANTES DE LA OPERACIÓN ASÍNCRONA**
    // Obtenemos el color primario del tema
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    // ignore: deprecated_member_use
    final pdfColor = PdfColor.fromInt(color.value);

    // Cargamos el logo desde los assets
    final logoData = await rootBundle.load('assets/images/yachay_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Formateamos la fecha actual
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Column(children: [
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Generado con YachayPrompts',
                          style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      pw.Text(
                          'Página ${context.pageNumber} de ${context.pagesCount}',
                          style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    ])
              ]));
        },
        build: (pw.Context context) => [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Image(logoImage, height: 40),
            pw.SizedBox(width: 10),
            pw.Text(titulo ?? 'Prompt Generado',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 24,
                  color: pdfColor,
                )),
          ]),
          pw.Divider(color: pdfColor),
          pw.SizedBox(height: 20),
          pw.Paragraph(
            text: promptText,
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Spacer(),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Fecha de Exportación: $formattedDate',
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic, fontSize: 10))),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}
