import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Responsive Card Widget with adaptive sizing
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;
  final double? borderRadius;
  final VoidCallback? onTap;
  
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveMargin = ResponsiveUtils.getResponsiveMargin(context);
    final responsiveElevation = ResponsiveUtils.getResponsiveElevation(context, elevation ?? 2.0);
    final responsiveBorderRadius = ResponsiveUtils.getResponsiveBorderRadius(context, borderRadius ?? 12.0);
    
    Widget cardWidget = Container(
      padding: padding ?? responsivePadding,
      margin: margin ?? responsiveMargin,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: responsiveElevation,
            offset: Offset(0, responsiveElevation / 2),
          ),
        ],
      ),
      child: child,
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardWidget,
      );
    }
    
    return cardWidget;
  }
}

/// Responsive Button Widget
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final bool isOutlined;
  final bool isLoading;
  
  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.isOutlined = false,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = ResponsiveUtils.getResponsiveButtonHeight(context);
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 16.0);
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveBorderRadius = ResponsiveUtils.getResponsiveBorderRadius(context, 8.0);
    
    final buttonHeight = height ?? responsiveHeight;
    final buttonWidth = width ?? double.infinity;
    
    Widget buttonChild = isLoading
        ? SizedBox(
            height: buttonHeight * 0.5,
            width: buttonHeight * 0.5,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 20.0),
                  color: textColor ?? (isOutlined ? Theme.of(context).primaryColor : Colors.white),
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 8.0)),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: responsiveFontSize,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? (isOutlined ? Theme.of(context).primaryColor : Colors.white),
                ),
              ),
            ],
          );
    
    if (isOutlined) {
      return SizedBox(
        width: buttonWidth,
        height: buttonHeight,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: backgroundColor ?? Theme.of(context).primaryColor,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(responsiveBorderRadius),
            ),
            padding: responsivePadding,
          ),
          child: buttonChild,
        ),
      );
    }
    
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
          ),
          padding: responsivePadding,
          elevation: ResponsiveUtils.getResponsiveElevation(context, 2.0),
        ),
        child: buttonChild,
      ),
    );
  }
}

/// Responsive Text Widget with adaptive font sizing
class ResponsiveText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;
  
  const ResponsiveText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.style,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(
      context, 
      fontSize ?? style?.fontSize ?? 14.0,
    );
    
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: responsiveFontSize,
        fontWeight: fontWeight ?? style?.fontWeight,
        color: color ?? style?.color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive Icon Widget
class ResponsiveIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  
  const ResponsiveIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveSize = ResponsiveUtils.getResponsiveIconSize(context, size ?? 24.0);
    
    return Icon(
      icon,
      size: responsiveSize,
      color: color,
    );
  }
}

/// Responsive Container with adaptive sizing
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Decoration? decoration;
  final Alignment? alignment;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.alignment,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveMargin = ResponsiveUtils.getResponsiveMargin(context);
    
    return Container(
      width: width,
      height: height,
      padding: padding ?? responsivePadding,
      margin: margin ?? responsiveMargin,
      color: color,
      decoration: decoration,
      alignment: alignment,
      child: child,
    );
  }
}

/// Responsive ListTile Widget
class ResponsiveListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsets? contentPadding;
  
  const ResponsiveListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveHeight = ResponsiveUtils.getResponsiveListTileHeight(context);
    
    return SizedBox(
      height: responsiveHeight,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        enabled: enabled,
        contentPadding: contentPadding ?? responsivePadding,
      ),
    );
  }
}

/// Responsive Chip Widget
class ResponsiveChip extends StatelessWidget {
  final String label;
  final Widget? avatar;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? labelColor;
  final bool selected;
  
  const ResponsiveChip({
    super.key,
    required this.label,
    this.avatar,
    this.onDeleted,
    this.onTap,
    this.backgroundColor,
    this.labelColor,
    this.selected = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = ResponsiveUtils.getResponsiveChipHeight(context);
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 14.0);
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    
    return SizedBox(
      height: responsiveHeight,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: responsiveFontSize,
            color: labelColor,
          ),
        ),
        avatar: avatar,
        onDeleted: onDeleted,
        backgroundColor: backgroundColor,
        padding: responsivePadding,
      ),
    );
  }
}

/// Responsive Dialog Widget
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool barrierDismissible;
  
  const ResponsiveDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.barrierDismissible = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveDialogWidth = ResponsiveUtils.getResponsiveDialogWidth(context);
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveBorderRadius = ResponsiveUtils.getResponsiveBorderRadius(context, 16.0);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
      ),
      child: Container(
        width: responsiveDialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: responsivePadding,
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: responsivePadding,
                child: child,
              ),
            ),
            if (actions != null)
              Padding(
                padding: responsivePadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Responsive BottomSheet Widget
class ResponsiveBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final double? height;
  
  const ResponsiveBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.height,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = height != null 
        ? ResponsiveUtils.getResponsiveBottomSheetHeight(context, height!)
        : MediaQuery.of(context).size.height * 0.6;
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveBorderRadius = ResponsiveUtils.getResponsiveBorderRadius(context, 20.0);
    
    return Container(
      height: responsiveHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(responsiveBorderRadius),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: responsivePadding.top / 2),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null)
            Padding(
              padding: responsivePadding,
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 18.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: responsivePadding,
              child: child,
            ),
          ),
          if (actions != null)
            Padding(
              padding: responsivePadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Responsive Input Field Widget
class ResponsiveTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final bool enabled;
  
  const ResponsiveTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = ResponsiveUtils.getResponsiveInputHeight(context);
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 16.0);
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveBorderRadius = ResponsiveUtils.getResponsiveBorderRadius(context, 8.0);
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(fontSize: responsiveFontSize),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        contentPadding: responsivePadding,
        constraints: BoxConstraints(minHeight: responsiveHeight),
      ),
    );
  }
}
