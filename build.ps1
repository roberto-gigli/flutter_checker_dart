Remove-Item dist -Recurse
New-Item -Name "dist" -ItemType Directory
dart compile exe -o dist/flutter_checker.exe bin/flutter_checker_dart.dart