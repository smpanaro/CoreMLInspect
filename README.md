# CoreMLInspect 🔍

Inspect a CoreML model. For each layer see:
- which device (CPU/GPU/ANE) it can and will run on
- an estimate of the total cost compared to the whole model

Thin wrapper around the iOS 17.4/macOS 14.4 [`MLComputePlan`](https://developer.apple.com/documentation/coreml/mlcomputeplan) API.

```shell
$ xcrun coremlcompiler compile path_to_your_model.mlpackage .
$ swift run CoreMLInspect --model-path path_to_your_model.mlmodelc
Analyzing model for compute unit [all]...

Key: C=CPU, G=GPU, N=NeuralEngine
<Estimate of total operation cost>% <primary compute|supported compute> <operation>
func main(input_ids) {
           x_1_axis_0 = const()
           x_1_batch_dims_0 = const()
           transformer_wte_weight_to_fp16 = const()
0.68% G|C  x_1_cast_fp16 = ios16.gather(batch_dims: ["x_1_batch_dims_0"], x: ["transformer_wte_weight_to_fp16"], indices: ["input_ids"], axis: ["x_1_axis_0"])
           var_136 = const()
           var_137 = const()
0.17% G|CN var_145_cast_fp16 = ios16.mul(x: ["x_1_cast_fp16"], y: ["x_1_cast_fp16"])
```
