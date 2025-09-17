import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'advanced_tool_dashboard_viewmodel.dart';
import 'widgets/advanced_tool_overview_widget.dart';
import 'widgets/tool_inventory_widget.dart';
import 'widgets/tool_checkout_widget.dart';
import 'widgets/tool_reservations_widget.dart';
import 'widgets/tool_sharing_widget.dart';
import 'widgets/tool_condition_widget.dart';
import 'widgets/tool_performance_widget.dart';
import 'widgets/tool_warranty_widget.dart';
import 'widgets/tool_cost_tracking_widget.dart';

class AdvancedToolDashboardView extends StackedView<AdvancedToolDashboardViewModel> {
  const AdvancedToolDashboardView({super.key});

  @override
  Widget builder(
    BuildContext context,
    AdvancedToolDashboardViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Tool Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: viewModel.refreshData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: viewModel.handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_data',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 8),
                    Text('Reports'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Section
                  AdvancedToolOverviewWidget(
                    stats: viewModel.overviewStats,
                    onStatsTap: viewModel.handleStatsTap,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Tab View for different sections
                  Container(
                    height: 600,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DefaultTabController(
                      length: 8,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: TabBar(
                              isScrollable: true,
                              indicatorColor: Colors.blue,
                              labelColor: Colors.blue,
                              unselectedLabelColor: Colors.grey[600],
                              tabs: const [
                                Tab(text: 'Inventory'),
                                Tab(text: 'Check-out'),
                                Tab(text: 'Reservations'),
                                Tab(text: 'Sharing'),
                                Tab(text: 'Condition'),
                                Tab(text: 'Performance'),
                                Tab(text: 'Warranty'),
                                Tab(text: 'Costs'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Inventory Tab
                                ToolInventoryWidget(
                                  inventory: viewModel.inventory,
                                  onItemTap: viewModel.handleInventoryItemTap,
                                  onAddItem: viewModel.showAddInventoryDialog,
                                  onEditItem: viewModel.showEditInventoryDialog,
                                ),
                                
                                // Check-out Tab
                                ToolCheckoutWidget(
                                  checkouts: viewModel.activeCheckouts,
                                  overdueCheckouts: viewModel.overdueCheckouts,
                                  onCheckout: viewModel.showCheckoutDialog,
                                  onCheckin: viewModel.showCheckinDialog,
                                  onExtend: viewModel.showExtendCheckoutDialog,
                                ),
                                
                                // Reservations Tab
                                ToolReservationsWidget(
                                  reservations: viewModel.upcomingReservations,
                                  pendingApprovals: viewModel.pendingReservations,
                                  onCreateReservation: viewModel.showCreateReservationDialog,
                                  onApproveReservation: viewModel.approveReservation,
                                  onRejectReservation: viewModel.showRejectReservationDialog,
                                ),
                                
                                // Sharing Tab
                                ToolSharingWidget(
                                  incomingRequests: viewModel.incomingSharingRequests,
                                  outgoingRequests: viewModel.outgoingSharingRequests,
                                  activeSharing: viewModel.activeSharing,
                                  onRequestSharing: viewModel.showRequestSharingDialog,
                                  onApproveSharing: viewModel.approveSharingRequest,
                                  onRejectSharing: viewModel.showRejectSharingDialog,
                                ),
                                
                                // Condition Tab
                                ToolConditionWidget(
                                  conditionReports: viewModel.recentConditionReports,
                                  requiresAction: viewModel.reportsRequiringAction,
                                  onCreateReport: viewModel.showCreateConditionReportDialog,
                                  onViewReport: viewModel.viewConditionReport,
                                  onTakeAction: viewModel.showTakeActionDialog,
                                ),
                                
                                // Performance Tab
                                ToolPerformanceWidget(
                                  performanceMetrics: viewModel.recentPerformanceMetrics,
                                  decliningTools: viewModel.decliningPerformanceTools,
                                  onRecordMetric: viewModel.showRecordMetricDialog,
                                  onViewTrends: viewModel.viewPerformanceTrends,
                                  onGenerateAlert: viewModel.generatePerformanceAlert,
                                ),
                                
                                // Warranty Tab
                                ToolWarrantyWidget(
                                  expiringWarranties: viewModel.expiringWarranties,
                                  activeWarranties: viewModel.activeWarranties,
                                  renewalRecommendations: viewModel.warrantyRenewals,
                                  onCreateWarranty: viewModel.showCreateWarrantyDialog,
                                  onExtendWarranty: viewModel.showExtendWarrantyDialog,
                                  onCreateClaim: viewModel.showCreateClaimDialog,
                                ),
                                
                                // Costs Tab
                                ToolCostTrackingWidget(
                                  recentCosts: viewModel.recentCosts,
                                  budgetAnalysis: viewModel.budgetAnalysis,
                                  topCostTools: viewModel.topCostTools,
                                  onRecordCost: viewModel.showRecordCostDialog,
                                  onViewCostAnalytics: viewModel.viewCostAnalytics,
                                  onGenerateReport: viewModel.generateCostReport,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.showQuickActionMenu,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('Quick Action'),
      ),
    );
  }

  @override
  AdvancedToolDashboardViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      AdvancedToolDashboardViewModel();
}