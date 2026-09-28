import 'dart:ui';

/// Trạng thái học của một môn (điền khi Khối E import bảng điểm).
enum CourseProgressStatus { passed, failed, studying, notStarted }

extension CourseProgressStatusX on CourseProgressStatus {
  String get label {
    switch (this) {
      case CourseProgressStatus.passed:
        return 'Đã đạt';
      case CourseProgressStatus.failed:
        return 'Chưa đạt / học lại';
      case CourseProgressStatus.studying:
        return 'Đang học';
      case CourseProgressStatus.notStarted:
        return 'Chưa học';
    }
  }

  Color get color {
    switch (this) {
      case CourseProgressStatus.passed:
        return const Color(0xFF16A34A);
      case CourseProgressStatus.failed:
        return const Color(0xFFDC2626);
      case CourseProgressStatus.studying:
        return const Color(0xFF2563EB);
      case CourseProgressStatus.notStarted:
        return const Color(0xFF94A3B8);
    }
  }
}

/// Một node trên đồ thị: môn học, hoặc node học kỳ (chỉ hiện khi bật tùy chọn).
class GraphNode {
  GraphNode({
    required this.id,
    required this.title,
    required this.semester,
    required this.credits,
    this.countsInGpa = true,
    this.isSemesterNode = false,
  });

  final String id;
  final String title;
  final int semester;
  final int credits;
  final bool countsInGpa;
  final bool isSemesterNode;

  /// Số liên kết tiên quyết (vào + ra), dùng để tính kích thước node.
  int degree = 0;
  double radius = 10;

  // Trạng thái mô phỏng lực (toạ độ world, tâm = (0, 0)).
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;

  /// Khác null khi node đang bị kéo: node được giữ cố định tại vị trí này.
  Offset? pinnedAt;

  bool get isIsolated => !isSemesterNode && degree == 0;
}

enum GraphEdgeKind { prerequisite, semesterMembership }

/// Cạnh có hướng: [from] là môn tiên quyết, [to] là môn học sau.
class GraphEdge {
  const GraphEdge(this.from, this.to, {this.kind = GraphEdgeKind.prerequisite});

  final String from;
  final String to;
  final GraphEdgeKind kind;

  bool get isPrerequisite => kind == GraphEdgeKind.prerequisite;
}

/// Tham số mô phỏng lực, chỉnh được từ bảng điều khiển.
class ForceSettings {
  const ForceSettings({
    this.repulsion = 900,
    this.linkDistance = 90,
    this.centerGravity = 0.06,
  });

  final double repulsion;
  final double linkDistance;
  final double centerGravity;

  ForceSettings copyWith({double? repulsion, double? linkDistance, double? centerGravity}) {
    return ForceSettings(
      repulsion: repulsion ?? this.repulsion,
      linkDistance: linkDistance ?? this.linkDistance,
      centerGravity: centerGravity ?? this.centerGravity,
    );
  }
}

/// Lựa chọn lọc ba trạng thái: tất cả / chỉ có / chỉ không có.
enum TriFilter { all, yes, no }

/// Bộ lọc của bảng điều khiển (Mục 4.3.f).
class GraphFilters {
  const GraphFilters({
    this.semesters = const {},
    this.statuses = const {},
    this.gpa = TriFilter.all,
    this.prerequisite = TriFilter.all,
    this.showIsolated = true,
  });

  /// Rỗng nghĩa là hiện tất cả học kỳ.
  final Set<int> semesters;

  /// Rỗng nghĩa là hiện tất cả trạng thái (chỉ dùng khi đã có bảng điểm).
  final Set<CourseProgressStatus> statuses;
  final TriFilter gpa;
  final TriFilter prerequisite;
  final bool showIsolated;

  bool get isDefault =>
      semesters.isEmpty && statuses.isEmpty && gpa == TriFilter.all && prerequisite == TriFilter.all && showIsolated;

  GraphFilters copyWith({
    Set<int>? semesters,
    Set<CourseProgressStatus>? statuses,
    TriFilter? gpa,
    TriFilter? prerequisite,
    bool? showIsolated,
  }) {
    return GraphFilters(
      semesters: semesters ?? this.semesters,
      statuses: statuses ?? this.statuses,
      gpa: gpa ?? this.gpa,
      prerequisite: prerequisite ?? this.prerequisite,
      showIsolated: showIsolated ?? this.showIsolated,
    );
  }
}

/// Màu node theo học kỳ (HK0 → HK9), dùng chung cho node và chú giải.
const List<Color> kSemesterColors = [
  Color(0xFF64748B), // HK0 - Giai đoạn chuẩn bị
  Color(0xFF0EA5E9),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFA855F7),
  Color(0xFF6366F1),
  Color(0xFF14B8A6),
];

Color semesterColor(int semester) => kSemesterColors[semester.clamp(0, kSemesterColors.length - 1)];

String semesterLabel(int semester) => semester == 0 ? 'Giai đoạn 0' : 'HK$semester';

/// Màu làm rõ hướng liên kết khi hover (Mục 4.3.d).
const Color kPrerequisiteColor = Color(0xFFF59E0B); // môn tiên quyết (phía trước)
const Color kDependentColor = Color(0xFF0EA5E9); // môn phụ thuộc (phía sau)
const Color kSearchColor = Color(0xFFFACC15);
const Color kSelectionColor = Color(0xFF7C3AED);
