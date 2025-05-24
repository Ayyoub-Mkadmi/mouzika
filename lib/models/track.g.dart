// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final int typeId = 0;

  @override
  Track read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Track(
      videoId: fields[0] as String,
      title: fields[1] as String,
      mp3Path: fields[2] as String,
      thumbPath: fields[3] as String,
      duration: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.videoId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.mp3Path)
      ..writeByte(3)
      ..write(obj.thumbPath)
      ..writeByte(4)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
