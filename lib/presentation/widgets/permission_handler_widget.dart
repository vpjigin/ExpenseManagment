import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/services/permission_service.dart';
import 'permission_explanation_dialog.dart';

/// Widget that handles SMS permission flow
class PermissionHandlerWidget extends StatefulWidget {
  final Widget child;

  const PermissionHandlerWidget({
    super.key,
    required this.child,
  });

  @override
  State<PermissionHandlerWidget> createState() =>
      _PermissionHandlerWidgetState();
}

class _PermissionHandlerWidgetState extends State<PermissionHandlerWidget> {
  bool _isCheckingPermission = true;
  bool _hasShownDialog = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure widget is fully built before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermission();
    });
  }

  Future<void> _checkAndRequestPermission() async {
    try {
      // Add a timeout to prevent infinite loading
      await _performPermissionCheck().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // Timeout - stop loading and show app
          if (mounted) {
            setState(() {
              _isCheckingPermission = false;
            });
          }
        },
      );
    } catch (e) {
      // If there's any error, stop loading
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _performPermissionCheck() async {
    // Check if permission is already granted
    bool isGranted = false;
    try {
      isGranted = await PermissionService.isPermissionGranted();
    } catch (e) {
      // If check fails, assume not granted
      isGranted = false;
    }
    
    if (isGranted) {
      // Permission already granted - no need to show dialog
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
      return;
    }

    // Permission not granted - check if we've asked in this session
    if (!_hasShownDialog && mounted) {
      _hasShownDialog = true;
      // Wait a bit for UI to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showPermissionDialog();
        // Keep loading state until user interacts with dialog
        return;
      }
    }
    
    // If dialog was already shown in this session, just stop loading
    if (mounted) {
      setState(() {
        _isCheckingPermission = false;
      });
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    
    // Use SchedulerBinding to ensure the frame is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Show dialog immediately
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PermissionExplanationDialog(
            onGrantPermission: () {
              Navigator.of(dialogContext).pop();
              _requestPermission();
            },
            onSkip: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                setState(() {
                  _isCheckingPermission = false;
                });
              }
            },
          );
        },
      );
    });
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await PermissionService.requestPermission();
      
      if (!granted && mounted) {
        // Permission denied - check if permanently denied
        try {
          final status = await ph.Permission.sms.status;
          
          if (status.isPermanentlyDenied) {
            _showSettingsDialog();
          } else {
            if (mounted) {
              setState(() {
                _isCheckingPermission = false;
              });
            }
          }
        } catch (e) {
          // If status check fails, just continue
          if (mounted) {
            setState(() {
              _isCheckingPermission = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isCheckingPermission = false;
          });
        }
      }
    } catch (e) {
      // If request fails, just continue
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  void _showSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'SMS permission is required for automatic expense detection. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                setState(() {
                  _isCheckingPermission = false;
                });
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await PermissionService.openAppSettings();
              if (mounted) {
                setState(() {
                  _isCheckingPermission = false;
                });
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      // Show loading indicator while checking permission
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}
