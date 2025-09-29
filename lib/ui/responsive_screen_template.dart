import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'responsive_widgets.dart';
import 'dynamic_columns.dart';
import 'responsive_app_bar.dart';

/// Base responsive screen template for consistent layouts
class ResponsiveScreenTemplate extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final Color? backgroundColor;
  final bool showAppBar;
  final bool showBottomPadding;
  final EdgeInsets? customPadding;
  
  const ResponsiveScreenTemplate({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.drawer,
    this.endDrawer,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.backgroundColor,
    this.showAppBar = true,
    this.showBottomPadding = true,
    this.customPadding,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: showAppBar ? title : null,
      actions: actions,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      body: _buildBody(context),
    );
  }
  
  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState(context);
    }
    
    if (error != null) {
      return _buildErrorState(context);
    }
    
    return _buildContent(context);
  }
  
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16.0)),
          ResponsiveText(
            'Loading...',
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ResponsiveIcon(
              Icons.error_outline,
              size: ResponsiveUtils.getResponsiveIconSize(context, 64.0),
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16.0)),
            ResponsiveText(
              'Something went wrong',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8.0)),
            ResponsiveText(
              error!,
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24.0)),
            if (onRetry != null)
              ResponsiveButton(
                text: 'Try Again',
                onPressed: onRetry,
                width: ResponsiveUtils.getResponsiveSpacing(context, 200.0),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    final responsivePadding = customPadding ?? ResponsiveUtils.getResponsivePadding(context);
    final bottomPadding = showBottomPadding 
        ? ResponsiveUtils.getSafeAreaPadding(context).bottom 
        : 0.0;
    
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: responsivePadding.left,
        right: responsivePadding.right,
        top: responsivePadding.top,
        bottom: responsivePadding.bottom + bottomPadding,
      ),
      child: body,
    );
  }
}

/// Responsive List Screen Template
class ResponsiveListScreenTemplate extends StatelessWidget {
  final String? title;
  final List<Widget> items;
  final ContentType contentType;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final bool showGrid;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  
  const ResponsiveListScreenTemplate({
    super.key,
    this.title,
    required this.items,
    required this.contentType,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.showGrid = false,
    this.padding,
    this.physics,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenTemplate(
      title: title,
      isLoading: isLoading,
      error: error,
      onRetry: onRetry,
      body: _buildContent(context),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    if (showGrid) {
      return DynamicGridView(
        children: items,
        contentType: contentType,
        padding: padding,
        physics: physics,
      );
    } else {
      return ListView.separated(
        physics: physics,
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (context, index) => SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, 16.0),
        ),
        itemBuilder: (context, index) => items[index],
      );
    }
  }
}

/// Responsive Detail Screen Template
class ResponsiveDetailScreenTemplate extends StatelessWidget {
  final String? title;
  final Widget header;
  final List<Widget> sections;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  
  const ResponsiveDetailScreenTemplate({
    super.key,
    this.title,
    required this.header,
    required this.sections,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onRefresh,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenTemplate(
      title: title,
      isLoading: isLoading,
      error: error,
      onRetry: onRetry,
      body: _buildContent(context),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24.0)),
        ...sections.expand((section) => [
          section,
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24.0)),
        ]).take(sections.length * 2 - 1).toList(),
      ],
    );
  }
}

/// Responsive Form Screen Template
class ResponsiveFormScreenTemplate extends StatelessWidget {
  final String? title;
  final List<Widget> formFields;
  final List<Widget>? actions;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? error;
  final String? saveButtonText;
  final String? cancelButtonText;
  final bool showSaveButton;
  final bool showCancelButton;
  
  const ResponsiveFormScreenTemplate({
    super.key,
    this.title,
    required this.formFields,
    this.actions,
    this.onSave,
    this.onCancel,
    this.isLoading = false,
    this.error,
    this.saveButtonText = 'Save',
    this.cancelButtonText = 'Cancel',
    this.showSaveButton = true,
    this.showCancelButton = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenTemplate(
      title: title,
      isLoading: isLoading,
      error: error,
      body: _buildContent(context),
      actions: actions,
    );
  }
  
  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...formFields.expand((field) => [
          field,
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16.0)),
        ]).take(formFields.length * 2 - 1).toList(),
        
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 32.0)),
        
        // Action buttons
        ResponsiveLayoutBuilder(
          builder: (context, constraints) {
            if (ResponsiveUtils.isSmallScreen(context)) {
              return Column(
                children: [
                  if (showSaveButton)
                    ResponsiveButton(
                      text: saveButtonText!,
                      onPressed: isLoading ? null : onSave,
                      isLoading: isLoading,
                    ),
                  if (showSaveButton && showCancelButton)
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12.0)),
                  if (showCancelButton)
                    ResponsiveButton(
                      text: cancelButtonText!,
                      onPressed: onCancel,
                      isOutlined: true,
                    ),
                ],
              );
            } else {
              return Row(
                children: [
                  if (showCancelButton)
                    Expanded(
                      child: ResponsiveButton(
                        text: cancelButtonText!,
                        onPressed: onCancel,
                        isOutlined: true,
                      ),
                    ),
                  if (showCancelButton && showSaveButton)
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16.0)),
                  if (showSaveButton)
                    Expanded(
                      child: ResponsiveButton(
                        text: saveButtonText!,
                        onPressed: isLoading ? null : onSave,
                        isLoading: isLoading,
                      ),
                    ),
                ],
              );
            }
          },
        ),
      ],
    );
  }
}

/// Responsive Tab Screen Template
class ResponsiveTabScreenTemplate extends StatefulWidget {
  final String? title;
  final List<Widget> tabs;
  final List<String> tabLabels;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  
  const ResponsiveTabScreenTemplate({
    super.key,
    this.title,
    required this.tabs,
    required this.tabLabels,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });
  
  @override
  State<ResponsiveTabScreenTemplate> createState() => _ResponsiveTabScreenTemplateState();
}

class _ResponsiveTabScreenTemplateState extends State<ResponsiveTabScreenTemplate>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenTemplate(
      title: widget.title,
      isLoading: widget.isLoading,
      error: widget.error,
      onRetry: widget.onRetry,
      body: _buildContent(context),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadius(context, 8.0),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: widget.tabLabels.map((label) => 
              Tab(
                child: ResponsiveText(
                  label,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ).toList(),
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, 8.0),
              ),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16.0)),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.tabs,
          ),
        ),
      ],
    );
  }
}
