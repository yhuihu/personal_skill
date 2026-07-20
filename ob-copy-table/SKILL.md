---
name: ob-copy-table
description: 使用 obdumper 导出源表结构+数据，obloader 导入到目标表。当用户要求"复制表 / clone 表 / 创建副本表 / duplicate table / 拷贝表"时使用。
version: 2.0.0
author: opencode
license: MIT
---

# OB Copy Table · 表副本创建

## 触发场景

- 用户要求"复制表"、"clone 表"、"创建副本"、"拷贝表"、"duplicate table"、"原表备份"
- 用户在 OceanBase MySQL 模式下需要快速创建一张表的完整副本（结构 + 数据）

## 输入验证

用户**必须**提供以下全部参数，缺一不可：

| 参数 | 说明 |
|------|------|
| `source_table` | 原表名 |
| `target_table` | 目标表名 |
| `host` | 数据库连接地址 (IP 或域名) |
| `port` | 数据库端口 |
| `user` | 用户名 (如 `root@test`) |
| `password` | 密码 |
| `database` | 数据库名 |

## 工作目录

所有操作在用户指定的工作目录下进行，默认为项目根目录。如未指定，使用 `%TEMP%/ob_copy_${table}`。

## 执行流程

### Step 1: 导出源表 DDL

```bash
obdumper -h {host} -P {port} -u {user} -p {password} -D {database} --ddl --table {source_table} -f {work_dir}/ddl
```

### Step 2: 导出源表数据 (CSV)

```bash
obdumper -h {host} -P {port} -u {user} -p {password} -D {database} --csv --table {source_table} -f {work_dir}/data
```

### Step 3: 修改 DDL 中的表名

读取 `{work_dir}/ddl` 目录下的 `CREATE TABLE` 语句，将表名从 `{source_table}` 替换为 `{target_table}` 后写入临时文件。

### Step 4: 导入 DDL + 数据到目标表

```bash
obloader -h {host} -P {port} -u {user} -p {password} -D {database} --ddl --csv -f {work_dir}
```

### Step 5: Harness 校验

导入完成后自动执行验证，对比源表与目标表：

| 校验项 | 方法 | 通过条件 |
|--------|------|----------|
| **行数** | `SELECT COUNT(*)` | 两表行数完全一致 |
| **索引** | `SHOW INDEXES` | 索引名称、列、顺序、唯一性、类型完全一致 |

校验失败时**不会回滚**（数据已导入），但退出码非 0，提示用户手动检查差异。

### Step 6: 清理临时文件

删除 `{work_dir}` 目录下的所有导出文件（可选，默认保留日志）。

## 错误处理

| 错误 | 处理方式 |
|------|----------|
| 源表不存在 | 中止流程，提示用户检查表名 |
| obdumper/obloader 找不到 | 提示用户安装 ob-loader-dumper |
| Hadoop NativeIO 异常 | 添加 `ext/windows/hadoop/bin` 到 PATH 后重试 |
| 目标表已存在 | 询问用户是否覆盖 (DROP TABLE) 或指定其他表名 |
| 连接失败 | 提示用户检查连接参数 |

## 输出格式

流程结束后向用户输出：

```
✅ 复制完成: {source_table} → {target_table}
  - 结构: {work_dir}/ddl/{source_table}_schema.sql
  - 导出行数: N
  - 耗时: X 秒
```

## 脚本参考

技能所依赖的脚本文件存放在本目录下：

| 文件 | 作用 |
|------|------|
| `ob-copy-table.bat` | 主流程：导出 DDL → 导出 CSV → 替换表名 → 导入 → Harness 校验 → 清理 |
| `replace_table_name.ps1` | 在 DDL 文件中将 `CREATE TABLE source` 替换为 `CREATE TABLE target` |
| `harness.ps1` | 验证行数一致性和索引一致性，退出码 0 通过 / 非 0 失败 |

`ob-copy-table.bat` 接收 `source_table`, `target_table`, `host`, `port`, `user`, `password`, `database` 参数，以退出码 0 表示成功，非 0 表示失败。

## 完成检查

- [ ] 用户已提供全部必填参数
- [ ] obdumper 导出 DDL 成功
- [ ] obdumper 导出 CSV 数据成功
- [ ] DDL 中 `CREATE TABLE {source_table}` 已替换为 `CREATE TABLE {target_table}`
- [ ] obloader 导入 DDL + 数据成功
- [ ] Harness 校验：源表与目标表行数一致
- [ ] Harness 校验：源表与目标表索引定义一致
- [ ] 临时文件已清理（或告知用户位置）
- [ ] 向用户输出复制结果摘要（含校验通过/失败）
