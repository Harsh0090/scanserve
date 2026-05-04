import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dio/dio.dart' as dio;
import '../../../utils/apiClient.dart';

class PaymentSetupPage extends StatefulWidget {
  const PaymentSetupPage({super.key});

  @override
  State<PaymentSetupPage> createState() => _PaymentSetupPageState();
}

class _PaymentSetupPageState extends State<PaymentSetupPage> {
  final TextEditingController _upiController = TextEditingController();
  File? _qrFile;
  String? _qrPreviewUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/restaurants/payment');
      if (data != null && data['payment'] != null) {
        setState(() {
          _upiController.text = data['payment']['upiId'] ?? '';
          _qrPreviewUrl = data['payment']['qrImageUrl'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFileChange() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _qrFile = File(image.path);
        _qrPreviewUrl = null; // Clear URL preview to show local file preview
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSaving = true);
    try {
      final formDataMap = <String, dynamic>{
        'upiId': _upiController.text,
      };

      if (_qrFile != null) {
        formDataMap['qr'] = await dio.MultipartFile.fromFile(
          _qrFile!.path,
          filename: _qrFile!.path.split('/').last,
        );
      }

      final formData = dio.FormData.fromMap(formDataMap);

      await apiFetch(
        '/api/restaurants/payment',
        method: 'PATCH',
        data: formData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment settings updated successfully!')),
        );
        _fetchSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 500.w),
            padding: EdgeInsets.all(32.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 30.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Settings',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    
                    // UPI ID Input
                    Text(
                      'UPI ID',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _upiController,
                      decoration: InputDecoration(
                        hintText: 'e.g., restaurant@okaxis',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: Color(0xFFFF5C00)),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // QR Code Upload
                    Text(
                      'QR Code Image',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: _handleFileChange,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.image, size: 20.sp, color: Colors.grey),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                _qrFile != null 
                                  ? _qrFile!.path.split('/').last 
                                  : 'Click to select file...',
                                style: TextStyle(
                                  color: _qrFile != null ? const Color(0xFF0F172A) : Colors.grey,
                                  fontStyle: _qrFile != null ? FontStyle.normal : FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Preview Area
                    Text(
                      'Current QR Code Preview',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 200.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: _buildPreview(),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C00),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleType.circular(12.r),
                          elevation: 0,
                        ),
                        child: _isSaving 
                          ? SizedBox(
                              height: 20.h,
                              width: 20.h,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_qrFile != null) {
      return Image.file(_qrFile!, fit: BoxFit.contain);
    } else if (_qrPreviewUrl != null && _qrPreviewUrl!.isNotEmpty) {
      return Image.network(
        _qrPreviewUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)));
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text('Failed to load image', style: TextStyle(color: Colors.red)),
        ),
      );
    } else {
      return Center(
        child: Text(
          'No QR code available',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 14.sp),
        ),
      );
    }
  }
}

extension RoundedRectangleType on RoundedRectangleBorder {
  static RoundedRectangleBorder circular(double radius) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );
}
