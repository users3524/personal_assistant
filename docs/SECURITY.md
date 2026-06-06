# 数据安全说明

## 一、敏感数据范围

| 数据类型 | 存储位置 | 敏感等级 |
|----------|----------|----------|
| AI API Key | `user_preferences.ai_api_key` | 🔴 高 |
| 用户个人信息（姓名、电话、邮箱） | `resume_profile` 表 | 🟡 中 |
| 藏品购入价格、当前估值 | `antique_items` 表 | 🟡 中 |
| 备份文件（全量数据） | 用户指定路径 | 🔴 高 |
| 用户复盘内容 | `daily_reviews` 表 | 🟢 低 |

## 二、API Key 加密存储

### 2.1 方案

使用 `encrypt` 包的 AES-256-CBC 算法对 API Key 进行加密后存入数据库。

```dart
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

class SecureStorage {
  // 密钥派生：使用设备唯一标识 + 应用内置 salt
  static final _key = encrypt.Key.fromUtf8(_deriveKey());
  static final _iv = encrypt.IV.fromLength(16);

  static String _deriveKey() {
    // 使用 device_info_plus 获取设备 ID + 固定 salt 派生 32 字节密钥
    // 实际实现使用 PBKDF2 或类似算法
    return '01234567890123456789012345678901'; // 32 字节占位
  }

  static String encryptApiKey(String plainText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decryptApiKey(String encryptedText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    return encrypter.decrypt64(encryptedText, iv: _iv);
  }
}
```

> **注意**：密钥派生应使用 `device_info_plus` 获取设备 ID 作为种子，确保同一设备可解密，不同设备不可解密。

### 2.2 使用流程

```
用户输入 API Key
      │
      ▼
SecureStorage.encryptApiKey() ──► base64 密文 ──► 存入 user_preferences.ai_api_key
                                                         │
                                                         ▼
读取时 ──► SecureStorage.decryptApiKey() ──► 明文 ──► 传入 AI 服务
```

## 三、备份文件加密

### 3.1 方案

导出备份时使用用户输入的独立密码进行 AES-256-CBC 加密。

```dart
class BackupService {
  /// 导出备份：遍历所有表 → JSON → AES 加密 → 写入文件
  Future<void> exportBackup({
    required AppDatabase db,
    required String password,
    required String filePath,
  }) async {
    // 1. 收集所有数据（剔除敏感字段）
    final data = await _collectAllData(db);

    // 2. 序列化为 JSON
    final jsonStr = jsonEncode(data);

    // 3. 从密码派生 32 字节密钥（PBKDF2）
    final key = _deriveKeyFromPassword(password);

    // 4. AES-256-CBC 加密
    final encrypted = _encrypt(jsonStr, key);

    // 5. 写入文件（包含加密元数据：salt, iv, 版本号）
    await File(filePath).writeAsString(encrypted);
  }

  /// 导入备份：读取文件 → AES 解密 → 验证 → 写入数据库
  Future<void> importBackup({
    required AppDatabase db,
    required String password,
    required String filePath,
  }) async {
    // 1. 读取加密文件
    final encrypted = await File(filePath).readAsString();

    // 2. 从密码派生密钥
    final key = _deriveKeyFromPassword(password);

    // 3. AES-256-CBC 解密
    final jsonStr = _decrypt(encrypted, key);

    // 4. 解析 JSON
    final data = jsonDecode(jsonStr);

    // 5. 验证数据完整性（校验和）
    // 6. 清空数据库并写入
    await _restoreAllData(db, data);
  }
}
```

### 3.2 备份文件格式

```json
{
  "version": 1,
  "exportedAt": "2024-01-15T21:00:00Z",
  "schemaVersion": 1,
  "data": {
    "todos": [...],
    "antique_items": [...],
    "valuation_records": [...],
    "patting_logs": [...],
    "daily_reviews": [...],
    "weekly_reports": [...],
    "resume_profile": {...},
    "work_experiences": [...],
    "educations": [...],
    "skill_items": [...],
    "project_experiences": [...]
  },
  "checksum": "sha256_of_data"
}
```

### 3.3 导出时剔除的字段

| 表 | 剔除字段 | 原因 |
|----|----------|------|
| `user_preferences` | `ai_api_key` | API Key 不应离开当前设备 |
| `user_preferences` | `id` | 重建时自动生成 |

## 四、安全规范清单

| 序号 | 规范 | 说明 |
|------|------|------|
| 1 | API Key 绝不以明文存储 | 入库前 AES 加密 |
| 2 | 备份文件不含 API Key | 导出时主动剔除 |
| 3 | 备份文件必须加密 | 用户输入独立密码，AES-256-CBC |
| 4 | 不记录用户密码 | 所有密码即时派生为密钥，不落盘 |
| 5 | 敏感信息不输出日志 | 日志中不可打印 API Key、密码 |
| 6 | 图片文件不包含 EXIF | 存储前清除 EXIF 信息 |
| 7 | 数据库文件默认加密 | 使用 sqlcipher（可选增强） |

## 五、安全建议（用户侧）

1. **API Key 安全**：使用专门的 API Key，设置用量上限，定期轮换
2. **备份密码**：使用强密码（12 位以上，含大小写字母+数字+符号）
3. **设备锁**：建议开启手机锁屏密码/生物识别
