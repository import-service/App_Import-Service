import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Генерирует одностраничный PDF «тестовые данные» для демо-документа.
Future<String> buildDemoPlaceholderPdf({
  required String docType,
  String? title,
}) async {
  final safeDoc = docType.trim().isEmpty ? 'document' : docType.trim();
  final heading = (title ?? safeDoc).trim();
  final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final font = pw.Font.ttf(fontData);

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Тестовые данные',
              style: pw.TextStyle(
                font: font,
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              heading,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 16),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'docType: $safeDoc',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 32),
            pw.Text(
              'Демо-режим Import Service',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final bytes = Uint8List.fromList(await doc.save());
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(
      dir.path,
      'demo_${safeDoc.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf',
    ),
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
