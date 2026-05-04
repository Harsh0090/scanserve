import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

  String _newCategory = '';
  String _itemName = '';
  String _itemPrice = '';
  String _itemCategoryId = '';
  String _itemDescription = '';

  String? _editingItemId;
  String _editName = '';
  String _editPrice = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _editNameController = TextEditingController();
    _editPriceController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMenu();
    });
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editPriceController.dispose();
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

  Future<void> _addCategory() async {
    if (_newCategory.trim().isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await apiFetch(
        '/api/${_getBaseUrl(user)}/category',
        method: 'POST',
        data: {'name': _newCategory},
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
          'basePrice': num.parse(_itemPrice),
          'categories': _itemCategoryId,
          'description': _itemDescription,
        },
      );

      setState(() {
        _itemName = '';
        _itemPrice = '';
        _itemCategoryId = '';
        _itemDescription = '';
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
    try {
      await apiFetch('/api/${_getBaseUrl(user!)}/item/$id', method: 'DELETE');
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
    try {
      await apiFetch(
        '/api/${_getBaseUrl(user!)}/item/$id',
        method: 'PATCH',
        data: {'name': _editName, 'basePrice': num.parse(_editPrice)},
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
    try {
      final res = await apiFetch(
        '/api/${_getBaseUrl(user!)}/item/$id/toggle',
        method: 'PATCH',
      );
      final updatedAvailability = res['item']['isAvailable'];

      setState(() {
        final idx = _items.indexWhere((i) => i['_id'] == id);
        if (idx != -1) {
          _items[idx] = {..._items[idx], 'isAvailable': updatedAvailability};
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Reactive: If user just loaded, initialize data
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

    final filteredItems = _items.where((i) {
      final name = (i['name'] ?? i['globalItem']?['name'] ?? '')
          .toString()
          .toLowerCase();
      final matchesSearch = name.contains(_searchTerm.toLowerCase());
      if (_activeCategory == 'all') return matchesSearch;

      final itemCatId = i['category'] is Map
          ? i['category']['_id']
          : i['category'] ??
                i['globalItem']?['category']?['_id'] ??
                i['globalItem']?['category'];
      return matchesSearch && itemCatId == _activeCategory;
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
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600.w;
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
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -1,
                                ),
                                children: [
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
                              padding: EdgeInsets.symmetric(horizontal: 32.w),
                              child: _buildSearchBar(),
                            ),
                          ),
                        Row(
                          children: [
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
                        padding: EdgeInsets.only(top: 16.h),
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
                // Desktop Category Sidebar (visible if screen width > 1024)
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
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -1,
                                ),
                                children: [
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
                        SizedBox(height: 24.h),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 450.w,
                                  mainAxisExtent: 185.h,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                            itemCount: filteredItems.length,
                            itemBuilder: (ctx, idx) {
                              final i = filteredItems[idx];
                              final isEditing = _editingItemId == i['_id'];
                              final isAvailable = i['isAvailable'] == true;

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
                                        color: Colors.black.withAlpha(5),
                                        blurRadius: 10.r,
                                        offset: Offset(0, 4.h),
                                      ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                  children: [
                                    // Image space
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

                                            if (!isAvailable)
                                              Container(
                                                color: Colors.black26,
                                                child: Center(
                                                  child: Text(
                                                    'DISABLED',
                                                    style: TextStyle(
                                                      fontSize: 9.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Details
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.r),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8.w,
                                                    vertical: 2.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isAvailable
                                                        ? Colors.orange.shade50
                                                        : Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8.r,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    (i['category'] is Map
                                                            ? i['category']['name']
                                                            : 'STANDARD')
                                                        .toString()
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 8.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: isAvailable
                                                          ? const Color(
                                                              0xFFFF4D00,
                                                            )
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 8.h),
                                                if (isEditing)
                                                  TextField(
                                                    controller:
                                                        _editNameController,
                                                    onChanged: (v) =>
                                                        _editName = v,
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      border: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: const Color(
                                                            0xFFFF4D00,
                                                          ),
                                                          width: 1.w,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    i['name'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: isAvailable
                                                          ? const Color(
                                                              0xFF0F172A,
                                                            )
                                                          : Colors.grey,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),

                                                SizedBox(height: 4.h),
                                                Text(
                                                  i['description'] ??
                                                      'Authentic ingredients prepared fresh.',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final isVerySmall =
                                                    constraints.maxWidth <
                                                    180.w;
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        if (isEditing)
                                                          Expanded(
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  '₹',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: TextField(
                                                                    controller:
                                                                        _editPriceController,
                                                                    onChanged: (v) =>
                                                                        _editPrice =
                                                                            v,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14.sp,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                    ),
                                                                    decoration: InputDecoration(
                                                                      isDense:
                                                                          true,
                                                                      contentPadding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      border: UnderlineInputBorder(
                                                                        borderSide: BorderSide(
                                                                          color: const Color(
                                                                            0xFFFF4D00,
                                                                          ),
                                                                          width:
                                                                              1.w,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          )
                                                        else
                                                          Flexible(
                                                            child: Text(
                                                              '₹${i['price'] ?? i['basePrice'] ?? 0}',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    isVerySmall
                                                                    ? 13.sp
                                                                    : 16.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color:
                                                                    isAvailable
                                                                    ? const Color(
                                                                        0xFF0F172A,
                                                                      )
                                                                    : Colors
                                                                          .grey,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        if (!isVerySmall)
                                                          _buildItemActions(
                                                            i,
                                                            isEditing,
                                                            isAvailable,
                                                          ),
                                                      ],
                                                    ),
                                                    if (isVerySmall)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 8.h,
                                                            ),
                                                        child:
                                                            _buildItemActions(
                                                              i,
                                                              isEditing,
                                                              isAvailable,
                                                            ),
                                                      ),
                                                  ],
                                                );
                                              },
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREATE SECTION',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF4D00),
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16.r),
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
          SizedBox(height: 32.h),
          Text(
            'MENU SECTIONS',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView(
              children: [
                _buildCategoryItem('all', 'All Items', count: _items.length),
                ..._categories.map(
                  (c) => _buildCategoryItem(c['_id'], c['name'], category: c),
                ),
              ],
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
        padding: EdgeInsets.all((label == 'All Items') ? 16.sp : 7.sp),
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
                    color: isActive ? Colors.white : Colors.grey,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else ...[
              // if (isActive)
              //   Icon(
              //     LucideIcons.chevronRight,
              //     color: Colors.white,
              //     size: 16.sp,
              //   ),
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
      width: MediaQuery.of(context).size.width > 400.w
          ? 400.w
          : MediaQuery.of(context).size.width * 0.9,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D00),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      LucideIcons.packagePlus,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'NEW ENTRY',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
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
                        fontSize: 14.sp,
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
                      maxLines: 4,
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
                        fontSize: 14.sp,
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
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'CATEGORY',
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
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: _itemCategoryId.isEmpty
                              ? null
                              : _itemCategoryId,
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['_id'],
                                  child: Text(
                                    c['name'],
                                    style: TextStyle(
                                      fontSize: 14.sp,
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
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: _isActionLoading ? null : _addItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
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
      height: 48.h,
      constraints: BoxConstraints(maxWidth: 400.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18.sp, color: Colors.grey),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchTerm = v),
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemActions(dynamic i, bool isEditing, bool isAvailable) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => _toggleItem(i['_id']),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: isAvailable
                ? Colors.green.shade50
                : Colors.grey.shade100,
            elevation: 0,
          ),
          child: Text(
            isAvailable ? 'DISABLED' : 'ENABLED',
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w900,
              color: isAvailable ? Colors.green : Colors.grey,
            ),
          ),
        ),
        SizedBox(width: 4.w),
        if (isEditing)
          IconButton(
            onPressed: () => _saveEdit(i['_id']),
            icon: Icon(LucideIcons.check, size: 16.sp, color: Colors.green),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          )
        else
          IconButton(
            onPressed: () {
              setState(() {
                _editingItemId = i['_id'];
                _editName = i['name'] ?? '';
                _editPrice = (i['price'] ?? i['basePrice'] ?? 0).toString();
                _editNameController.text = _editName;
                _editPriceController.text = _editPrice;
              });
            },
            icon: Icon(LucideIcons.edit3, size: 16.sp, color: Colors.black87),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        SizedBox(width: 4.w),
        IconButton(
          onPressed: () => _deleteItem(i['_id']),
          icon: Icon(LucideIcons.trash2, size: 16.sp, color: Colors.grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
      ],
    );
  }
}
