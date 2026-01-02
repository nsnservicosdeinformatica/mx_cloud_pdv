import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela de perfil do usuário
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppHeader(
        title: 'Perfil',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8F9FA),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.isMobile ? 16 : adaptive.getPadding(),
              vertical: adaptive.isMobile ? 12 : adaptive.getPadding(),
            ),
            child: Column(
              children: [
                SizedBox(height: adaptive.isMobile ? 20 : adaptive.getCardSpacing()),
                
                // Card do usuário
                _buildUserCard(context, user, adaptive),
                
                SizedBox(height: adaptive.isMobile ? 20 : adaptive.getCardSpacing() * 2),
                
                // Botão de trocar senha
                _buildChangePasswordButton(context, adaptive),
                
                SizedBox(height: adaptive.isMobile ? 16 : adaptive.getCardSpacing()),
                
                // Botão de sair
                _buildLogoutButton(context, authProvider, adaptive),
                
                // Espaço extra no final para não ficar escondido pelo bottom navigation
                SizedBox(height: adaptive.isMobile ? 100 : 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    user,
    AdaptiveLayoutProvider adaptive,
  ) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 24 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Nome
          Text(
            user?.name ?? 'Usuário',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Email
          Text(
            user?.email ?? '',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: user?.isSuperAdmin == true
                  ? AppTheme.warningColor.withOpacity(0.1)
                  : AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user?.isSuperAdmin == true ? 'Super Admin' : 'Usuário',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: user?.isSuperAdmin == true
                    ? AppTheme.warningColor
                    : AppTheme.infoColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordButton(
    BuildContext context,
    AdaptiveLayoutProvider adaptive,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: () {
            // TODO: Implementar troca de senha
          },
          borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
          child: Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: AppTheme.infoColor,
                    size: adaptive.isMobile ? 28 : 32,
                  ),
                ),
                SizedBox(width: adaptive.isMobile ? 16 : 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Trocar Senha',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: adaptive.isMobile ? 6 : 8),
                      Text(
                        'Alterar sua senha de acesso',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 13 : 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.infoColor,
                    size: adaptive.isMobile ? 16 : 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    AuthProvider authProvider,
    AdaptiveLayoutProvider adaptive,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // Confirmação antes de sair
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Confirmar Saída',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Deseja realmente sair do sistema?',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Sair',
                    style: GoogleFonts.inter(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            await authProvider.logout();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: adaptive.isMobile ? 18 : 20,
            horizontal: 24,
          ),
          backgroundColor: AppTheme.errorColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
          ),
          shadowColor: AppTheme.errorColor.withOpacity(0.3),
        ).copyWith(
          elevation: MaterialStateProperty.all(0),
        ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, size: 22),
              const SizedBox(width: 10),
              Text(
                'Sair',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 17 : 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
