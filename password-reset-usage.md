# 密码重置功能使用说明

## 🔧 API端点说明

### 1. 用户重置自己的密码
**端点**: `POST /api/reset-password`

**请求参数**:
```json
{
  "username": "user1",
  "new_password": "newpass123",
  "current_password": "oldpass123"
}
```

**响应**:
```json
{
  "success": true,
  "message": "密码重置成功"
}
```

### 2. 管理员设置任意用户密码
**端点**: `POST /api/admin/set-password`

**请求参数**:
```json
{
  "username": "user1",
  "new_password": "newpass123"
}
```

**响应**:
```json
{
  "success": true,
  "message": "密码设置成功"
}
```

## 📋 使用示例

### JavaScript调用示例

```javascript
// 用户重置自己的密码
function resetMyPassword() {
    fetch('/api/reset-password', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            username: currentUser,
            new_password: newPassword,
            current_password: currentPassword
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert('密码重置成功！');
        } else {
            alert('错误: ' + data.message);
        }
    });
}

// 管理员设置用户密码
function adminSetPassword(username, newPassword) {
    fetch('/api/admin/set-password', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            username: username,
            new_password: newPassword
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert('密码设置成功！');
        } else {
            alert('错误: ' + data.message);
        }
    });
}
```

### cURL调用示例

```bash
# 用户重置自己的密码
curl -X POST http://localhost:5080/api/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user1",
    "new_password": "newpass123",
    "current_password": "oldpass123"
  }'

# 管理员设置用户密码
curl -X POST http://localhost:5080/api/admin/set-password \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user1",
    "new_password": "newpass123"
  }'
```

## 🔒 权限说明

### 普通用户权限
- ✅ 可以重置自己的密码
- ❌ 不能重置其他用户的密码
- ❌ 不能访问管理员工能

### 管理员权限
- ✅ 可以重置任意用户的密码
- ✅ 可以访问所有管理功能
- ✅ 不需要提供当前密码

## 🔐 安全特性

1. **权限验证**: 每个API都会验证用户身份和权限
2. **密码验证**: 用户重置密码需要提供当前密码验证身份
3. **错误处理**: 清晰的错误消息，不泄露敏感信息
4. **数据持久化**: 密码修改后立即保存到配置文件

## 🧪 测试步骤

1. 登录Web管理界面
2. 在用户配置页面找到"重置密码"功能
3. 输入新密码并确认
4. 提交后查看结果

或者直接使用API进行测试：
```bash
# 1. 测试用户重置自己的密码
curl -X POST http://localhost:5080/api/reset-password \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","new_password":"123456","current_password":"oldpass"}'

# 2. 测试配置文件下载（应该不再500错误）
curl -O http://localhost:5080/config/testuser.yaml
```