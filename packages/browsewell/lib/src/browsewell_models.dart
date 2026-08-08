import 'package:flutter/foundation.dart';

/// Persistent browser profile supplied by a consumer.
@immutable
final class BrowsewellProfile {
  /// Creates a profile identified by the consumer-owned logical [id].
  const BrowsewellProfile({required this.id});

  /// Stable logical identifier, including the consumer namespace.
  final String id;

  /// Encodes this profile.
  Map<String, Object?> toJson() => <String, Object?>{'id': id};
}

/// Browser safety and result-size policy.
@immutable
final class BrowsewellPolicy {
  /// Creates a policy.
  const BrowsewellPolicy({
    this.allowedSchemes = const <String>{'http', 'https', 'about'},
    this.maxEvaluateResultBytes = 1024 * 1024,
    this.maxLogEntries = 1000,
    this.maxScreenshotBytes = 20 * 1024 * 1024,
  });

  /// URL schemes accepted by navigation.
  final Set<String> allowedSchemes;

  /// Maximum encoded evaluate result.
  final int maxEvaluateResultBytes;

  /// Maximum retained log entries.
  final int maxLogEntries;

  /// Maximum screenshot size.
  final int maxScreenshotBytes;

  /// Encodes this policy.
  Map<String, Object?> toJson() => <String, Object?>{
    'allowedSchemes': allowedSchemes.toList()..sort(),
    'maxEvaluateResultBytes': maxEvaluateResultBytes,
    'maxLogEntries': maxLogEntries,
    'maxScreenshotBytes': maxScreenshotBytes,
  };
}

/// Capabilities one native backend guarantees.
@immutable
final class BrowsewellCapabilities {
  /// Creates a capability set.
  const BrowsewellCapabilities({
    required this.trustedInput,
    required this.fullPageScreenshot,
    required this.fileUpload,
    required this.multipleInstances,
    required this.persistentProfile,
    required this.crossOriginFrames,
  });

  /// Decodes capabilities.
  factory BrowsewellCapabilities.fromJson(Map<String, Object?> json) =>
      BrowsewellCapabilities(
        trustedInput: json['trustedInput'] == true,
        fullPageScreenshot: json['fullPageScreenshot'] == true,
        fileUpload: json['fileUpload'] == true,
        multipleInstances: json['multipleInstances'] == true,
        persistentProfile: json['persistentProfile'] == true,
        crossOriginFrames: json['crossOriginFrames'] == true,
      );

  /// Complete desktop contract required by Browsewell.
  static const desktop = BrowsewellCapabilities(
    trustedInput: true,
    fullPageScreenshot: true,
    fileUpload: true,
    multipleInstances: true,
    persistentProfile: true,
    crossOriginFrames: true,
  );

  /// Whether input reaches pages as trusted native input.
  final bool trustedInput;

  /// Whether full-document PNG capture is available.
  final bool fullPageScreenshot;

  /// Whether native file chooser completion is available.
  final bool fileUpload;

  /// Whether more than one browser can coexist.
  final bool multipleInstances;

  /// Whether cookies and site data persist in a supplied profile.
  final bool persistentProfile;

  /// Whether snapshots and trusted input include cross-origin child frames.
  final bool crossOriginFrames;

  /// Encodes capabilities.
  Map<String, Object?> toJson() => <String, Object?>{
    'trustedInput': trustedInput,
    'fullPageScreenshot': fullPageScreenshot,
    'fileUpload': fileUpload,
    'multipleInstances': multipleInstances,
    'persistentProfile': persistentProfile,
    'crossOriginFrames': crossOriginFrames,
  };
}

/// Native browser creation request.
@immutable
final class BrowsewellCreateRequest {
  /// Creates a request.
  const BrowsewellCreateRequest({
    required this.profile,
    required this.initialUrl,
    required this.policy,
  });

  /// Persistent profile.
  final BrowsewellProfile profile;

  /// First URL.
  final Uri initialUrl;

  /// Safety policy.
  final BrowsewellPolicy policy;

  /// Encodes the request.
  Map<String, Object?> toJson() => <String, Object?>{
    'profile': profile.toJson(),
    'initialUrl': initialUrl.toString(),
    'policy': policy.toJson(),
  };
}

/// Native browser creation result.
@immutable
final class BrowsewellCreateResult {
  /// Creates a result.
  const BrowsewellCreateResult({required this.id, required this.capabilities});

  /// Decodes a result.
  factory BrowsewellCreateResult.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final rawCapabilities = json['capabilities'];
    if (id is! String || rawCapabilities is! Map<Object?, Object?>) {
      throw const FormatException('Invalid create result.');
    }
    return BrowsewellCreateResult(
      id: id,
      capabilities: BrowsewellCapabilities.fromJson(
        _stringMap(rawCapabilities),
      ),
    );
  }

  /// Native browser identity.
  final String id;

  /// Native backend capabilities.
  final BrowsewellCapabilities capabilities;
}

/// Type-erased command understood by every backend.
@immutable
final class BrowsewellCommand {
  /// Creates a command.
  const BrowsewellCommand(
    this.name, [
    this.arguments = const <String, Object?>{},
  ]);

  /// Stable command name.
  final String name;

  /// Command arguments.
  final Map<String, Object?> arguments;

  /// Encodes this command.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'arguments': arguments,
  };
}

/// Current page lifecycle.
enum BrowsewellLoadState {
  /// No navigation is in progress.
  idle,

  /// The main document is loading.
  loading,

  /// The main document finished loading.
  loaded,

  /// The main document failed to load.
  failed,
}

