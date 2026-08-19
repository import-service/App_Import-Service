// Admin is Flutter Web — blob download / file picker.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

void saveBytesAsFile(
  Uint8List bytes,
  String filename, {
  String mime = 'application/zip',
}) {
  final blob = html.Blob(<Object>[bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<({String name, Uint8List bytes})?> pickZipFile() async {
  final input = html.FileUploadInputElement()..accept = '.zip,application/zip';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final raw = reader.result;
  late Uint8List bytes;
  if (raw is ByteBuffer) {
    bytes = raw.asUint8List();
  } else if (raw is Uint8List) {
    bytes = raw;
  } else {
    return null;
  }
  return (name: file.name, bytes: bytes);
}
