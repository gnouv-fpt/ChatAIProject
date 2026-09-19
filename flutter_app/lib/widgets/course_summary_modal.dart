import 'package:flutter/material.dart';
import '../models/course_node.dart';

class CourseSummaryModal extends StatelessWidget {
  final CourseNode course;
  final VoidCallback onDetailsPressed;

  const CourseSummaryModal({
    super.key,
    required this.course,
    required this.onDetailsPressed,
  });

  static void show(
    BuildContext context, {
    required CourseNode course,
    required VoidCallback onDetailsPressed,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true, // Click ngoài ?? ?óng modal
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourseSummaryModal(
        course: course,
        onDetailsPressed: () {
          Navigator.of(ctx).pop(); // ?óng modal
          onDetailsPressed(); // G?i chuy?n trang
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  course.id,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              Text(
                'H?c k? ${course.semester}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            course.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.credit_card, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                '${course.credits} Tín ch?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(
                'Xem chi ti?t',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: onDetailsPressed,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}