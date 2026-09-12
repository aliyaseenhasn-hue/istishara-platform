import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    final container = await bootstrap();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const LawConnectApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('🚨 Application startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(_StartupErrorApp(error: error));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تشغيل التطبيق',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدث خطأ أثناء تهيئة التطبيق. أعد تحميل الصفحة وحاول مرة أخرى.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
