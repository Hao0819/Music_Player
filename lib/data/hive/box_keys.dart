import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Keys for the boxes whose entries are identified by a file path.
///
/// Hive writes a String key's UTF-8 length into a **single byte** and does not
/// check it (`binary_writer_impl.dart`, `writeKey`). A key longer than 255
/// bytes writes a truncated length, the write itself succeeds, and on the next
/// launch the reader resumes at the wrong offset and takes a stray byte for the
/// next value's type id — so one over-long key makes the entire box unreadable,
/// permanently. That is what emptied every folder on a real device.
///
/// File paths go past 255 bytes easily here: these are files pulled off
/// YouTube, and a title in Han characters costs three bytes each. Measured on
/// one device, 2 of 1130 paths were over the limit on their own, and 7 were
/// over once a folder id was prepended.
///
/// So anything derived from a path is keyed by a digest of fixed length
/// instead. Nothing is lost by the key being opaque: every record already
/// carries the real path as a field, which is what the code reads anyway.
String trackKey(String path) => _digest(path);

/// The key for one folder-to-track link.
///
/// Note the folder id and separator are part of the digested text, not a
/// prefix on the key — a prefix would put the length right back over the edge
/// for the longest paths, since a uuid and separator cost 37 bytes.
String folderLinkKey(String folderId, String trackPath) => _digest('$folderId|$trackPath');

/// Whether [key] was written by this scheme, used to spot entries left by the
/// older path-keyed layout so they can be rewritten once.
bool isDigestKey(Object? key) => key is String && _digestPattern.hasMatch(key);

final _digestPattern = RegExp(r'^[0-9a-f]{40}$');

String _digest(String value) => sha1.convert(utf8.encode(value)).toString();
