import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});
  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<dynamic> _categories = [];
  List<dynamic> _items = [];
  String _searchTerm = '';
  String _activeCategory = 'all';
  bool _hasLoadedOnce = false;

  late TextEditingController _editNameController;
  late TextEditingController _editPriceController;
  late TextEditingController _editDescriptionController;

  String _newCategory = '';
  String _itemName = '';
  String _itemPrice = '';
  String _itemCategoryId = '';
  String _itemDescription = '';
  bool _skipKitchen = false; // Kitchen alert toggle for new item

  String? _editingItemId;
  String _editName = '';
  String _editPrice = '';
  String _editDescription = '';

  // Inventory & Recipe Builder states
  List<dynamic> _inventoryItems = [];

  // PDF Upload state
  bool _uploadUsed = false;
  bool _uploadStatusLoaded = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _editNameController = TextEditingController();
    _editPriceController = TextEditingController();
    _editDescriptionController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMenu();
      _loadInventory();
      _checkUploadStatus();
    });
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editPriceController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  String _getBaseUrl(Map<String, dynamic> user) {
    return user['role'] == 'owner' ? 'global-menu' : 'branch-menu';
  }

  Future<void> _loadMenu() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);
    final baseUrl = _getBaseUrl(user);

    try {
      final responses = await Future.wait([
        apiFetch('/api/$baseUrl/categories'),
        apiFetch('/api/$baseUrl/items'),
      ]);

      if (mounted) {
        setState(() {
          _categories = (responses[0] is List)
              ? responses[0]
              : (responses[0]['data'] ?? []);
          _items = (responses[1] is List)
              ? responses[1]
              : (responses[1]['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Menu Load Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load menu')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  Future<void> _loadInventory() async {
    try {
      final res = await apiFetch('/api/inventory/items');
      if (mounted) {
        setState(() {
          _inventoryItems = (res is List) ? res : (res['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Inventory Load Failed: $e");
    }
  }

  Future<void> _checkUploadStatus() async {
    try {
      final res = await apiFetch('/api/menu/upload-status');
      if (mounted) {
        setState(() {
          _uploadUsed = res['used'] == true;
          _uploadStatusLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Upload status check failed: $e");
    }
  }

  Future<void> _addCategory() async {
    if (_newCategory.trim().isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/category',
        method: 'POST',
        data: {'name': _newCategory.trim()},
      );
      setState(() => _newCategory = '');
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add category: $e')));
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (act != true) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/category/$id',
        method: 'DELETE',
      );
      if (_activeCategory == id) {
        setState(() => _activeCategory = 'all');
      }
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _editCategory(Map<String, dynamic> cat) async {
    final TextEditingController controller = TextEditingController(
      text: cat['name'],
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new category name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );

    if (newName == null ||
        newName.trim().isEmpty ||
        newName.trim() == cat['name']) {
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/category/${cat['_id']}',
        method: 'PATCH',
        data: {'name': newName.trim()},
      );
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final reordered = List<dynamic>.from(_categories);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    setState(() => _categories = reordered);

    final user = ref.read(authProvider).user;
    final baseUrl = user != null ? _getBaseUrl(user) : 'global-menu';

    try {
      await apiFetch(
        '/api/$baseUrl/category/reorder',
        method: 'PATCH',
        data: {
          'orderedIds': reordered.map((c) => c['_id'].toString()).toList(),
        },
      );
    } catch (e) {
      debugPrint("Category reorder failed: $e");
      await _loadMenu(); // rollback
    }
  }

  Future<void> _addItem() async {
    if (_itemName.isEmpty || _itemPrice.isEmpty || _itemCategoryId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all required fields')));
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isActionLoading = true);
    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/item',
        method: 'POST',
        data: {
          'name': _itemName,
          'basePrice': num.tryParse(_itemPrice) ?? 0,
          'categories': _itemCategoryId,
          'description': _itemDescription,
          'skipKitchen': _skipKitchen,
        },
      );

      setState(() {
        _itemName = '';
        _itemPrice = '';
        _itemCategoryId = '';
        _itemDescription = '';
        _skipKitchen = false;
      });
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dish registered')));
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeEndDrawer();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (act != true) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch('/api/${_getBaseUrl(user)}/item/$id', method: 'DELETE');
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _saveEdit(String id) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/item/$id',
        method: 'PATCH',
        data: {
          'name': _editName,
          'basePrice': num.tryParse(_editPrice) ?? 0,
          'description': _editDescription,
        },
      );
      setState(() => _editingItemId = null);
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _toggleItem(String id) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final res = await apiFetch(
        '/api/${_getBaseUrl(user)}/item/$id/toggle',
        method: 'PATCH',
      );
      final updatedAvailability = res['item']?['isAvailable'];

      setState(() {
        final idx = _items.indexWhere((i) => i['_id'] == id);
        if (idx != -1) {
          _items[idx] = {
            ..._items[idx],
            'isAvailable': updatedAvailability ?? !(_items[idx]['isAvailable'] == true),
          };
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
      }
    }
  }

  Future<void> _toggleSkipKitchen(String itemId, bool currentVal) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final baseUrl = _getBaseUrl(user);

    try {
      final res = await apiFetch(
        '/api/$baseUrl/item/$itemId/skip-kitchen',
        method: 'PATCH',
        data: {'skipKitchen': !currentVal},
      );
      final updatedItem = res['item'] ?? {};
      final newSkip = updatedItem['skipKitchen'] ?? !currentVal;

      setState(() {
        final idx = _items.indexWhere((i) => i['_id'] == itemId);
        if (idx != -1) {
          _items[idx] = {..._items[idx], 'skipKitchen': newSkip};
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newSkip
                  ? "Kitchen notification OFF for this item"
                  : "Kitchen notification ON for this item",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _openImagePicker(String id) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final user = ref.read(authProvider).user;
      if (user == null) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading Image...')));
      }

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path, filename: image.name),
      });

      await apiFetch(
        '/api/${_getBaseUrl(user)}/item/$id/image',
        method: 'POST',
        data: formData,
      );
      await _loadMenu();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image uploaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  /// Recipe Builder Modal matching page.js
  void _openRecipeModal(dynamic item) {
    if (_inventoryItems.isEmpty) {
      _loadInventory();
    }
    final rawRecipe = item['recipe'] as List? ?? [];
    List<Map<String, dynamic>> currentRecipe = rawRecipe.map<Map<String, dynamic>>((r) {
      return {
        'inventoryItem': r['inventoryItem'] is Map
            ? (r['inventoryItem']['_id']?.toString() ?? '')
            : (r['inventoryItem']?.toString() ?? ''),
        'quantity': r['quantity']?.toString() ?? '',
        'unit': r['unit']?.toString() ?? 'piece',
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
              titlePadding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 12.h),
              contentPadding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recipe Builder',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        (item['name'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 280.h),
                      child: currentRecipe.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 36.h),
                              child: Text(
                                'No ingredients yet. Click "Add Ingredient" to start.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: currentRecipe.length,
                              separatorBuilder: (c, idx) => SizedBox(height: 10.h),
                              itemBuilder: (context, index) {
                                final row = currentRecipe[index];
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14.r),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      // Ingredient select
                                      Expanded(
                                        flex: 4,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            hint: Text(
                                              'Select Ingredient',
                                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                            ),
                                            value: row['inventoryItem'].toString().isEmpty
                                                ? null
                                                : row['inventoryItem'].toString(),
                                            items: _inventoryItems.map<DropdownMenuItem<String>>((inv) {
                                              return DropdownMenuItem<String>(
                                                value: inv['_id'].toString(),
                                                child: Text(
                                                  (inv['name'] ?? '').toString(),
                                                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setModalState(() {
                                                row['inventoryItem'] = val ?? '';
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      // Quantity
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: row['quantity'].toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'Qty',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                          ),
                                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                          onChanged: (v) => row['quantity'] = v,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      // Unit
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: row['unit'] ?? 'piece',
                                            items: const ['g', 'kg', 'ml', 'ltr', 'piece'].map((u) {
                                              return DropdownMenuItem(
                                                value: u,
                                                child: Text(u, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setModalState(() {
                                                row['unit'] = val ?? 'piece';
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      // Remove
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 16),
                                        onPressed: () {
                                          setModalState(() {
                                            currentRecipe.removeAt(index);
                                          });
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              currentRecipe.add({
                                'inventoryItem': '',
                                'quantity': '',
                                'unit': 'piece',
                              });
                            });
                          },
                          icon: const Icon(LucideIcons.plus, size: 14),
                          label: const Text('Add Ingredient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final user = ref.read(authProvider).user;
                              final baseUrl = user != null ? _getBaseUrl(user) : 'global-menu';
                              try {
                                await apiFetch(
                                  '/api/$baseUrl/item/${item['_id']}/recipe',
                                  method: 'PATCH',
                                  data: {
                                    'recipe': currentRecipe.map((r) => {
                                      'inventoryItem': r['inventoryItem'],
                                      'quantity': num.tryParse(r['quantity'].toString()) ?? 0,
                                      'unit': r['unit'],
                                    }).toList(),
                                  },
                                );
                                navigator.pop();
                                await _loadMenu();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Recipe saved')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to save recipe: $e')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D00),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'SAVE RECIPE',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Robust check whether an item belongs to the selected category.
  /// Handles:
  /// - `i['categories']` as List of String IDs or List of Maps with `_id`
  /// - `i['category']` as String ID or Map with `_id`
  /// - Nested in `i['globalItem']` for branch menu items
  bool _itemBelongsToCategory(dynamic i, String categoryId) {
    if (categoryId == 'all') return true;

    final List<String> itemCategoryIds = [];

    void extractIds(dynamic cats) {
      if (cats == null) return;
      if (cats is List) {
        for (var c in cats) {
          if (c is Map && c['_id'] != null) {
            itemCategoryIds.add(c['_id'].toString());
          } else if (c != null) {
            itemCategoryIds.add(c.toString());
          }
        }
      } else if (cats is Map && cats['_id'] != null) {
        itemCategoryIds.add(cats['_id'].toString());
      } else {
        itemCategoryIds.add(cats.toString());
      }
    }

    extractIds(i['categories']);
    extractIds(i['category']);
    if (i['globalItem'] is Map) {
      extractIds(i['globalItem']['categories']);
      extractIds(i['globalItem']['category']);
    }

    return itemCategoryIds.contains(categoryId.toString());
  }

  /// Resolves display name of the category for an item
  String _getCategoryName(dynamic item) {
    if (item == null) return 'STANDARD';

    // 1. item['category']
    if (item['category'] is Map && item['category']['name'] != null) {
      return item['category']['name'].toString();
    }
    // 2. item['categories']
    if (item['categories'] is List && item['categories'].isNotEmpty) {
      final first = item['categories'][0];
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
      if (first != null) {
        final catId = (first is Map ? first['_id'] : first).toString();
        final found = _categories.firstWhere(
          (c) => c['_id'].toString() == catId,
          orElse: () => null,
        );
        if (found != null && found['name'] != null) {
          return found['name'].toString();
        }
      }
    }
    // 3. item['category'] as ID
    if (item['category'] != null) {
      final catId = item['category'].toString();
      final found = _categories.firstWhere(
        (c) => c['_id'].toString() == catId,
        orElse: () => null,
      );
      if (found != null && found['name'] != null) {
        return found['name'].toString();
      }
    }
    // 4. globalItem
    if (item['globalItem'] is Map) {
      return _getCategoryName(item['globalItem']);
    }

    return 'STANDARD';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.user != null && !_hasLoadedOnce && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMenu();
      });
    }

    if (_isLoading && _items.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFCF6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D00)),
        ),
      );
    }

    // Filter items based on search term and selected category
    final filteredItems = _items.where((i) {
      final name = (i['name'] ?? i['globalItem']?['name'] ?? '')
          .toString()
          .toLowerCase();
      final matchesSearch = name.contains(_searchTerm.toLowerCase());
      if (!matchesSearch) return false;
      return _itemBelongsToCategory(i, _activeCategory);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildCategoryDrawer(),
      endDrawer: _buildAddFormDrawer(),
      body: Column(
        children: [
          // Top Nav
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700.w;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -1,
                                ),
                                children: const [
                                  TextSpan(text: 'SCAN '),
                                  TextSpan(
                                    text: 'SERVE',
                                    style: TextStyle(color: Color(0xFFFF4D00)),
                                  ),
                                ],
                              ),
                            ),
                            if (!isMobile)
                              Text(
                                'MENU MANAGER',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                          ],
                        ),
                        if (!isMobile)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: _buildSearchBar(),
                            ),
                          ),
                        Row(
                          children: [
                            if (!isMobile) ...[
                              OutlinedButton.icon(
                                onPressed: (_uploadUsed || !_uploadStatusLoaded)
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'PDF Menu Upload is available via the Web Dashboard',
                                            ),
                                          ),
                                        );
                                      },
                                icon: Icon(LucideIcons.upload, size: 14.sp),
                                label: Text(
                                  _uploadUsed ? 'PDF Upload Already Used' : 'Upload PDF Menu',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _uploadUsed
                                      ? Colors.grey.shade400
                                      : const Color(0xFFFF4D00),
                                  side: BorderSide(
                                    color: _uploadUsed
                                        ? Colors.grey.shade300
                                        : const Color(0xFFFF4D00),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.h,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                            ],
                            IconButton(
                              icon: const Icon(LucideIcons.filter),
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                            SizedBox(width: 8.w),
                            ElevatedButton(
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openEndDrawer(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D00),
                                padding: EdgeInsets.all(12.r),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Icon(
                                LucideIcons.plus,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isMobile)
                      Padding(
                        padding: EdgeInsets.only(top: 14.h),
                        child: _buildSearchBar(),
                      ),
                  ],
                );
              },
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desktop Category Sidebar
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isDesktop = MediaQuery.of(context).size.width > 900.w;
                    if (!isDesktop) return const SizedBox.shrink();
                    return _buildCategoryDrawerConfig(isDrawer: false);
                  },
                ),

                // Main Grid
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -1,
                                ),
                                children: const [
                                  TextSpan(text: 'LIVE '),
                                  TextSpan(
                                    text: 'MENU',
                                    style: TextStyle(color: Color(0xFFFF4D00)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${filteredItems.length} ITEMS',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                                letterSpacing: 1.w,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Expanded(
                          child: filteredItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.package,
                                        size: 48.sp,
                                        color: Colors.grey.shade300,
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        'No dishes found in this category',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 480.w,
                                    mainAxisExtent: 220.h,
                                    crossAxisSpacing: 16.w,
                                    mainAxisSpacing: 16.h,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (ctx, idx) {
                                    final i = filteredItems[idx];
                                    final isEditing = _editingItemId == i['_id'];
                                    final isAvailable = i['isAvailable'] == true;
                                    final isSkip = i['skipKitchen'] == true;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(24.r),
                                        border: Border.all(
                                          color: Colors.grey.shade100,
                                        ),
                                        boxShadow: [
                                          if (isAvailable)
                                            BoxShadow(
                                              color: Colors.black.withAlpha(6),
                                              blurRadius: 10.r,
                                              offset: Offset(0, 4.h),
                                            ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Row(
                                        children: [
                                          // Left Image
                                          InkWell(
                                            onTap: () => _openImagePicker(i['_id']),
                                            child: Container(
                                              width: 120.w,
                                              height: double.infinity,
                                              color: Colors.grey.shade100,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  if (i['imageUrl'] != null)
                                                    Image.network(
                                                      i['imageUrl'],
                                                      fit: BoxFit.cover,
                                                      color: isAvailable
                                                          ? null
                                                          : Colors.grey,
                                                      colorBlendMode: isAvailable
                                                          ? null
                                                          : BlendMode.saturation,
                                                    )
                                                  else
                                                    Icon(
                                                      LucideIcons.image,
                                                      size: 32.sp,
                                                      color: Colors.black12,
                                                    ),

                                                  // Off overlay badge
                                                  if (!isAvailable)
                                                    Container(
                                                      color: Colors.black26,
                                                      child: Center(
                                                        child: Container(
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal: 6.w,
                                                            vertical: 2.h,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withAlpha(230),
                                                            borderRadius: BorderRadius.circular(6.r),
                                                          ),
                                                          child: Text(
                                                            'OFF',
                                                            style: TextStyle(
                                                              fontSize: 8.sp,
                                                              fontWeight: FontWeight.w900,
                                                              color: Colors.grey.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),

                                                  // No KDS top-left badge
                                                  if (isSkip)
                                                    Positioned(
                                                      top: 6.h,
                                                      left: 6.w,
                                                      child: Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 6.w,
                                                          vertical: 2.h,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF0F172A),
                                                          borderRadius: BorderRadius.circular(6.r),
                                                          boxShadow: const [
                                                            BoxShadow(
                                                              color: Colors.black26,
                                                              blurRadius: 4,
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              LucideIcons.bellOff,
                                                              color: Colors.white,
                                                              size: 8.sp,
                                                            ),
                                                            SizedBox(width: 3.w),
                                                            Text(
                                                              'NO KDS',
                                                              style: TextStyle(
                                                                fontSize: 7.sp,
                                                                fontWeight: FontWeight.w900,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Right Details & Actions
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.all(12.r),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Category pill
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 8.w,
                                                      vertical: 2.h,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isAvailable
                                                          ? Colors.orange.shade50
                                                          : Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(6.r),
                                                    ),
                                                    child: Text(
                                                      _getCategoryName(i).toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 8.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: isAvailable
                                                            ? const Color(0xFFFF4D00)
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),

                                                  // Title
                                                  if (isEditing)
                                                    TextField(
                                                      controller: _editNameController,
                                                      onChanged: (v) => _editName = v,
                                                      style: TextStyle(
                                                        fontSize: 13.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.zero,
                                                        border: UnderlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color: const Color(0xFFFF4D00),
                                                            width: 1.w,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Text(
                                                      (i['name'] ?? '').toString(),
                                                      style: TextStyle(
                                                        fontSize: 13.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: isAvailable
                                                            ? const Color(0xFF0F172A)
                                                            : Colors.grey,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),

                                                  SizedBox(height: 2.h),

                                                  // Description
                                                  if (isEditing)
                                                    TextField(
                                                      controller: _editDescriptionController,
                                                      onChanged: (v) => _editDescription = v,
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      decoration: const InputDecoration(
                                                        hintText: 'Description...',
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.zero,
                                                        border: InputBorder.none,
                                                      ),
                                                    )
                                                  else
                                                    Text(
                                                      (i['description'] ??
                                                              'Authentic ingredients prepared fresh.')
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),

                                                  SizedBox(height: 4.h),

                                                  // Price
                                                  if (isEditing)
                                                    Row(
                                                      children: [
                                                        Text(
                                                          '₹',
                                                          style: TextStyle(
                                                            fontSize: 14.sp,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                        ),
                                                        SizedBox(width: 2.w),
                                                        Expanded(
                                                          child: TextField(
                                                            controller: _editPriceController,
                                                            onChanged: (v) => _editPrice = v,
                                                            keyboardType: TextInputType.number,
                                                            style: TextStyle(
                                                              fontSize: 14.sp,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                            decoration: InputDecoration(
                                                              isDense: true,
                                                              contentPadding: EdgeInsets.zero,
                                                              border: UnderlineInputBorder(
                                                                borderSide: BorderSide(
                                                                  color: const Color(0xFFFF4D00),
                                                                  width: 1.w,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  else
                                                    Text(
                                                      '₹${i['price'] ?? i['basePrice'] ?? 0}',
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: isAvailable
                                                            ? const Color(0xFF0F172A)
                                                            : Colors.grey,
                                                      ),
                                                    ),

                                                  const Spacer(),

                                                  // Action Buttons Row 1: Availability + SkipKitchen (No KDS)
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: InkWell(
                                                          onTap: () => _toggleItem(i['_id']),
                                                          borderRadius: BorderRadius.circular(6.r),
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(vertical: 4.h),
                                                            decoration: BoxDecoration(
                                                              color: isAvailable
                                                                  ? const Color(0xFFDCFCE7)
                                                                  : Colors.grey.shade100,
                                                              borderRadius: BorderRadius.circular(6.r),
                                                            ),
                                                            alignment: Alignment.center,
                                                            child: Text(
                                                              isAvailable ? 'Available' : 'Unavailable',
                                                              style: TextStyle(
                                                                fontSize: 8.sp,
                                                                fontWeight: FontWeight.w900,
                                                                color: isAvailable
                                                                    ? const Color(0xFF15803D)
                                                                    : Colors.grey.shade600,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      Expanded(
                                                        child: InkWell(
                                                          onTap: () => _toggleSkipKitchen(i['_id'], isSkip),
                                                          borderRadius: BorderRadius.circular(6.r),
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(vertical: 4.h),
                                                            decoration: BoxDecoration(
                                                              color: isSkip
                                                                  ? const Color(0xFF0F172A)
                                                                  : const Color(0xFFFFF7ED),
                                                              borderRadius: BorderRadius.circular(6.r),
                                                            ),
                                                            alignment: Alignment.center,
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(
                                                                  isSkip ? LucideIcons.bellOff : LucideIcons.bell,
                                                                  size: 9.sp,
                                                                  color: isSkip
                                                                      ? Colors.white
                                                                      : const Color(0xFFEA580C),
                                                                ),
                                                                SizedBox(width: 3.w),
                                                                Text(
                                                                  isSkip ? 'No KDS' : 'KDS On',
                                                                  style: TextStyle(
                                                                    fontSize: 8.sp,
                                                                    fontWeight: FontWeight.w900,
                                                                    color: isSkip
                                                                        ? Colors.white
                                                                        : const Color(0xFFEA580C),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4.h),

                                                  // Action Buttons Row 2: Edit/Save + Delete
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: isEditing
                                                            ? InkWell(
                                                                onTap: () => _saveEdit(i['_id']),
                                                                borderRadius: BorderRadius.circular(6.r),
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFF22C55E),
                                                                    borderRadius: BorderRadius.circular(6.r),
                                                                  ),
                                                                  alignment: Alignment.center,
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                      Icon(LucideIcons.check, size: 9.sp, color: Colors.white),
                                                                      SizedBox(width: 3.w),
                                                                      Text(
                                                                        'Save',
                                                                        style: TextStyle(
                                                                          fontSize: 8.sp,
                                                                          fontWeight: FontWeight.w900,
                                                                          color: Colors.white,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              )
                                                            : InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _editingItemId = i['_id'];
                                                                    _editName = i['name'] ?? '';
                                                                    _editPrice = (i['price'] ?? i['basePrice'] ?? 0).toString();
                                                                    _editDescription = i['description'] ?? '';
                                                                    _editNameController.text = _editName;
                                                                    _editPriceController.text = _editPrice;
                                                                    _editDescriptionController.text = _editDescription;
                                                                  });
                                                                },
                                                                borderRadius: BorderRadius.circular(6.r),
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFF0F172A),
                                                                    borderRadius: BorderRadius.circular(6.r),
                                                                  ),
                                                                  alignment: Alignment.center,
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                      Icon(LucideIcons.edit3, size: 9.sp, color: Colors.white),
                                                                      SizedBox(width: 3.w),
                                                                      Text(
                                                                        'Edit',
                                                                        style: TextStyle(
                                                                          fontSize: 8.sp,
                                                                          fontWeight: FontWeight.w900,
                                                                          color: Colors.white,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      Expanded(
                                                        child: InkWell(
                                                          onTap: () => _deleteItem(i['_id']),
                                                          borderRadius: BorderRadius.circular(6.r),
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(vertical: 4.h),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFEF2F2),
                                                              borderRadius: BorderRadius.circular(6.r),
                                                            ),
                                                            alignment: Alignment.center,
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(LucideIcons.trash2, size: 9.sp, color: const Color(0xFFEF4444)),
                                                                SizedBox(width: 3.w),
                                                                Text(
                                                                  'Delete',
                                                                  style: TextStyle(
                                                                    fontSize: 8.sp,
                                                                    fontWeight: FontWeight.w900,
                                                                    color: const Color(0xFFEF4444),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4.h),

                                                  // Action Buttons Row 3: Recipe Builder
                                                  InkWell(
                                                    onTap: () => _openRecipeModal(i),
                                                    borderRadius: BorderRadius.circular(6.r),
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding: EdgeInsets.symmetric(vertical: 4.h),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFFF7ED),
                                                        borderRadius: BorderRadius.circular(6.r),
                                                        border: Border.all(color: const Color(0xFFFFEDD5)),
                                                      ),
                                                      alignment: Alignment.center,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(LucideIcons.package, size: 9.sp, color: const Color(0xFFEA580C)),
                                                          SizedBox(width: 4.w),
                                                          Text(
                                                            'Recipe Builder',
                                                            style: TextStyle(
                                                              fontSize: 8.sp,
                                                              fontWeight: FontWeight.w900,
                                                              color: const Color(0xFFEA580C),
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDrawerConfig({required bool isDrawer}) {
    return Container(
      width: isDrawer ? null : 300.w,
      height: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CREATE SECTION',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF4D00),
                  letterSpacing: 1,
                ),
              ),
              if (isDrawer)
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => _newCategory = v,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Desserts',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addCategory,
                  icon: Icon(
                    LucideIcons.plus,
                    size: 16.sp,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28.h),
          Text(
            'MENU SECTIONS',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 14.h),
          // All Items Button
          _buildCategoryItem('all', 'All Items', count: _items.length),
          SizedBox(height: 6.h),
          // Reorderable list for categories
          Expanded(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              onReorder: _reorderCategories,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 6,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                  child: child,
                );
              },
              itemBuilder: (context, idx) {
                final c = _categories[idx];
                final catId = (c['_id'] ?? '$idx').toString();
                return Container(
                  key: ValueKey(catId),
                  child: _buildCategoryItem(
                    catId,
                    (c['name'] ?? '').toString(),
                    category: c is Map<String, dynamic>
                        ? c
                        : Map<String, dynamic>.from(c),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(child: _buildCategoryDrawerConfig(isDrawer: true)),
    );
  }

  Widget _buildCategoryItem(
    String id,
    String label, {
    int? count,
    Map<String, dynamic>? category,
  }) {
    final isActive = _activeCategory == id;
    return InkWell(
      onTap: () {
        setState(() => _activeCategory = id);
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isActive
              ? (id == 'all'
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFFF4D00))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white24 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else ...[
              if (isActive)
                Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white,
                  size: 14.sp,
                ),
              if (id != 'all' && category != null) ...[
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _editCategory(category),
                  icon: Icon(
                    LucideIcons.edit3,
                    color: isActive ? Colors.white70 : Colors.grey,
                    size: 14.sp,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 16,
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _deleteCategory(id),
                  icon: Icon(
                    LucideIcons.trash2,
                    color: isActive ? Colors.white70 : Colors.grey,
                    size: 14.sp,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 16,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddFormDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width > 450.w
          ? 420.w
          : MediaQuery.of(context).size.width * 0.9,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D00),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          LucideIcons.packagePlus,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'NEW ENTRY',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'TITLE',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      onChanged: (v) => _itemName = v,
                      decoration: InputDecoration(
                        hintText: 'Dish name',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      onChanged: (v) => _itemDescription = v,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Optional details...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'MARKET PRICE (₹)',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _itemPrice = v,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'SET CATEGORY',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(
                            'Select category',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: _itemCategoryId.isEmpty
                              ? null
                              : _itemCategoryId,
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['_id'].toString(),
                                  child: Text(
                                    (c['name'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _itemCategoryId = v);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Kitchen Notification Toggle matching page.js
                    InkWell(
                      onTap: () => setState(() => _skipKitchen = !_skipKitchen),
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: _skipKitchen
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: _skipKitchen
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFFFEDD5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _skipKitchen ? LucideIcons.bellOff : LucideIcons.bell,
                                  color: _skipKitchen ? Colors.white : const Color(0xFFFF4D00),
                                  size: 20.sp,
                                ),
                                SizedBox(width: 12.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _skipKitchen ? 'NO KITCHEN ALERT' : 'KITCHEN ALERT ON',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: _skipKitchen
                                            ? Colors.white
                                            : const Color(0xFFC2410C),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _skipKitchen
                                          ? "Staff won't see this on KDS · Bill only"
                                          : "Staff will be notified when ordered",
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                        color: _skipKitchen
                                            ? Colors.grey.shade400
                                            : const Color(0xFFFB923C),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Toggle switch indicator
                            Container(
                              width: 42.w,
                              height: 22.h,
                              padding: EdgeInsets.symmetric(horizontal: 2.w),
                              decoration: BoxDecoration(
                                color: _skipKitchen ? Colors.white24 : const Color(0xFFFB923C),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              alignment: _skipKitchen ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 18.r,
                                height: 18.r,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 28.h),
                    ElevatedButton(
                      onPressed: _isActionLoading ? null : _addItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        _isActionLoading ? 'REGISTERING...' : 'ADD TO CATALOG',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44.h,
      constraints: BoxConstraints(maxWidth: 400.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16.sp, color: Colors.grey),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchTerm = v),
              decoration: const InputDecoration(
                hintText: 'Search dishes...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
