//
//  CLI.swift
//
//
//  Created by stephen on 4/15/24.
//

import Foundation
import ArgumentParser
import ColorizeSwift
import CoreML

@available(macOS 14.4, *)
@main
struct CLI: AsyncParsableCommand {
    
    static var configuration: CommandConfiguration {
        .init(abstract: "Load a CoreML model and print its detailed compute plan.")
    }
    
    @Option(help: "Path to a mlmodelc. Generate with: xcrun coremlcompiler compile your.mlpackage .")
    public var modelPath: String
    
    @Option(help: "all, cpuOnly, cpuAndGPU, cpuAndNeuralEngine")
    public var computeUnits: String = "all"
    
    public func run() async throws  {
        let url = URL(fileURLWithPath: self.modelPath)
        let config = MLModelConfiguration()
        config.computeUnits = MLComputeUnits.fromString(s: computeUnits)
        print("Analyzing model for compute unit [\(config.computeUnits.name)]...")
        let plan = try! await MLComputePlan.load(contentsOf: url, configuration: config)
        
        switch plan.modelStructure {
        case .neuralNetwork(_):
            print("NeuralNetwork not implemented")
            break
        case .program(let program):
            printProgram(program: program, plan: plan)
        case .pipeline(_):
            print("Pipeline not implemented")
            break
        case .unsupported:
            print("Unsupported model structure.")
            break
        @unknown default:
            print("Unknown model structure.")
            break
        }
    }
    
    func printProgram(program: MLModelStructure.Program, plan: MLComputePlan) {
        print("\nKey: C=CPU, G=GPU, N=NeuralEngine\n<Estimate of total operation cost>% <primary compute|supported compute>  <operation>")
        
        program.functions.forEach { (key: String, value: MLModelStructure.Program.Function) in
            let args = value.inputs.map {
                "\($0.name)" // $0.type has nothing interesting in it.
            }.joined(separator: ", ")
            print("func \(key)(\(args)) {")
            printBlock(block: value.block, plan: plan)
            print("}")
        }
    }
    
    func printBlock(block: MLModelStructure.Program.Block, plan: MLComputePlan, depth: Int = 1) {
        let indent = String(repeating: " ", count: depth)
        let deviceWidth = 4
        let costWidth = 5

        let ops = block.operations.map { op in
            let deviceUsage = plan.deviceUsage(for: op)
            let cost = plan.estimatedCost(of: op)
            return OpStats(op: op, cost: cost, deviceUsage: deviceUsage)
        }
        let totalCost = ops.compactMap({ $0.cost?.weight }).reduce(0, { $0 + $1 })

        ops.forEach { opStats in
            let op = opStats.op
            let outputs = op.outputs.map {
                $0.name
            }.joined(separator: ", ")
            let inputs = op.inputs.map { k,v in
                "\(k): \(v.bindings.map({b in b.displayName}))"
            }.joined(separator: ", ")
            
            // Show device support.
            let deviceIcons = (opStats.deviceUsage?.icons ?? "")
                .padding(toLength: deviceWidth, withPad: " ", startingAt: 0)
            
            // Show total cost.
            let costPercentage = opStats.cost.map({ 100 * $0.weight / totalCost })
            let formattedCost = (costPercentage.map({String(format: "%.2f", $0) + "%"}) ?? "")
                .padding(toLength: costWidth, withPad: " ", startingAt: 0)
                
            print("\(formattedCost) \(deviceIcons)\(indent)\(outputs) = \(op.operatorName)(\(inputs))")
        }
        print("\(String(repeating: " ", count: deviceWidth + 1 + costWidth))\(indent)-> (\(block.outputNames.joined(separator:", ")))")
    }
}

@available(macOS 14.4, *)
struct OpStats {
    let op: MLModelStructure.Program.Operation
    let cost: MLComputePlan.Cost?
    let deviceUsage: MLComputePlan.DeviceUsage?
}

@available(macOS 14.4, *)
extension MLComputePlan.DeviceUsage {
    var icons: String {
        preferredIcon + "|" + supported.filter({$0 != preferred}).map({$0.letter}).joined()
    }
    var preferredIcon: String {
        preferred.letter
    }
}

extension MLComputeDevice {
    var letter: String {
        switch self {
        case .cpu(_):
            return "C"
        case .gpu(_):
            return "G"
        case .neuralEngine(_):
            return "N"
        @unknown default:
            return "?"
        }
    }
}

@available(macOS 14.4, *)
extension MLModelStructure.Program.Binding {
    var displayName: String {
        switch self {
        case .name(let n):
            return n
        case .value(_):
            return "value"
        @unknown default:
            return "unknown"
        }
    }
}

extension MLComputeUnits {
    static func fromString(s: String) -> Self {
        switch s {
        case "cpuOnly":
            fallthrough
        case "cpu":
            return .cpuOnly
        case "cpuAndGPU":
            fallthrough
        case "cpuGPU":
            return .cpuAndGPU
        case "cpuAndNeuralEngine":
            fallthrough
        case "cpuAndNE":
            fallthrough
        case "cpuAndANE":
            return .cpuAndNeuralEngine
        default:
            return .all
        }
    }
    
    var name: String {
        switch self {
        case .all:
            return "all"
        case .cpuOnly:
            return "cpuOnly"
        case .cpuAndGPU:
            return "cpuAndGPU"
        case .cpuAndNeuralEngine:
            return "cpuAndNeuralEngine"
        @unknown default:
            return "unknown"
        }
    }
}
