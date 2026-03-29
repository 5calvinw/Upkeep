import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/auth_service.dart';

class SideNav extends StatelessWidget {
  final String activeRoute;
  final String role;

  const SideNav({super.key, this.activeRoute = 'dashboard', this.role = 'tenant'});

  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _bgColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(right: BorderSide(color: _slate200)),
      ),
      child: Column(
        children: [
          // Logo section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
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
                  child: const Icon(Icons.architecture, color: Colors.white, size: 20),
                ),
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
            ),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: activeRoute == 'dashboard',
                    onTap: () => context.go(
                      role == 'manager' ? '/manager/dashboard' : '/dashboard',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _NavItem(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Active Tickets',
                    isActive: activeRoute == 'tickets',
                    onTap: () => context.go(
                      role == 'manager' ? '/manager/tickets' : '/dashboard',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _NavItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Support',
                    isActive: activeRoute == 'support',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // Bottom section
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _slate200)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  isActive: false,
                  onTap: () {},
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  isActive: false,
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      elevation: isActive ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
