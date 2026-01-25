# Testing

### Code Coverage Report

Generate detailed coverage report:

```console
swift test --enable-code-coverage
llvm-cov report .build/debug/swift-waylandPackageTests.xctest --instr-profile=.build/debug/codecov/default.profdata --ignore-filename-regex='(.build|Tests)[/\\].*'
```
