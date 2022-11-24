import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ubuntu_service/ubuntu_service.dart';
import 'package:yaru/yaru.dart';

import 'path_provider.dart';
import 'settings_editor.dart';
import 'settings_notifier.dart';

void main() {
  registerService(PathProvider.new);

  runApp(
    YaruTheme(
      builder: (context, yaru, child) => MaterialApp(
        theme: yaru.theme,
        darkTheme: yaru.darkTheme,
        home: const HomePage(),
      ),
    ),
  );
}

class GlobalSettings extends SettingsNotifier with ReadOnlySettings {
  GlobalSettings(super.path);
}

class UserSettings extends SettingsNotifier with InheritedSettings {
  UserSettings(super.path);
}

class WorkspaceSettings extends SettingsNotifier with InheritedSettings {
  WorkspaceSettings(super.path);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final path = getService<PathProvider>();
    return Scaffold(
      body: ChangeNotifierProvider(
        create: (_) =>
            GlobalSettings(path.getBundleFile('global.json'))..init(),
        builder: (context, child) => Row(
          children: [
            Expanded(
              child: SettingsEditor(
                title: const Text('Global (read-only)'),
                settings: context.watch<GlobalSettings>(),
                readOnly: true,
              ),
            ),
            for (var i = 1; i <= 2; ++i) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child:
                    ChangeNotifierProxyProvider<GlobalSettings, UserSettings>(
                  create: (_) =>
                      UserSettings(path.getConfigFile('user$i.json')),
                  update: (_, global, user) => user!..init(base: global),
                  builder: (context, child) => Column(
                    children: [
                      Expanded(
                        child: SettingsEditor(
                          title: Text('User $i'),
                          settings: context.watch<UserSettings>(),
                        ),
                      ),
                      Expanded(
                        child: ChangeNotifierProxyProvider<UserSettings,
                            WorkspaceSettings>(
                          create: (_) => WorkspaceSettings(
                              path.getConfigFile('user$i/workspace$i.json')),
                          update: (_, user, workspace) =>
                              workspace!..init(base: user),
                          builder: (context, child) => SettingsEditor(
                            title: Text('Workspace $i'),
                            settings: context.watch<WorkspaceSettings>(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}