import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/agent_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/signal_provider.dart';
import 'providers/visitor_provider.dart';
import 'services/signal_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent storage
  final storageService = StorageService();
  await storageService.init();

  // Initialize core services
  final signalService = SignalService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AgentProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => SignalProvider(signalService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => VisitorProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => DiagnosticsProvider(),
        ),
      ],
      child: const WebRTCGatewayApp(),
    ),
  );
}

class WebRTCGatewayApp extends StatelessWidget {
  const WebRTCGatewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const HomeShell(),
    );
  }
}
