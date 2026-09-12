class LegalSpecializations {
  static const int maxLawyerSpecializations = 3;
  static const String uncertainClientChoice = 'لا أعرف التخصص المناسب';

  /// Lawyer-selectable specializations only. A broad/general specialization is
  /// intentionally excluded so lawyers cannot appear in every category.
  static const List<String> all = [
    'إداري',
    'قوى الأمن الداخلي',
    'شركات',
    'تسجيل عقاري',
    'معاملات مؤسسة الشهداء',
    'أحوال شخصية',
    'مدني',
    'جنائي',
    'تجاري',
    'عمالي',
    'ضمان اجتماعي',
    'مروري',
    'عقود واتفاقيات',
    'صياغة العقود',
    'تحصيل الديون',
    'تنفيذ الأحكام',
    'دعاوى التعويض',
    'ملكية فكرية',
    'علامات تجارية',
    'ضرائب',
    'كمارك',
    'استثمار',
    'مصارف وتمويل',
    'منازعات عقارية',
    'إيجارات',
    'مقاولات',
    'مناقصات حكومية',
    'قضايا الأسرة والطفولة',
    'إرث ووصايا',
    'نفقة وحضانة',
    'زواج وطلاق',
    'قضايا المخدرات',
    'قضايا إلكترونية',
    'قضايا عسكرية',
    'قضايا دولية',
    'إقامة وجنسية',
    'تأسيس الشركات',
    'تصفية الشركات',
    'الوكالات التجارية',
    'تسجيل العلامات والبراءات',
    'منازعات العمل',
    'التأمين',
    'الوساطة والتحكيم',
  ];

  /// Client-facing categories add one neutral choice for users who do not know
  /// which legal field applies to their matter. It is not a lawyer specialty.
  static const List<String> clientChoices = [uncertainClientChoice, ...all];
}
