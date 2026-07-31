abstract final class AppConstants {
  static const appName = 'GST Expense Admin';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/v1',
  );
}

abstract final class ApiPaths {
  static const login = '/admin/auth/login';
  static const dashboard = '/admin/dashboard';
  static const invoices = '/admin/invoices';
  static const employees = '/admin/employees';
  static const categories = '/admin/categories';
  static const branches = '/admin/branches';
  static const settings = '/admin/company/settings';
  static const announcements = '/admin/announcements';
  static const itcStatus = '/admin/itc/status';
  static const itcImport = '/admin/itc/import';
  static const itcImports = '/admin/itc/imports';
  static const itcSummary = '/admin/itc/summary';
  static const itcMatches = '/admin/itc/matches';
  static const itcReconcile = '/admin/itc/reconcile';
  static const itcRemindMissing = '/admin/itc/remind-missing';
  static const itcReminders = '/admin/itc/reminders';
  static const itcExport = '/admin/itc/matches/export';
  static const plans = '/super/plans';
  static const companies = '/super/companies';
}
