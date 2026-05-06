import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/ingredient_detail_screen.dart';
import '../../features/inventory/ingredient_form_screen.dart';
import '../../features/recipes/recipes_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/shopping/shopping_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/inventory',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const IngredientFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => IngredientDetailScreen(
                      ingredientId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => IngredientFormScreen(
                          ingredientId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shopping',
                builder: (context, state) => const ShoppingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recipes',
                builder: (context, state) => const RecipesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
