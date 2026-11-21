import '../../core/supabase.dart';
import 'dashboard_figures.dart';

/// The codes `admin_dashboard` raises, in the app's words.
const dashboardErrors = {
  'forbidden': 'لوحة المتابعة للمشرفين فقط.',
  'bad_period': 'اختر فترة تنتهي بعد بدايتها.',
};

/// US-39: the dashboard figures for one period. The database refuses anyone who is not an administrator.
class DashboardRepository {
  Future<DashboardFigures> load(DashboardPeriod period) async {
    final rows = await db.rpc('admin_dashboard', params: {
      'p_from': period.from.toUtc().toIso8601String(),
      'p_to': period.to.toUtc().toIso8601String(),
    }) as List;
    return DashboardFigures.fromMap(rows.first as Map<String, dynamic>);
  }
}
