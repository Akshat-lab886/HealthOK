import 'package:flutter/material.dart';
import 'package:health/health.dart' as health;
import 'package:health_ok/main.dart' show AppColors;

class PermissionManagerPage extends StatefulWidget {
  const PermissionManagerPage({super.key});

  @override
  State<PermissionManagerPage> createState() => _PermissionManagerPageState();
}

class _PermissionManagerPageState extends State<PermissionManagerPage> {
  final health.Health _health = health.Health();
  Map<health.HealthDataType, bool> _permissionStatus = {};
  bool _isLoading = false;

  final List<health.HealthDataType> _dataTypes = [
    health.HealthDataType.STEPS,
    health.HealthDataType.DISTANCE_DELTA,
    health.HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  List<health.HealthDataAccess> get _permissions =>
      _dataTypes.map((_) => health.HealthDataAccess.READ).toList();

  static const _typeInfo = {
    health.HealthDataType.STEPS: (
      icon: Icons.directions_walk_rounded,
      label: 'Steps',
      color: AppColors.stepsColor,
    ),
    health.HealthDataType.DISTANCE_DELTA: (
      icon: Icons.route_rounded,
      label: 'Distance',
      color: AppColors.distanceColor,
    ),
    health.HealthDataType.ACTIVE_ENERGY_BURNED: (
      icon: Icons.local_fire_department_rounded,
      label: 'Active Energy',
      color: AppColors.energyColor,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    try {
      final statuses = <health.HealthDataType, bool>{};
      for (final type in _dataTypes) {
        final has = await _health.hasPermissions([type]);
        statuses[type] = has ?? false;
      }
      setState(() {
        _permissionStatus = statuses;
        _isLoading = false;
      });
      if (statuses.values.any((granted) => !granted)) {
        Future.delayed(const Duration(milliseconds: 500), _requestPermissions);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _health.requestAuthorization(
        _dataTypes,
        permissions: _permissions,
      );
      if (granted) {
        await _loadPermissions();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _permissionStatus.values.isNotEmpty &&
        _permissionStatus.values.every((g) => g);

    return Container(
      decoration:  BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon:  Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          title:  Text(
            'Permissions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              icon:  Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: _loadPermissions,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
            : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: allGranted
                          ? const LinearGradient(
                              colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: (allGranted
                                  ? AppColors.success
                                  : AppColors.primary)
                              .withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          allGranted
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          color: allGranted ? AppColors.success : Colors.white,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allGranted ? 'All Granted' : 'Access Required',
                          style: TextStyle(
                            color: allGranted
                                ? AppColors.textPrimary
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allGranted
                              ? 'Health Connect access is fully configured.'
                              : 'Grant access to read your health data from Health Connect.',
                          style: TextStyle(
                            color: allGranted
                                ? AppColors.textSecondary
                                : Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permissions list
                  Text(
                    'Data Types',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._dataTypes.map((type) {
                    final granted = _permissionStatus[type] ?? false;
                    final info = _typeInfo[type];
                    if (info == null) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: info.color.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: info.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(info.icon, color: info.color, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.label,
                                  style:  TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  granted
                                      ? 'Read access granted'
                                      : 'Read access required',
                                  style: TextStyle(
                                    color: granted
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: granted
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.energyColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              granted
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: granted
                                  ? AppColors.success
                                  : AppColors.energyColor,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Request button
                  if (!allGranted)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: GestureDetector(
                        onTap: _requestPermissions,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Grant Permissions',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