/// A native browser state event.
@immutable
final class BrowsewellEvent {
  /// Creates an event.
  const BrowsewellEvent({
    required this.id,
    required this.type,
    this.url,
    this.title,
    this.message,
  });

  /// Decodes an event.
  factory BrowsewellEvent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = json['type'];
    if (id is! String || type is! String) {
      throw const FormatException('Invalid browser event.');
    }
    final rawUrl = json['url'];
    return BrowsewellEvent(
      id: id,
      type: type,
      url: rawUrl is String ? Uri.tryParse(rawUrl) : null,
      title: json['title'] as String?,
      message: json['message'] as String?,
    );
  }

  /// Browser identity.
  final String id;

  /// Stable event name.
  final String type;

  /// Current URL, when changed.
  final Uri? url;

  /// Current title, when changed.
  final String? title;

  /// Failure or console message.
  final String? message;
}

/// Immutable controller state.
@immutable
final class BrowsewellState {
  /// Creates state.
  const BrowsewellState({
    required this.url,
    required this.title,
    required this.loadState,
    this.error,
  });

  /// Current URL.
  final Uri url;

  /// Current document title.
  final String title;

  /// Current lifecycle.
  final BrowsewellLoadState loadState;

  /// Last main-frame failure.
  final String? error;
}

/// One accessibility-tree node.
@immutable
final class BrowsewellSnapshotNode {
  /// Creates a node.
  const BrowsewellSnapshotNode({
    required this.role,
    required this.name,
    this.ref,
    this.value,
    this.children = const <BrowsewellSnapshotNode>[],
  });

  /// Decodes a node.
  factory BrowsewellSnapshotNode.fromJson(Map<String, Object?> json) {
    final rawChildren = json['children'];
    return BrowsewellSnapshotNode(
      role: json['role'] as String? ?? 'generic',
      name: json['name'] as String? ?? '',
      ref: json['ref'] as String?,
      value: json['value'] as String?,
      children: rawChildren is List<Object?>
          ? rawChildren
                .whereType<Map<Object?, Object?>>()
                .map(
                  (child) => BrowsewellSnapshotNode.fromJson(_stringMap(child)),
                )
                .toList(growable: false)
          : const <BrowsewellSnapshotNode>[],
    );
  }

  /// Accessibility role.
  final String role;

  /// Accessible name.
  final String name;

  /// Generation-scoped interactive reference.
  final String? ref;

  /// Accessible value.
  final String? value;

  /// Child nodes.
  final List<BrowsewellSnapshotNode> children;
}

/// Accessibility snapshot whose refs expire with its generation.
@immutable
final class BrowsewellSnapshot {
  /// Creates a snapshot.
  const BrowsewellSnapshot({required this.generation, required this.document});

  /// Decodes a snapshot.
  factory BrowsewellSnapshot.fromJson(Map<String, Object?> json) {
    final generation = json['generation'];
    final document = json['document'];
    if (generation is! int || document is! Map<Object?, Object?>) {
      throw const FormatException('Invalid snapshot.');
    }
    return BrowsewellSnapshot(
      generation: generation,
      document: BrowsewellSnapshotNode.fromJson(_stringMap(document)),
    );
  }

  /// Ref generation.
  final int generation;

  /// Document root.
  final BrowsewellSnapshotNode document;
}

/// One console or network log entry.
@immutable
final class BrowsewellLogEntry {
  /// Creates a log entry.
  const BrowsewellLogEntry({
    required this.level,
    required this.message,
    required this.timestampMicros,
  });

  /// Decodes a log entry.
  factory BrowsewellLogEntry.fromJson(Map<String, Object?> json) =>
      BrowsewellLogEntry(
        level: json['level'] as String? ?? 'info',
        message: json['message'] as String? ?? '',
        timestampMicros: json['timestampMicros'] as int? ?? 0,
      );

  /// Severity or entry kind.
  final String level;

  /// Bounded log message.
  final String message;

  /// Monotonic timestamp supplied by the backend.
  final int timestampMicros;
}

/// Dialog handled during an automation command.
@immutable
final class BrowsewellDialog {
  /// Creates a dialog report.
  const BrowsewellDialog({
    required this.type,
    required this.message,
    required this.accepted,
  });

  /// Browser dialog kind.
  final String type;

  /// Dialog text.
  final String message;

  /// Whether Browsewell accepted it.
  final bool accepted;
}

/// Stable package error codes.
enum BrowsewellErrorCode {
  /// The current backend does not implement the requested capability.
  unsupported,

  /// The target browser no longer exists.
  tabNotFound,

  /// The element reference belongs to an older snapshot generation.
  staleRef,

  /// The command exceeded its deadline.
  timeout,

  /// A configured policy rejected the command.
  denied,

  /// The browser cannot accept another command yet.
  busy,

  /// The backend failed unexpectedly.
  internal,
}

/// Typed browser failure.
final class BrowsewellException implements Exception {
  /// Creates a failure.
  const BrowsewellException(this.code, this.message);

  /// Stable code.
  final BrowsewellErrorCode code;

  /// Human-readable detail.
  final String message;

  @override
  String toString() => 'BrowsewellException(${code.name}): $message';
}

/// Decodes a platform byte result.
Uint8List browsewellBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List<Object?> && value.every((item) => item is int)) {
    return Uint8List.fromList(value.cast<int>());
  }
  throw const FormatException('Invalid byte result.');
}

Map<String, Object?> _stringMap(Map<Object?, Object?> raw) =>
    raw.map((key, value) => MapEntry(key.toString(), value));
