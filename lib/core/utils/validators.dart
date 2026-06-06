/// 表单验证工具类
class Validators {
  Validators._();

  /// 验证标题（1-100 字符）
  static String? title(String? value) {
    if (value == null || value.trim().isEmpty) return '标题不能为空';
    if (value.trim().length > 100) return '标题不能超过 100 个字符';
    return null;
  }

  /// 验证邮箱
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // 可选
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return '请输入有效的邮箱地址';
    return null;
  }

  /// 验证电话号码
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // 可选
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value.trim())) return '请输入有效的手机号';
    return null;
  }

  /// 验证金额
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return null; // 可选
    final amountRegex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!amountRegex.hasMatch(value.trim())) return '请输入有效金额（最多两位小数）';
    return null;
  }

  /// 验证日期范围：start 不能晚于 end
  static String? dateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && start.isAfter(end)) {
      return '开始日期不能晚于结束日期';
    }
    return null;
  }

  /// 验证 API Key
  static String? apiKey(String? value) {
    if (value == null || value.trim().isEmpty) return 'API Key 不能为空';
    if (value.trim().length < 8) return 'API Key 长度不足';
    return null;
  }
}
