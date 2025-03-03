import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

const String version = '0.0.1';

String? projectVersion;
String? flutterVersion;
String? flutterPath;
String? flutterRootPath;

ArgParser buildParser() {
  return ArgParser()
    ..addOption(
      "workingDirectory",
      abbr: "d",
      mandatory: false,
      help: "Used to set the working directory of this command",
    )
    ..addOption(
      "desiredVersion",
      abbr: "v",
      mandatory: false,
      help: "Used to set the version to which you want to upgrade flutter",
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: dart flutter_checker_dart.dart <flags> [arguments]');
  print(argParser.usage);
}

Future<String> _systemRun(
  String command, {
  String? cwd,
}) async {
  final result = await Process.run(
    command,
    [],
    workingDirectory: cwd,
    runInShell: true,
  );

  return result.stdout.toString() + result.stderr.toString();
}

Future<String?> getFlutterVersion() async {
  await _systemRun("flutter doctor");
  final output = await _systemRun("flutter --version");

  try {
    return output.split("\n")[0].split(" ")[1];
  } on Exception {
    return null;
  }
}

Future<String?> getFlutterPath() async {
  try {
    if (Platform.isWindows) {
      final output = await _systemRun("where flutter");
      final result = output.split("\n")[0].split("\\");
      result.removeLast();
      return result.join("\\");
    }

    if (Platform.isMacOS || Platform.isLinux) {
      final output = await _systemRun("which flutter");
      final result = output.trim().split("/");
      result.removeLast();
      return result.join("/");
    }

    return null;
  } on Exception {
    return null;
  }
}

Future<String?> getFlutterRootPath() async {
  try {
    if (Platform.isWindows) {
      final output = await _systemRun("where flutter");
      final result = output.split("\n")[0].split("\\");
      result.removeLast();
      result.removeLast();
      return result.join("\\");
    }

    if (Platform.isMacOS || Platform.isLinux) {
      final output = await _systemRun("which flutter");
      final result = output.trim().split("/");
      result.removeLast();
      result.removeLast();
      return result.join("/");
    }

    return null;
  } on Exception {
    return null;
  }
}

Future<String?> getProjectVersion() async {
  final pubpsecFile = File("pubspec.yaml");

  final exist = await pubpsecFile.exists();

  if (!exist) return null;

  final pubspec = loadYaml(await pubpsecFile.readAsString());

  try {
    return pubspec?["environment"]?["flutter"];
  } on Exception {
    return null;
  }
}

void printStatus() {
  print("Project version: $projectVersion");
  print("Flutter version: $flutterVersion");
  print("Flutter path: $flutterPath");
  print("Flutter root path: $flutterRootPath");
}

Future<void> updateStatus() async {
  flutterVersion = await getFlutterVersion();
  flutterPath = await getFlutterPath();
  flutterRootPath = await getFlutterRootPath();
  projectVersion = await getProjectVersion();
}

Future<void> changeVersion(String version) async {
  print("Cleaning flutter working tree");
  await _systemRun("git reset --hard", cwd: flutterPath).then(print);
  print("Checking out $version...");
  await _systemRun("git fetch", cwd: flutterPath).then(print);
  await _systemRun("git checkout $version", cwd: flutterPath).then(print);
  print("Cleaning flutter working tree");
  await _systemRun("git reset --hard", cwd: flutterPath).then(print);

  if (version == "3.29.0") {
    //https://github.com/flutter/flutter/issues/163308#issuecomment-2661479464
    print("Applying workaround for Flutter 3.29.0...");
    print("Removing /engine/src/.gn...");

    if (Platform.isWindows) {
      await _systemRun("del .\\engine\\src\\.gn", cwd: flutterRootPath);
    }

    if (Platform.isMacOS || Platform.isLinux) {
      await _systemRun("rm -rf ./engine/src/.gn", cwd: flutterRootPath);
    }
  }

  print("Running flutter doctor...");
  await _systemRun("flutter doctor").then(print);
  await _systemRun("flutter clean").then(print);
  await _systemRun("flutter pub upgrade").then(print);
  if (Platform.isMacOS) {
    await _systemRun("pod update", cwd: "./ios").then(print);
  }
  print("Completed.");
}

void run(List<String> args) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(args);

    final dirPath = results.option("workingDirectory");
    final desiredVersion = results.option("desiredVersion")?.trim();

    final dir = switch (dirPath) {
      null => null,
      _ => await () async {
          final result = Directory(dirPath);

          return await result.exists() ? result : null;
        }(),
    };

    if (dir == null) {
      print("No valid directory specified. Using current directory.");
    }

    if (dir != null) {
      Directory.current = dir;
    }

    print("Current directory ${Directory.current.path}");
    print("Loading Flutter version...");
    await updateStatus();
    printStatus();

    if (desiredVersion != null && desiredVersion.isNotEmpty) {
      print("DesiredVersion: $desiredVersion");

      if (desiredVersion != flutterVersion) {
        print("Syncing flutter version with desired version...");
        await changeVersion(desiredVersion);
        await updateStatus();
        printStatus();
      }

      return;
    }

    if (projectVersion == null) {
      print(
          "Project flutter version is not set.\nPlease set it in pubspec.yaml -> environment -> flutter.");
      return;
    }

    if (projectVersion != flutterVersion) {
      print("Flutter version is not synced with project version. Syncing...");
      await changeVersion(projectVersion ?? "");
      await updateStatus();
      printStatus();
      return;
    }
    print("Flutter version is already synced with project version :)");
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  }
}

void main(List<String> arguments) {
  run(arguments);
}
