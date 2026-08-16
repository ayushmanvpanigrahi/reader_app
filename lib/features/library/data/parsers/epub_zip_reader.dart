import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A single entry from an EPUB ZIP central directory.
class EpubZipEntry {
  const EpubZipEntry({
    required this.name,
    required this.compressedSize,
    required this.compressionMethod,
    required this.localHeaderOffset,
  });

  final String name;
  final int compressedSize;
  final int compressionMethod;
  final int localHeaderOffset;
}

/// Minimal streaming ZIP reader for EPUB files.
///
/// Unlike `package:archive`'s `ZipDecoder.decodeStream`, which eagerly reads the
/// compressed bytes of every entry into memory, this reads only the end-of-
/// central-directory record, the central directory, and the specific entries
/// that are requested. Importing or enriching a large EPUB therefore never
/// pulls the whole file into memory.
class EpubZipReader {
  static const int _signatureEocd = 0x06054b50;
  static const int _signatureCentralDir = 0x02014b50;
  static const int _signatureLocalHeader = 0x04034b50;
  static const int _maxEocdScan = 65557;

  /// Parses the central directory of [raf].
  ///
  /// Returns null for truncated archives, ZIP64 archives, or archives with no
  /// entries; callers should fall back to filename-based parsing.
  static Future<List<EpubZipEntry>?> readCentralDirectory(RandomAccessFile raf) async {
    final length = await raf.length();
    if (length < 22) return null;

    // The EOCD record lives at the end of the file (possibly followed by a
    // comment of up to 64KB), so scanning the last 64KB + 22 bytes is enough.
    final scanLen = length < _maxEocdScan ? length : _maxEocdScan;
    await raf.setPosition(length - scanLen);
    final tail = await raf.read(scanLen);

    var eocdOffset = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (_uint32(tail, i) == _signatureEocd) {
        eocdOffset = i;
        break;
      }
    }
    if (eocdOffset < 0) return null;

    final entryCount = _uint16(tail, eocdOffset + 10);
    final cdSize = _uint32(tail, eocdOffset + 12);
    final cdOffset = _uint32(tail, eocdOffset + 16);
    if (entryCount == 0xffff || cdSize == 0xffffffff || cdOffset == 0xffffffff) {
      // ZIP64 sentinel values - fall back to non-streaming paths.
      return null;
    }

    await raf.setPosition(cdOffset);
    final cd = await raf.read(cdSize);
    if (cd.length < cdSize) return null;

    final entries = <EpubZipEntry>[];
    var pos = 0;
    while (pos + 46 <= cd.length) {
      if (_uint32(cd, pos) != _signatureCentralDir) break;
      final compressionMethod = _uint16(cd, pos + 10);
      final compressedSize = _uint32(cd, pos + 20);
      final fnameLen = _uint16(cd, pos + 28);
      final extraLen = _uint16(cd, pos + 30);
      final commentLen = _uint16(cd, pos + 32);
      final localHeaderOffset = _uint32(cd, pos + 42);
      final nameBytes = cd.sublist(pos + 46, pos + 46 + fnameLen);
      entries.add(EpubZipEntry(
        name: utf8.decode(nameBytes, allowMalformed: true),
        compressedSize: compressedSize,
        compressionMethod: compressionMethod,
        localHeaderOffset: localHeaderOffset,
      ));
      pos += 46 + fnameLen + extraLen + commentLen;
    }
    return entries.isEmpty ? null : entries;
  }

  /// Reads and decompresses [entry] as UTF-8 text.
  ///
  /// Returns an empty string for empty entries and null when the entry cannot
  /// be read or uses an unsupported compression method.
  static Future<String?> readEntryText(RandomAccessFile raf, EpubZipEntry entry) async {
    if (entry.compressedSize <= 0) return '';
    if (entry.compressionMethod != 0 && entry.compressionMethod != 8) return null;

    await raf.setPosition(entry.localHeaderOffset);
    final header = await raf.read(30);
    if (header.length < 30 || _uint32(header, 0) != _signatureLocalHeader) return null;
    final fnameLen = _uint16(header, 26);
    final extraLen = _uint16(header, 28);

    await raf.setPosition(entry.localHeaderOffset + 30 + fnameLen + extraLen);
    final data = await raf.read(entry.compressedSize);
    if (data.length != entry.compressedSize) return null;

    try {
      final bytes = entry.compressionMethod == 8
          ? ZLibCodec(raw: true).decode(data)
          : data;
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static int _uint16(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.little);

  static int _uint32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);
}
