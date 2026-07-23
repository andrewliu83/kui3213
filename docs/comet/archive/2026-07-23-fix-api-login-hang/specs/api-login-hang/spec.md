# api-login-hang

## Purpose

定义登录与探针依赖的 DB schema 初始化在冷启动与外部依赖失败时的行为，避免整站 API 被 schema promise 阻塞。

## Requirements

1. `ensureDbSchema` 在 `sys_config.schema_version` 已等于当前代码版本时，不得执行全量迁移与外部网络。
2. schema 版本缺失或不匹配时执行 `initializeDbSchema`，成功后写入当前版本。
3. 初始化中拉取 `cached_nodes_data` 的外部请求必须有超时上界；超时或失败不得使 `schemaReadyPromise` 永久 pending。
4. 登录 UI 对 `POST /api/login` 使用有限超时；超时与 429 显示可读错误。

## Acceptance criteria

1. **版本短路**  
   - 输入：schema_version 已匹配。  
   - 输出：ensureDbSchema 快速返回。

2. **外部 seed 超时**  
   - 输入：GitHub 不可达。  
   - 输出：schema 仍完成。

3. **登录超时提示**  
   - 输入：login 请求超时。  
   - 输出：用户看到超时提示。
