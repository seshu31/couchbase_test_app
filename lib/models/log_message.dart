import 'package:cbl/cbl.dart';

abstract class AppLogMessage {
  String get id;
  DateTime get createdAt;
  String get message;
}

class CblLogMessage extends AppLogMessage {
  CblLogMessage(this.dict);

  final DictionaryInterface dict;

  @override
  String get id => dict.documentId;

  @override
  DateTime get createdAt => dict.value('createdAt')!;

  @override
  String get message => dict.value('message')!;

  String? get userId => dict.value('userId');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CblLogMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CblLogMessage(id: $id, message: $message)';
}

extension DictionaryDocumentIdExt on DictionaryInterface {
  String get documentId {
    final self = this;
    return self is Document ? self.id : self.value('id')!;
  }
} 