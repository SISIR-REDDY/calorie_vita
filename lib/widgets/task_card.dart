import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Professional task card widget for displaying individual tasks
class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onToggleCompletion;
  final VoidCallback onDelete;
  final bool showActions;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleCompletion,
    required this.onDelete,
    this.showActions = true,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _strikethroughAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _strikethroughAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.task.isCompleted) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.isCompleted != oldWidget.task.isCompleted) {
      if (widget.task.isCompleted) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _strikethroughAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.task.isCompleted 
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: context.isDarkMode ? 0.3 : 0.1),
              width: widget.task.isCompleted ? 2 : 1,
            ),
            boxShadow: context.cardShadow,
          ),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 12 : 16),
            child: Row(
              children: [
                _buildCompletionIndicator(),
                const SizedBox(width: 12),
                _buildEmoji(),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTaskContent(context),
                ),
                if (widget.showActions) _buildActions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletionIndicator() {
    return GestureDetector(
      onTap: () {
        if (kDebugMode) debugPrint('🎯 Circle tapped for task: ${widget.task.title}');
        widget.onToggleCompletion();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.task.isCompleted 
                ? Colors.green
                : Colors.grey.withValues(alpha: 0.5),
            width: 2,
          ),
          color: widget.task.isCompleted 
              ? Colors.green
              : Colors.transparent,
        ),
        child: widget.task.isCompleted
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 18,
              )
            : null,
      ),
    );
  }

  Widget _buildEmoji() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: context.isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          widget.task.emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildTaskContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.task.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: widget.task.isCompleted 
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: widget.task.isCompleted 
                      ? Colors.grey[500]
                      : context.textPrimary,
                  decoration: widget.task.isCompleted 
                      ? TextDecoration.lineThrough
                      : null,
                  decorationThickness: 2.0,
                  decorationColor: Colors.grey[400],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (widget.task.description != null && widget.task.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.task.description!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: widget.task.isCompleted 
                  ? Colors.grey[400]
                  : context.textSecondary,
              decoration: widget.task.isCompleted 
                  ? TextDecoration.lineThrough
                  : null,
              decorationThickness: 1.5,
              decorationColor: Colors.grey[300],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _formatDate(widget.task.createdAt),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
            if (widget.task.isOverdue) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'OVERDUE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }


  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            if (kDebugMode) debugPrint('🗑️ Delete button tapped for task: ${widget.task.title}');
            widget.onDelete();
          },
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.withValues(alpha: 0.7),
            size: 20,
          ),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Empty state widget for when there are no tasks
class EmptyTasksWidget extends StatelessWidget {
  final VoidCallback onAddTask;

  const EmptyTasksWidget({
    super.key,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt,
              size: 40,
              color: kAccentColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tasks yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first task to get started\nand stay organized!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'Add Your First Task',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example tasks widget for showing sample tasks
class ExampleTasksWidget extends StatelessWidget {
  final VoidCallback onAddTask;

  const ExampleTasksWidget({
    super.key,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kAccentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: kAccentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Example Tasks',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kAccentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Here are some example tasks to get you started:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...ExampleTasks.tasks.take(3).map((taskData) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  taskData['emoji'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    taskData['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              'Create Your Own Task',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

