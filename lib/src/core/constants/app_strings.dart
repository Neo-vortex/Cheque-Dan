class AppStrings {
  AppStrings._();

  static const String appName = 'چک دان';
  static const String appSubtitle = 'مدیریت هوشمند چک‌های صیادی';

  // Navigation
  static const String dashboard = 'خانه';
  static const String cheques = 'چک‌ها';
  static const String calendar = 'تقویم';
  static const String analytics = 'گزارش‌ها';
  static const String settings = 'تنظیمات';

  // Cheque directions
  static const String issued = 'صادر شده';
  static const String received = 'دریافت شده';

  // Cheque statuses
  static const String draft = 'پیش‌نویس';
  static const String active = 'فعال';
  static const String pendingReview = 'در انتظار بررسی';
  static const String cleared = 'وصول شد';
  static const String returned = 'برگشت خورد';
  static const String cancelled = 'لغو شد';

  // Due date states
  static const String upcoming = 'در پیش';
  static const String dueToday = 'امروز سررسید';
  static const String overdue = 'گذشته';

  // Dashboard
  static const String totalExposure = 'مجموع تعهدات';
  static const String issuedTotal = 'چک‌های صادره';
  static const String receivedTotal = 'چک‌های دریافتی';
  static const String upcomingCheques = 'چک‌های پیش رو';
  static const String cashflowForecast = 'پیش‌بینی جریان نقدی';
  static const String riskStatus = 'وضعیت مالی';

  // Risk levels
  static const String safe = 'مطمئن';
  static const String warning = 'هشدار';
  static const String critical = 'بحرانی';

  // Actions
  static const String add = 'افزودن';
  static const String edit = 'ویرایش';
  static const String delete = 'حذف';
  static const String save = 'ذخیره';
  static const String cancel = 'انصراف';
  static const String confirm = 'تأیید';
  static const String search = 'جستجو';
  static const String filter = 'فیلتر';
  static const String close = 'بستن';
  static const String skip = 'رد کردن';
  static const String snooze = 'به تعویق';
  static const String markCleared = 'وصول شد';
  static const String markReturned = 'برگشت خورد';
  static const String markPending = 'در انتظار بررسی';
  static const String markAll = 'همه را علامت‌گذاری کن';

  // Fields
  static const String sayyadiId = 'شناسه صیادی';
  static const String chequeNumber = 'شماره چک';
  static const String bankName = 'نام بانک';
  static const String amount = 'مبلغ';
  static const String issueDate = 'تاریخ صدور';
  static const String dueDate = 'تاریخ سررسید';
  static const String direction = 'جهت چک';
  static const String counterparty = 'طرف حساب';
  static const String status = 'وضعیت';
  static const String note = 'یادداشت';
  static const String tags = 'برچسب‌ها';

  // Validation
  static const String fieldRequired = 'این فیلد الزامی است';
  static const String invalidAmount = 'مبلغ نامعتبر است';
  static const String invalidDate = 'تاریخ نامعتبر است';
  static const String duplicateSayyadiId = 'این شناسه صیادی قبلاً ثبت شده است';
  static const String issueDateAfterDueDate =
      'تاریخ صدور نمی‌تواند بعد از سررسید باشد';

  // Reconciliation
  static const String reconciliationTitle = 'بررسی چک‌ها';
  static const String reconciliationSubtitle =
      'چک‌هایی که نیاز به توجه دارند';
  static const String overdueSection = 'چک‌های گذشته از سررسید';
  static const String dueTodaySection = 'سررسید امروز';
  static const String upcomingSection = 'سررسیدهای نزدیک';
  static const String noChequesNeedAttention = 'همه چک‌ها در وضعیت مطلوب هستند';

  // Search
  static const String searchHint = 'جستجو در همه چک‌ها...';
  static const String noResults = 'نتیجه‌ای یافت نشد';
  static const String searchResults = 'نتایج جستجو';

  // Notifications
  static const String reminderTitle = 'یادآوری چک';
  static const String overdueTitle = 'چک معوق';

  // Settings
  static const String reminderDays = 'روزهای یادآوری';
  static const String notifications = 'اعلان‌ها';
  static const String enableNotifications = 'فعال کردن اعلان‌ها';

  // Insight messages
  static const String insightAllGood =
      'وضعیت مالی شما خوب است. همه چک‌ها در موعد مقرر هستند.';
  static const String insightWarning =
      'چند چک به سررسید نزدیک می‌شوند. آماده باشید.';
  static const String insightCritical =
      'توجه! برخی چک‌ها نیاز فوری به پیگیری دارند.';

  // Calendar
  static const String calendarTitle = 'تقویم چک‌ها';
  static const String noChequesForDay = 'چکی برای این روز ثبت نشده';

  // Analytics
  static const String analyticsTitle = 'تحلیل مالی';
  static const String incomingVsOutgoing = 'دریافتی در مقابل صادره';
  static const String chequeDistribution = 'توزیع چک‌ها';
  static const String financialPressure = 'فشار مالی';

  // Common tags
  static const List<String> commonTags = [
    'اجاره',
    'حقوق',
    'وام',
    'سرمایه‌گذاری',
    'خرید',
    'فروش',
    'خدمات',
    'ضمانت',
  ];
}
