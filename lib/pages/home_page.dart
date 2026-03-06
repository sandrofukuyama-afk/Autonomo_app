import 'package:flutter/material.dart';

import 'entries_page.dart';
import 'expenses_page.dart';
import 'reports_page.dart';

/// Página principal do aplicativo com dashboard inicial e navegação.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _goToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Entradas';
      case 2:
        return 'Saídas';
      case 3:
        return 'Relatórios';
      default:
        return 'Autonomo App';
    }
  }

  String _getAppBarSubtitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Cadastro e controle de receitas';
      case 2:
        return 'Cadastro e organização de despesas';
      case 3:
        return 'Acompanhe resultados mensais e anuais';
      default:
        return 'Gestão financeira para autônomos no Japão';
    }
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 1:
        return const EntriesPage();
      case 2:
        return const ExpensesPage();
      case 3:
        return const ReportsPage();
      default:
        return _DashboardPage(
          onOpenEntries: () => _goToTab(1),
          onOpenExpenses: () => _goToTab(2),
          onOpenReports: () => _goToTab(3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        toolbarHeight: 76,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getAppBarTitle(),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getAppBarSubtitle(),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: const Color(0xFF7B8794),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Entradas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off_csred_outlined),
            activeIcon: Icon(Icons.money_off_csred),
            label: 'Saídas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.onOpenEntries,
    required this.onOpenExpenses,
    required this.onOpenReports,
  });

  final VoidCallback onOpenEntries;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final EdgeInsets pagePadding = EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16,
          vertical: 18,
        );

        return SingleChildScrollView(
          padding: pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(
                onPrimaryAction: onOpenEntries,
                onSecondaryAction: onOpenReports,
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Visão geral',
                subtitle: 'Resumo rápido da operação financeira do aplicativo.',
              ),
              const SizedBox(height: 12),
              _SummaryGrid(isWide: isWide),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Acesso rápido',
                subtitle: 'Atalhos para as áreas mais usadas no dia a dia.',
              ),
              const SizedBox(height: 12),
              _QuickActions(
                isWide: isWide,
                onOpenEntries: onOpenEntries,
                onOpenExpenses: onOpenExpenses,
                onOpenReports: onOpenReports,
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Recursos do sistema',
                subtitle: 'Estrutura pensada para o controle financeiro do autônomo.',
              ),
              const SizedBox(height: 12),
              _FeaturesGrid(isWide: isWide),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1976D2),
            Color(0xFF0F4C81),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(25, 118, 210, 0.18),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bem-vindo ao seu painel financeiro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Organize entradas, saídas, relatórios e recibos em um único lugar. '
            'Esta base foi preparada para evoluir para um sistema completo de produção.',
            style: TextStyle(
              color: Color(0xFFE8F1FB),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F4C81),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Nova entrada'),
              ),
              OutlinedButton.icon(
                onPressed: onSecondaryAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Ver relatórios'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = const [
      _SummaryCard(
        title: 'Entradas',
        value: '¥ 0,00',
        subtitle: 'Receitas registradas',
        icon: Icons.south_west_rounded,
        iconBackground: Color(0xFFE7F6EC),
        iconColor: Color(0xFF1E8E3E),
      ),
      _SummaryCard(
        title: 'Saídas',
        value: '¥ 0,00',
        subtitle: 'Despesas registradas',
        icon: Icons.north_east_rounded,
        iconBackground: Color(0xFFFDECEC),
        iconColor: Color(0xFFD93025),
      ),
      _SummaryCard(
        title: 'Saldo',
        value: '¥ 0,00',
        subtitle: 'Resultado atual',
        icon: Icons.account_balance_wallet_outlined,
        iconBackground: Color(0xFFE8F0FE),
        iconColor: Color(0xFF1967D2),
      ),
      _SummaryCard(
        title: 'Relatórios',
        value: 'Mensal / Anual',
        subtitle: 'Acompanhamento consolidado',
        icon: Icons.insert_chart_outlined,
        iconBackground: Color(0xFFF3E8FF),
        iconColor: Color(0xFF7B1FA2),
      ),
    ];

    if (isWide) {
      return GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        children: cards,
      );
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isWide,
    required this.onOpenEntries,
    required this.onOpenExpenses,
    required this.onOpenReports,
  });

  final bool isWide;
  final VoidCallback onOpenEntries;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [
      _QuickActionCard(
        title: 'Nova Entrada',
        subtitle: 'Registre uma receita rapidamente.',
        icon: Icons.add_card_rounded,
        color: const Color(0xFF1976D2),
        onTap: onOpenEntries,
      ),
      _QuickActionCard(
        title: 'Nova Saída',
        subtitle: 'Cadastre uma despesa do dia.',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFD32F2F),
        onTap: onOpenExpenses,
      ),
      _QuickActionCard(
        title: 'Ver Relatórios',
        subtitle: 'Consulte visão mensal e anual.',
        icon: Icons.query_stats_rounded,
        color: const Color(0xFF388E3C),
        onTap: onOpenReports,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  const _FeaturesGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = const [
      _FeatureCard(
        icon: Icons.account_balance_outlined,
        title: 'Controle financeiro',
        description:
            'Organização prática de receitas e despesas em uma estrutura simples e escalável.',
      ),
      _FeatureCard(
        icon: Icons.calendar_month_outlined,
        title: 'Relatórios mensais e anuais',
        description:
            'Acompanhamento consolidado para enxergar resultado, fluxo e evolução do negócio.',
      ),
      _FeatureCard(
        icon: Icons.photo_camera_outlined,
        title: 'Recibos por foto',
        description:
            'Base pronta para evoluir para captura de comprovantes usando a câmera do celular.',
      ),
      _FeatureCard(
        icon: Icons.folder_open_outlined,
        title: 'Organização de despesas',
        description:
            'Estrutura pensada para separar gastos operacionais e apoiar abatimentos futuros.',
      ),
    ];

    if (isWide) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        children: items,
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: const Color(0xFF1976D2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFFE5E7EB),
      width: 1,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(15, 23, 42, 0.04),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}
