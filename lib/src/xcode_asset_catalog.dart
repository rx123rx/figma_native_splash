import 'dart:convert';

/// Xcode 写入 asset catalog 的 `Contents.json` 采用 `"key" : value` 形式，
/// 与 `JsonEncoder` 输出的 `"key": value` 不同；保持与 Xcode 一致后，
/// 工程在 Xcode 里打开并保存不会产生纯格式 diff。
String encodeAssetCatalogContents(Map<String, Object?> contents) =>
    const JsonEncoder.withIndent('  ')
        .convert(contents)
        .split('\n')
        .map(
          (line) => line.replaceFirstMapped(
            RegExp(r'^(\s*)"([^"]*)": '),
            (match) => '${match[1]}"${match[2]}" : ',
          ),
        )
        .join('\n');

/// 生成 image set 的 `Contents.json` 内容。
///
/// 只写入实际带文件的槽位：Xcode 打开工程时会补出空的 1x/2x 占位槽，
/// 这些空槽没有 `filename`，在 Xcode 中显示为 Unassigned 并产生资源警告。
Map<String, Object?> imageSetContents(List<Map<String, String>> entries) => {
  'images': [
    for (final entry in entries)
      if (entry['filename'] case final String filename when filename.isNotEmpty)
        entry,
  ],
  'info': {'version': 1, 'author': 'xcode'},
};
