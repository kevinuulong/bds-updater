import 'dart:async';
import 'dart:io';
import 'package:http/http.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

Uri pageUrl =
    Uri.parse('https://www.minecraft.net/en-us/download/server/bedrock');

var serverPath,
    doNotOverwrite = [
      "permissions.json",
      "server.properties",
      "allowlist.json"
    ],
    platform;
void main(List<String> args) async {
  var parser = ArgParser();

  parser.addOption('platform', allowed: ['windows', 'ubuntu', 'linux']);
  parser.addOption('path');

  var results = parser.parse(args);

  serverPath = results['path'];
  platform = results['platform'];

  print("📦 Backing up");
  makeBackup(doNotOverwrite, serverPath);

  final zipPath = await downloadLatest(platform);

  print("👽 Extracting");
  extract(zipPath, serverPath);

  print("📂 Restoring files from backup");
  restoreBackup(serverPath);

  print("✅ Update successful");
}

Future downloadLatest(platform) async {
  print("🔗 Extracting latest download link");

  final zip = await extractLink(platform);

  print("🔽 Downloading the latest version of BDS");

  final request = await HttpClient().getUrl(zip);
  final response = await request.close();
  await Directory('./versions/').createSync();
  await response.pipe(File('./versions/${zip.pathSegments.last}').openWrite());

  return './versions/${zip.pathSegments.last}';
}

Future extractLink(platform) async {
  platform = platform == 'windows' ? 0 : 1;
  var client = Client();
  Response response = await client.get(pageUrl);

  var document = parse(response.body);
  List<Element> downloads = document.querySelectorAll('.downloadlink');

  return Uri.parse(downloads[platform].attributes['href']);
}

void makeBackup(List<String> files, serverPath) async {
  await Directory('./backup/').createSync();
  for (String file in files) {
    File('${serverPath}/${file}').copySync('./backup/${file}');
  }
}

void restoreBackup(serverPath) async {
  Directory("./backup").list().forEach((element) {
    if (element is File) {
      try {
        element.copySync('${serverPath}/${path.basename(element.path)}');
        element.delete();
      } catch (error) {
        print(error);
      }
    }
  });
}

void extract(zipPath, destinationPath) {
  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final file in archive) {
    final fileName = file.name;
    if (file.isFile) {
      final data = file.content as List<int>;
      File('${destinationPath}/${fileName}')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      Directory('${destinationPath}/${fileName}')..create(recursive: true);
    }
  }
}
