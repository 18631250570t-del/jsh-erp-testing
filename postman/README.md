# jshERP Postman 接口自动化

## 为什么需要辅助服务

jshERP 登录需要**图形验证码**，而验证码只存在 Redis（`captcha_codes:{uuid}`），
Postman 无法直接读 Redis。所以用一个本地小服务把验证码暴露成 HTTP 接口，
Postman 通过 `pm.sendRequest` 调它，即可实现**全自动登录**。

```
Postman ──GET /user/randomImage──> jshERP 后端 ──> 验证码写入 Redis
   │
   └──GET helper/captcha?uuid=xx──> captcha_helper ──读 Redis──> 返回验证码
   │
   └──POST /user/login {md5密码, 验证码, uuid}──> token
```

## 启动步骤

```powershell
# 1. 启动被测服务（Redis + 后端 + 前端）
D:\jsh-env\start-all.ps1

# 2. 启动验证码辅助服务
python D:\jsh-erp-test\tools\captcha_helper.py
# 看到 "captcha helper 启动: http://127.0.0.1:8899" 即可
```

## 导入 Postman

1. 打开 Postman → Import
2. 选择 `jshERP.postman_collection.json` 和 `jshERP.postman_environment.json`
3. 右上角环境选择 **jshERP-本地**
4. 先跑 **00-认证 / 01-登录**，成功后 `token` 会自动写入环境变量

## 用 Collection Runner 批量跑

1. 选中集合 → Run
2. 勾选全部请求，Iterations = 1
3. 点 Run

## 用 Newman 命令行跑（可进 CI）

```powershell
npm install -g newman newman-reporter-htmlextra

newman run D:\jsh-erp-test\postman\jshERP.postman_collection.json \
  -e D:\jsh-erp-test\postman\jshERP.postman_environment.json \
  -r cli,htmlextra \
  --reporter-htmlextra-export D:\jsh-erp-test\reports\newman.html
```

## 两个必须知道的坑

### 1. jshERP 用 HTTP 200 包业务码

```
GET /depot/checkIsNameExist?name=xxx
-> HTTP 200
   {"code":500,"data":"未知异常"}
```

**所以断言必须校验 `body.code`，只看 HTTP 状态码会漏掉所有业务错误。**

### 2. 响应有两种风格

| 风格 | 示例 | 断言方式 |
|---|---|---|
| 包装型 | `{"code":200,"data":{"total":4,"rows":[...]}}` | 校验 `body.code` |
| 直接型 | `[{"id":63,"userName":"测试用户"}]` | 校验数组本身 |

## 后续扩展

- 基础资料新增/编辑（`/depot/add`、`/supplier/add`、`/material/add`）
- 单据流转（`/depotHead/batchAddDepotHeadAndDetail` + 审核）
- 用 Tests 脚本串联：新增后把 id 写入变量，供后续请求引用
- 数据驱动：CSV 文件 + Runner 逐行执行，覆盖边界值用例
