# CI 门禁改动（需手动应用）

`build_apk.yml.proposed` 是建议替换 `.github/workflows/build_apk.yml` 的内容，新增：

1. `quality` job：`flutter analyze` + `flutter test`（此前 CI 只打包，没有任何检查）
2. `backend-tests` job：`python -m pytest backend/tests -q`
3. `build` job 依赖前两者（`needs`），测试不通过则不出包
4. Flutter 版本 3.16.0 → 3.24.5（与仓库 `pubspec.lock` 对齐）
5. Release tag 改为从 `pubspec.yaml` 读取，避免 tag 与包内版本不一致

**为什么是 .proposed 文件**：当前推送使用的 GitHub App 令牌没有 `workflows` 权限，
无法直接修改 `.github/workflows/` 下的文件。请由有权限的维护者执行：

```bash
cp docs/ci/build_apk.yml.proposed .github/workflows/build_apk.yml
git add .github/workflows/build_apk.yml && git commit -m "ci: 增加 analyze/test 门禁"
```

`codemagic.yaml` 与 `build_apk.sh` 的门禁改动已直接提交（不受该权限限制）。
