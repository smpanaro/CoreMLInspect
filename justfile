inspect PACKAGE:
    xcrun coremlcompiler compile {{PACKAGE}}.mlpackage .
    swift run CoreMLInspect --model-path {{PACKAGE}}.mlmodelc
