import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_provider/data/models/ai_model_info.dart';
import 'features/ai_provider/data/models/ai_provider.dart';
import 'features/ai_provider/data/models/daily_usage_bucket.dart';
import 'features/ai_provider/data/models/rate_limit_snapshot.dart';
import 'features/ai_provider/data/models/usage_stats.dart';
import 'features/ai_provider/data/repositories/model_repository.dart';
import 'features/ai_provider/data/repositories/provider_repository.dart';
import 'features/ai_provider/data/repositories/usage_repository.dart';
import 'features/ai_provider/domain/providers.dart';
import 'features/library/controllers/library_controller.dart';
import 'features/library/data/local_storage_service.dart';
import 'features/rag/controllers/rag_controller.dart';
import 'features/rag/data/rag_store.dart';
import 'features/settings/controllers/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive edge-to-edge system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize local persistent storage
  final storageService = await LocalStorageService.init();
  await Hive.initFlutter();
  Hive.registerAdapter(AIProviderAdapter());
  Hive.registerAdapter(AIModelInfoAdapter());
  Hive.registerAdapter(RateLimitSnapshotAdapter());
  Hive.registerAdapter(UsageStatsAdapter());
  Hive.registerAdapter(DailyUsageBucketAdapter());
  final providerRepository = ProviderRepository();
  await providerRepository.init();
  final modelRepository = ModelRepository();
  await modelRepository.init();
  final usageRepository = UsageRepository();
  await usageRepository.init();
  final ragStore = await RagStore.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
        providerRepositoryProvider.overrideWithValue(providerRepository),
        modelRepositoryProvider.overrideWithValue(modelRepository),
        usageRepositoryProvider.overrideWithValue(usageRepository),
        ragStoreProvider.overrideWithValue(ragStore),
      ],
      child: const ReaderApp(),
    ),
  );
}

class ReaderApp extends ConsumerWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Neomorphic Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsState.themeMode,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
