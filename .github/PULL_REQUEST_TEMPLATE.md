## 变更摘要

- 

## 类型

- [ ] 修复缺陷
- [ ] 新增能力
- [ ] 文档更新
- [ ] CI / 发布流程
- [ ] 内部重构

## 发布影响

- [ ] 不影响公开 API
- [ ] 新增公开 API，已更新 `tool/api_snapshot.json`
- [ ] 行为变化，已更新 `CHANGELOG.md`
- [ ] 破坏性变化，已写明迁移说明

## 自测

- [ ] `dart format --set-exit-if-changed lib test benchmark tool example/lib example/integration_test`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `dart run tool/check_api_snapshot.dart`
- [ ] `dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json`
- [ ] `dart doc --output doc/api`
- [ ] `dart pub publish --dry-run`

## 平台验证

- [ ] Android emulator 或真机
- [ ] iOS simulator 或真机
- [ ] 大图 / HEIC / EXIF / 透明 PNG 场景不受影响
