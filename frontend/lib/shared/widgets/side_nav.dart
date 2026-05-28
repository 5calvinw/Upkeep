import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/features/auth/data/auth_service.dart';

class SideNav extends StatelessWidget {
  final String activeRoute;
  final String role;
  final bool? isCompactOverride;

  const SideNav({
    super.key,
    this.activeRoute = 'dashboard',
    this.role = 'tenant',
    this.isCompactOverride,
  });

  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _bgColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final isCompact =
        isCompactOverride ?? (MediaQuery.sizeOf(context).width < 720);

    return Container(
      width: isCompact ? 73 : 256,
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(right: BorderSide(color: _slate200)),
      ),
      child: Column(
        children: [
          // Logo section
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 24,
              24,
              isCompact ? 16 : 24,
              28,
            ),
            child: Row(
              mainAxisAlignment: isCompact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF031632), Color(0xFF1A2B48)],
                    ),
                  ),
                  child: const Icon(
                    Icons.architecture,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upkeep',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _slate900,
                        ),
                      ),
                      Text(
                        'PROPERTY MANAGEMENT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _slate500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
              child: Column(
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: activeRoute == 'dashboard',
                    isCompact: isCompact,
                    onTap: () => context.go(
                      role == 'manager' ? '/manager/dashboard' : '/dashboard',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _NavItem(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Active Tickets',
                    isActive: activeRoute == 'tickets',
                    isCompact: isCompact,
                    onTap: () => context.go(
                      role == 'manager' ? '/manager/tickets' : '/tickets',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _NavItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Support',
                    isActive: activeRoute == 'support',
                    isCompact: isCompact,
                    onTap: () => context.go(
                      role == 'manager' ? '/manager/support' : '/support',
                    ),
                  ),
                  if (role == 'manager') ...[
                    const SizedBox(height: 4),
                    _NavItem(
                      icon: Icons.insights_outlined,
                      label: 'Analytics',
                      isActive: activeRoute == 'analytics',
                      isCompact: isCompact,
                      onTap: () => context.go('/manager/analytics'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom section
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _slate200)),
            ),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 10 : 16,
              17,
              isCompact ? 10 : 16,
              16,
            ),
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  isActive: false,
                  isCompact: isCompact,
                  onTap: () async {
                    await AuthService().logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isCompact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: isActive ? 1 : 0,
      shadowColor: const Color(0x1F1E293B),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : 14,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: isCompact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return isCompact ? Tooltip(message: label, child: item) : item;
  }
}
