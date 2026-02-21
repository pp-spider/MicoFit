"""测试 workouts/records 接口"""
import requests
import sys

BASE_URL = "http://localhost:8000"

def test_records():
    # 先尝试获取 token
    token = None

    # 尝试从环境变量或命令行参数获取凭据
    if len(sys.argv) >= 3:
        username = sys.argv[1]
        password = sys.argv[2]
    else:
        username = input("用户名/邮箱: ").strip()
        password = input("密码: ").strip()

    # 登录
    print(f"\n尝试登录: {username}")
    response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        json={"email": username, "password": password}
    )

    if response.status_code != 200:
        print(f"登录失败: {response.status_code}")
        print(f"响应: {response.text}")
        return

    token = response.json().get("access_token")
    print(f"登录成功，token: {token[:20]}...")

    # 测试 /api/v1/workouts/records
    print(f"\n测试 GET /api/v1/workouts/records?limit=500")
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(
        f"{BASE_URL}/api/v1/workouts/records?limit=500",
        headers=headers
    )

    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text[:500]}")

    # 列出所有可用路由
    print(f"\n测试 GET /api/v1/ 查看可用路由")
    response = requests.get(f"{BASE_URL}/")
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")

if __name__ == "__main__":
    test_records()
